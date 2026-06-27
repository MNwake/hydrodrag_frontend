import 'package:flutter/material.dart';
import '../models/matchup.dart';
import '../models/registration_ref.dart';
import '../models/round.dart';

/// Accent for PWC registration numbers (racer ID on the water).
const Color _pwcBadgeColor = Color(0xFFFF9800);

/// How participant labels render at different zoom levels.
enum BracketLabelMode {
  /// Full name plus PWC badge.
  full,

  /// PWC number primary; abbreviated name when space allows.
  compact,

  /// PWC number only (fits zoomed-out overview).
  numberOnly,
}

/// Scaled layout values for the bracket tree (base design at scale 1.0).
class BracketLayoutMetrics {
  BracketLayoutMetrics(
    this.layoutScale, {
    double? labelScale,
  }) : labelScale = labelScale ?? layoutScale;

  /// Box/connector sizing (updated by zoom buttons).
  final double layoutScale;

  /// Label density (updated by pinch or buttons).
  final double labelScale;

  static BracketLabelMode labelModeFor(double scale) {
    if (scale < 0.55) return BracketLabelMode.numberOnly;
    if (scale < 0.8) return BracketLabelMode.compact;
    return BracketLabelMode.full;
  }

  static const double baseBoxWidth = 188;
  static const double baseParticipantRowHeight = 28;
  static const double baseDividerHeight = 1;
  static const double baseCompactMatchupGap = 10;
  static const double baseSlotGap = 14;
  static const double baseConnectorWidth = 18;
  static const double baseRoundLabelHeight = 22;

  double get boxWidth => baseBoxWidth * layoutScale;
  double get participantRowHeight => baseParticipantRowHeight * layoutScale;
  double get dividerHeight => baseDividerHeight;
  double get boxHeight => participantRowHeight * 2 + dividerHeight;
  double get compactMatchupGap => baseCompactMatchupGap * layoutScale;
  double get slotGap => baseSlotGap * layoutScale;
  double get connectorWidth => baseConnectorWidth * layoutScale;
  double get roundLabelHeight => baseRoundLabelHeight * layoutScale;

  double get slotUnit => boxHeight + slotGap;

  double get nameFontSize => (13 * layoutScale).clamp(9, 13);
  double get badgeFontSize => (11 * layoutScale).clamp(9, 11);
  double get numberOnlyFontSize => (14 * layoutScale).clamp(10, 16);

  BracketLabelMode get labelMode => labelModeFor(labelScale);
}

/// Positions matchups from feeder relationships (handles solo bye rows).
class BracketTreeLayout {
  BracketTreeLayout({
    required this.metrics,
    required this.rounds,
  });

  final BracketLayoutMetrics metrics;
  final List<List<MatchupBase>> rounds;

  int _prevMatchupIndex(int roundIndex, int slot) {
    final prevLen = rounds[roundIndex - 1].length;
    if (prevLen == 0) return 0;
    return slot.clamp(0, prevLen - 1);
  }

  /// Previous-round index that feeds a solo bye in [roundIndex].
  int byeFeederIndex(int roundIndex, int matchIndex) {
    return _prevMatchupIndex(roundIndex, 2 * matchIndex);
  }

  double matchupCenterY(int roundIndex, int matchIndex) {
    if (roundIndex < 0 || roundIndex >= rounds.length) return 0;
    final matchups = rounds[roundIndex];
    if (matchIndex < 0 || matchIndex >= matchups.length) return 0;

    if (roundIndex == 0) {
      return (2 * matchIndex + 1) * metrics.slotUnit;
    }

    final prevLen = rounds[roundIndex - 1].length;
    if (prevLen == 0) return 0;

    if (matchups[matchIndex].isBye) {
      return matchupCenterY(
        roundIndex - 1,
        byeFeederIndex(roundIndex, matchIndex),
      );
    }

    final idxA = 2 * matchIndex;
    final idxB = 2 * matchIndex + 1;
    if (idxB >= prevLen) {
      return matchupCenterY(
        roundIndex - 1,
        _prevMatchupIndex(roundIndex, idxA),
      );
    }

    final yA = matchupCenterY(roundIndex - 1, idxA);
    final yB = matchupCenterY(roundIndex - 1, idxB);
    return (yA + yB) / 2;
  }

  double matchupTop(int roundIndex, int matchIndex) {
    return matchupCenterY(roundIndex, matchIndex) - metrics.boxHeight / 2;
  }

