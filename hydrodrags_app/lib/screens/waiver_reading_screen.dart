import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../widgets/language_toggle.dart';
import '../l10n/app_localizations.dart';

class WaiverReadingScreen extends StatefulWidget {
  const WaiverReadingScreen({super.key});

  @override
  State<WaiverReadingScreen> createState() => _WaiverReadingScreenState();
}

class _WaiverReadingScreenState extends State<WaiverReadingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

  void _continueToSign() {
    Navigator.of(context).pushNamed('/waiver-signature');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppStateService>(context);
    final htmlContent = appState.waiverContentHtml;
    final title = appState.waiverTitle ?? l10n.waiver;

    if (htmlContent == null || htmlContent.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: const [
            LanguageToggle(isCompact: true),
            SizedBox(width: 8),
          ],
        ),
        body: const Center(
          child: Text('Waiver content is not available. Please go back.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              child: HtmlWidget(
                htmlContent,
                textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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
                  if (!_hasScrolledToEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.scrollToEnd,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _hasScrolledToEnd ? _continueToSign : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(l10n.continueToWaiver), // "Continue to Sign" flow
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
