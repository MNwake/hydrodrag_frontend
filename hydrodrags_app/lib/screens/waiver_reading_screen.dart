import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/waiver_2026.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';

class WaiverReadingScreen extends StatefulWidget {
  const WaiverReadingScreen({super.key});

  @override
  State<WaiverReadingScreen> createState() => _WaiverReadingScreenState();
}

class _WaiverReadingScreenState extends State<WaiverReadingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  late List<TextEditingController> _initialControllers;
  late List<FocusNode> _initialFocusNodes;
  late List<GlobalKey> _initialRowKeys;
  int? _focusedInitialIndex; // which initial field has focus, null if none
  static const int _initialCount = 8;

  @override
  void initState() {
    super.initState();
    _initialControllers = List.generate(
      _initialCount,
      (_) => TextEditingController(),
    );
    _initialFocusNodes = List.generate(
      _initialCount,
      (_) => FocusNode(),
    );
    for (var i = 0; i < _initialCount; i++) {
      final idx = i;
      _initialFocusNodes[i].addListener(() {
        if (_initialFocusNodes[idx].hasFocus) {
          setState(() => _focusedInitialIndex = idx);
        } else {
          setState(() {
            if (_focusedInitialIndex == idx) _focusedInitialIndex = null;
          });
        }
      });
    }
    _initialRowKeys = List.generate(_initialCount, (_) => GlobalKey());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final c in _initialControllers) {
      c.dispose();
    }
    for (final f in _initialFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _goToNextInitial() {
    final current = _focusedInitialIndex;
    if (current == null || current >= _initialCount - 1) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    final nextIdx = current + 1;
    final nextContext = _initialRowKeys[nextIdx].currentContext;
    if (nextContext != null) {
      Scrollable.ensureVisible(
        nextContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _initialFocusNodes[nextIdx].requestFocus();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      final isAtBottom = position.pixels >= position.maxScrollExtent - 50;
      if (isAtBottom && !_hasScrolledToEnd) {
        setState(() => _hasScrolledToEnd = true);
      }
    }
  }

  List<String> get _initials =>
      _initialControllers.map((c) => c.text.trim()).toList();

  bool get _allInitialsFilled {
    if (_initialControllers.length != _initialCount) return false;
    return _initialControllers.every((c) => c.text.trim().length >= 1);
  }

  void _continueToSign() {
    if (!_allInitialsFilled) return;
    final appState = Provider.of<AppStateService>(context, listen: false);
    appState.setWaiverInitials(_initials);
    Navigator.of(context).pushNamed('/waiver-signature');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int initialIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 HydroDrag Waiver'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _hasScrolledToEnd
                ? 1.0
                : _scrollController.hasClients
                    ? (_scrollController.position.pixels /
                            _scrollController.position.maxScrollExtent)
                        .clamp(0.0, 1.0)
                    : 0.0,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2026 HydroDrag Waiver, Release, Risk Assumption',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PARTICIPANTS MUST INITIAL ALL PLACES. BOTH MINORS AND GUARDIANS MUST INITIAL.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...waiver2026Segments.map((segment) {
                    final needsInitial = segment.needsInitial;
                    final idx = needsInitial ? initialIndex++ : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                        if (needsInitial && idx != null && idx < _initialCount) ...[
                          const SizedBox(height: 8),
                          Row(
                            key: _initialRowKeys[idx],
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Initials:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: _initialControllers[idx],
                                  focusNode: _initialFocusNodes[idx],
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 4,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[A-Za-z]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '___',
                                    counterText: '',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 32),
                  if (!_hasScrolledToEnd)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please scroll to the end of the waiver and complete all initials to continue.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_allInitialsFilled && _hasScrolledToEnd && _focusedInitialIndex == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Please initial all sections above.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _focusedInitialIndex != null
                          ? _goToNextInitial
                          : (_hasScrolledToEnd && _allInitialsFilled
                              ? _continueToSign
                              : null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _focusedInitialIndex != null ? 'Next' : 'Continue to Sign',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