  double columnContentHeight(int roundIndex) {
    final matchups = rounds[roundIndex];
    if (matchups.isEmpty) return 0;
    var maxBottom = 0.0;
    for (var i = 0; i < matchups.length; i++) {
      final bottom = matchupTop(roundIndex, i) + metrics.boxHeight;
      if (bottom > maxBottom) maxBottom = bottom;
    }
    return maxBottom;
  }
}

/// Provides [BracketLayoutMetrics] to bracket widgets.
class BracketScaleScope extends InheritedWidget {
  const BracketScaleScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  final BracketLayoutMetrics metrics;

  static BracketLayoutMetrics of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BracketScaleScope>();
    assert(scope != null, 'BracketScaleScope not found');
    return scope!.metrics;
  }

  @override
  bool updateShouldNotify(BracketScaleScope oldWidget) {
    return oldWidget.metrics.layoutScale != metrics.layoutScale ||
        oldWidget.metrics.labelScale != metrics.labelScale;
  }
}

/// Pinch/pan zoom with a bottom floating toolbar; drives scaled bracket layout and label mode.
class BracketZoomableView extends StatefulWidget {
  const BracketZoomableView({
    super.key,
    this.scrollHeader,
    required this.child,
  });

  /// Layout height of [scrollHeader] at 100% zoom (must match [DoubleEliminationBracketHeader]).
  static const double scrollHeaderHeight = 72;

  /// Inside the pannable area; pans with the bracket but does not shrink on pinch.
  final Widget? scrollHeader;

  final Widget child;

  @override
  State<BracketZoomableView> createState() => _BracketZoomableViewState();
}

class _BracketZoomableViewState extends State<BracketZoomableView> {
  static const double _minEffectiveScale = 0.35;
  static const double _maxEffectiveScale = 1.0;
  static const List<double> _scaleSteps = [0.35, 0.45, 0.55, 0.7, 0.85, 1.0];

  /// Infinite margin so pinch can reach [minScale]; finite margins block zoom-out
  /// before minScale (Flutter clamps scale to keep content inside the boundary).
  static const EdgeInsets _boundaryMargin = EdgeInsets.all(double.infinity);

  final TransformationController _transformController = TransformationController();
  double _layoutScale = 1.0;
  double _labelScale = 1.0;
  BracketLabelMode _labelMode = BracketLabelMode.full;

  double get _matrixScale => _transformController.value.getMaxScaleOnAxis();

  double get _effectiveScale => (_layoutScale * _matrixScale).clamp(0.01, 2.0);

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  double get _matrixMin => _minEffectiveScale / _layoutScale;

  double get _matrixMax => _maxEffectiveScale / _layoutScale;

  /// Keep pan inside the bracket viewport (no empty space left, no bleed above top).
  void _clampPanBounds() {
    final matrix = _transformController.value;
    final translation = matrix.getTranslation();
    final scale = matrix.getMaxScaleOnAxis().clamp(_matrixMin, _matrixMax);

    final clampedX = translation.x > 0 ? 0.0 : translation.x;
    final clampedY = translation.y > 0 ? 0.0 : translation.y;
    if (clampedX == translation.x &&
        clampedY == translation.y &&
        scale == matrix.getMaxScaleOnAxis()) {
      return;
    }

    _transformController.value = Matrix4.identity()
      ..translate(clampedX, clampedY)
      ..scale(scale);
  }

  void _clampMatrixScale() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale >= _matrixMin && scale <= _matrixMax) return;
    final translation = matrix.getTranslation();
    _transformController.value = Matrix4.identity()
      ..translate(translation.x, translation.y)
      ..scale(scale.clamp(_matrixMin, _matrixMax));
  }

  void _onTransformChanged() {
    _clampMatrixScale();
    _clampPanBounds();

    final effective = _effectiveScale;
    final mode = BracketLayoutMetrics.labelModeFor(effective);
    final scaleChanged = (effective - _labelScale).abs() >= 0.03;
    final modeChanged = mode != _labelMode;
    if (!scaleChanged && !modeChanged) return;
    setState(() {
      _labelScale = effective;
      _labelMode = mode;
    });
  }

  double get _headerSpacerHeight =>
      BracketZoomableView.scrollHeaderHeight /
      _matrixScale.clamp(_minEffectiveScale, _maxEffectiveScale);

  int _currentEffectiveStepIndex() {
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < _scaleSteps.length; i++) {
      final diff = (_scaleSteps[i] - _effectiveScale).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  /// Adjust zoom via matrix only (same as pinch) — avoids layout-scale preset bugs.
  void _zoomStep(int direction) {
    final translation = _transformController.value.getTranslation();
    final next = (_currentEffectiveStepIndex() + direction)
        .clamp(0, _scaleSteps.length - 1);
    final targetMatrix = (_scaleSteps[next] / _layoutScale).clamp(_matrixMin, _matrixMax);

    _transformController.value = Matrix4.identity()
      ..translate(translation.x, translation.y)
      ..scale(targetMatrix);
  }

  String get _scaleLabel => '${(_effectiveScale * 100).round()}%';

  String get _modeLabel {
    return switch (_labelMode) {
      BracketLabelMode.full => 'Names',
      BracketLabelMode.compact => 'Compact',
      BracketLabelMode.numberOnly => 'Numbers',
    };
  }

  @override
  Widget build(BuildContext context) {
    final metrics = BracketLayoutMetrics(_layoutScale, labelScale: _labelScale);
    final canZoomOut = _effectiveScale > _minEffectiveScale + 0.02;
    final canZoomIn = _effectiveScale < _maxEffectiveScale - 0.02;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: BracketScaleScope(
            metrics: metrics,
            child: InteractiveViewer(
              transformationController: _transformController,
              alignment: Alignment.topLeft,
              minScale: _matrixMin,
              maxScale: _matrixMax,
              constrained: false,
              panEnabled: true,
              scaleEnabled: true,
              trackpadScrollCausesScale: false,
              boundaryMargin: _boundaryMargin,
              onInteractionEnd: (_) {
                _clampMatrixScale();
                _clampPanBounds();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.scrollHeader != null)
                    SizedBox(height: _headerSpacerHeight),
                  widget.child,
                ],
              ),
            ),
          ),
        ),
        if (widget.scrollHeader != null)
          AnimatedBuilder(
            animation: _transformController,
            builder: (context, _) {
              final translation = _transformController.value.getTranslation();
              return Positioned(
                left: translation.x,
                top: translation.y,
                child: widget.scrollHeader!,
              );
            },
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: _BracketZoomToolbar(
              scaleLabel: _scaleLabel,
              modeLabel: _modeLabel,
              canZoomIn: canZoomIn,
              canZoomOut: canZoomOut,
              onZoomIn: () => _zoomStep(1),
              onZoomOut: () => _zoomStep(-1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating pill toolbar for bracket zoom (maps / design-tool pattern).
class _BracketZoomToolbar extends StatelessWidget {
  const _BracketZoomToolbar({
    required this.scaleLabel,
    required this.modeLabel,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final String scaleLabel;
  final String modeLabel;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.outline.withOpacity(0.2);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.94),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarIcon(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom out',
              enabled: canZoomOut,
              onTap: onZoomOut,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scaleLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    modeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            _ToolbarIcon(
              icon: Icons.add_rounded,
              tooltip: 'Zoom in',
              enabled: canZoomIn,
              onTap: onZoomIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      style: IconButton.styleFrom(
        foregroundColor: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withOpacity(0.3),
        minimumSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

/// One participant slot; layout depends on [BracketLabelMode].
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.pwcId,
    required this.name,
    required this.isWinner,
    required this.textColor,
    this.racer,
    this.pwcFallback,
  });

  final String pwcId;
  final String name;
  final bool isWinner;
  final Color textColor;
  final RegistrationRefBase? racer;
  final String? pwcFallback;

  String _nameForLabel(BracketLabelMode mode) {
    if (mode == BracketLabelMode.compact) {
      return racer?.compactDisplayName ??
          RegistrationRefBase.compactFromDisplayName(name);
    }
    return name;
  }

  String _displayPwc(String? fallback) {
    if (pwcId.isNotEmpty) return pwcId;
    return fallback?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = BracketScaleScope.of(context);
    final displayPwc = _displayPwc(pwcFallback);
    final mode = m.labelMode;
    final displayName = _nameForLabel(mode);

    return SizedBox(
      height: m.participantRowHeight,
      child: ColoredBox(
        color: isWinner
            ? theme.colorScheme.primary.withOpacity(0.18)
            : const Color(0xFF2D3A4F),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * m.layoutScale),
          child: _buildContent(context, m, mode, displayPwc, displayName),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    BracketLayoutMetrics m,
    BracketLabelMode mode,
    String displayPwc,
    String displayName,
  ) {
    if (mode == BracketLabelMode.numberOnly) {
      return Center(
        child: Text(
          displayPwc.isNotEmpty ? displayPwc : '—',
          style: TextStyle(
            fontSize: m.numberOnlyFontSize,
            fontWeight: FontWeight.bold,
            color: displayPwc.isNotEmpty ? _pwcBadgeColor : textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (mode == BracketLabelMode.compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: m.nameFontSize,
                height: 1.1,
                fontWeight: isWinner ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (displayPwc.isNotEmpty) ...[
            SizedBox(width: 6 * m.layoutScale),
            Container(
              height: 20 * m.layoutScale,
              constraints: BoxConstraints(minWidth: 24 * m.layoutScale),
              padding: EdgeInsets.symmetric(horizontal: 4 * m.layoutScale),
              decoration: BoxDecoration(
                color: _pwcBadgeColor,
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Text(
                displayPwc,
                style: TextStyle(
                  fontSize: m.badgeFontSize,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            displayName,
            style: TextStyle(
              fontSize: m.nameFontSize,
              height: 1.2,
              fontWeight: isWinner ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (displayPwc.isNotEmpty) ...[
          SizedBox(width: 6 * m.layoutScale),
          Container(
            height: 20 * m.layoutScale,
            constraints: BoxConstraints(minWidth: 26 * m.layoutScale),
            padding: EdgeInsets.symmetric(horizontal: 5 * m.layoutScale),
            decoration: BoxDecoration(
              color: _pwcBadgeColor,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              displayPwc,
              style: TextStyle(
                fontSize: m.badgeFontSize,
                height: 1,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One matchup cell: two slots with PWC ids and winner highlight.
class _MatchupBox extends StatelessWidget {
  const _MatchupBox({
    required this.matchup,
    required this.pwcByRegistrationId,
  });

  final MatchupBase matchup;
  final Map<String, String> pwcByRegistrationId;

  String? _fallbackPwc(String? registrationId) {
    if (registrationId == null || registrationId.isEmpty) return null;
    return pwcByRegistrationId[registrationId];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = BracketScaleScope.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SizedBox(
      width: m.boxWidth,
      height: m.boxHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2836),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.35),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Column(
            children: [
              _ParticipantRow(
                pwcId: matchup.pwcIdA,
                racer: matchup.racerA,
                pwcFallback: _fallbackPwc(matchup.racerA?.id),
                name: matchup.nameA,
                isWinner: matchup.isWinnerA,
                textColor: onSurface,
              ),
              Container(
                height: m.dividerHeight,
                color: theme.colorScheme.outline.withOpacity(0.25),
              ),
              _ParticipantRow(
                pwcId: matchup.pwcIdB,
                racer: matchup.racerB,
                pwcFallback: _fallbackPwc(matchup.racerB?.id),
                name: matchup.nameB,
                isWinner: matchup.isWinnerB,
                textColor: onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal connector lines from one round column to the next.
class _BracketConnector extends StatelessWidget {
  const _BracketConnector({
    required this.layout,
    required this.roundIndex,
    required this.columnHeight,
    required this.color,
  });

  final BracketTreeLayout layout;
  final int roundIndex;
  final double columnHeight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final nextRound = roundIndex + 1;
    if (nextRound >= layout.rounds.length || columnHeight <= 0) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(layout.metrics.connectorWidth, columnHeight),
      painter: _BracketConnectorPainter(
        layout: layout,
        roundIndex: roundIndex,
        color: color,
      ),
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  _BracketConnectorPainter({
    required this.layout,
    required this.roundIndex,
    required this.color,
  });

  final BracketTreeLayout layout;
  final int roundIndex;
  final Color color;

  /// Same connector geometry for paired heats and solo-bye feeders.
  void _drawBracketConnector(
    Canvas canvas,
    Paint paint,
    double halfW,
    double width,
    double yA,
    double yB,
    double yOut,
  ) {
    canvas.drawLine(Offset(0, yA), Offset(halfW, yA), paint);
    canvas.drawLine(Offset(0, yB), Offset(halfW, yB), paint);
    canvas.drawLine(Offset(halfW, yA), Offset(halfW, yB), paint);
    canvas.drawLine(Offset(halfW, yOut), Offset(width, yOut), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = (1.5 * layout.metrics.layoutScale).clamp(1, 1.5)
      ..style = PaintingStyle.stroke;

    final halfW = size.width / 2;
    final nextRound = roundIndex + 1;
    final nextMatchups = layout.rounds[nextRound];

    final prevLen = layout.rounds[roundIndex].length;

    for (var i = 0; i < nextMatchups.length; i++) {
      final yOut = layout.matchupCenterY(nextRound, i);
      final idxA = 2 * i;
      final idxB = 2 * i + 1;

      if (nextMatchups[i].isBye || idxB >= prevLen) {
        final prevIdx = nextMatchups[i].isBye
            ? layout.byeFeederIndex(nextRound, i)
            : layout._prevMatchupIndex(roundIndex + 1, idxA);
        final y = layout.matchupCenterY(roundIndex, prevIdx);
        _drawBracketConnector(canvas, paint, halfW, size.width, y, y, yOut);
        continue;
      }

      final yA = layout.matchupCenterY(roundIndex, idxA);
      final yB = layout.matchupCenterY(roundIndex, idxB);
      _drawBracketConnector(canvas, paint, halfW, size.width, yA, yB, yOut);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.roundIndex != roundIndex ||
        oldDelegate.color != color ||
        oldDelegate.layout.metrics.layoutScale != layout.metrics.layoutScale ||
        oldDelegate.layout.rounds != layout.rounds;
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.layout,
    required this.roundIndex,
    required this.matchups,
    required this.pwcByRegistrationId,
    required this.isLastRound,
    required this.connectorColor,
    required this.useTreeLayout,
  });

  final BracketTreeLayout layout;
  final int roundIndex;
  final List<MatchupBase> matchups;
  final Map<String, String> pwcByRegistrationId;
  final bool isLastRound;
  final Color connectorColor;
  final bool useTreeLayout;

  @override
  Widget build(BuildContext context) {
    if (matchups.isEmpty) return const SizedBox.shrink();

    final m = BracketScaleScope.of(context);

    if (!useTreeLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < matchups.length; i++) ...[
            if (i > 0) SizedBox(height: m.compactMatchupGap),
            _MatchupBox(
              matchup: matchups[i],
              pwcByRegistrationId: pwcByRegistrationId,
            ),
          ],
        ],
      );
    }

    final contentHeight = layout.columnContentHeight(roundIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: m.boxWidth,
          height: contentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < matchups.length; i++)
                Positioned(
                  top: layout.matchupTop(roundIndex, i),
                  left: 0,
                  child: _MatchupBox(
                    matchup: matchups[i],
                    pwcByRegistrationId: pwcByRegistrationId,
                  ),
                ),
            ],
          ),
        ),
        if (!isLastRound)
          _BracketConnector(
            layout: layout,
            roundIndex: roundIndex,
            columnHeight: contentHeight,
            color: connectorColor,
          ),
      ],
    );
  }
}

/// One bracket section (Winners, Losers, or Championship).
class BracketColumn extends StatelessWidget {
  const BracketColumn({
    super.key,
    required this.rounds,
    required this.title,
    required this.isLosers,
    this.pwcByRegistrationId = const {},
  });

  final List<RoundBase> rounds;
  final String title;
  final bool isLosers;
  final Map<String, String> pwcByRegistrationId;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final m = BracketScaleScope.of(context);
    final connectorColor = theme.colorScheme.primary.withOpacity(0.45);
    final useTreeLayout = rounds.length > 1;
    final sectionLabel = title.toUpperCase();
    final treeLayout = BracketTreeLayout(
      metrics: m,
      rounds: rounds.map((r) => r.matchups).toList(),
    );

    const fixedRoundLabelHeight = BracketLayoutMetrics.baseRoundLabelHeight;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sectionLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rounds.length; r++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: fixedRoundLabelHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          r == rounds.length - 1 && rounds.length > 1
                              ? 'Finals'
                              : 'Round ${rounds[r].roundNumber}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    _RoundColumn(
                      layout: treeLayout,
                      roundIndex: r,
                      matchups: rounds[r].matchups,
                      pwcByRegistrationId: pwcByRegistrationId,
                      isLastRound: r == rounds.length - 1,
                      connectorColor: connectorColor,
                      useTreeLayout: useTreeLayout,
                    ),
                  ],
                ),
                if (r < rounds.length - 1)
                  SizedBox(width: useTreeLayout ? 4 * m.layoutScale : 12 * m.layoutScale),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Header for the full double-elimination results view.
class DoubleEliminationBracketHeader extends StatelessWidget {
  const DoubleEliminationBracketHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: BracketZoomableView.scrollHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'DOUBLE ELIMINATION',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bracket results',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DoubleEliminationBracketFooter extends StatelessWidget {
  const DoubleEliminationBracketFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 72);
  }
}
