import 'package:flutter/material.dart';
import '../widgets/language_toggle.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sample waiver content - replace with actual content from backend
    const waiverContent = '''
LIABILITY WAIVER AND RELEASE OF CLAIMS

PLEASE READ CAREFULLY BEFORE SIGNING

In consideration of being permitted to participate in HydroDrags events and activities, I hereby acknowledge, agree, and represent that:

1. RISK OF INJURY: I understand and acknowledge that participation in watercraft racing and related activities involves inherent and serious risks of physical injury, including but not limited to: collision with other participants, watercraft, or obstacles; falls; exposure to water; mechanical failure; and other hazards.

2. ASSUMPTION OF RISK: I voluntarily assume full responsibility for any risks of loss, property damage, or personal injury, including death, that may be sustained by me or any loss or damage to property owned by me, as a result of my participation in HydroDrags events.

3. RELEASE AND WAIVER: I hereby release, waive, discharge, and covenant not to sue HydroDrags, its officers, directors, employees, agents, volunteers, sponsors, and all other persons or entities associated with the event (collectively "Releasees") from all liability to me for any loss or damage, and any claim or demands on account of injury to my person or property, or resulting in my death, arising out of or related to my participation in HydroDrags events.

4. INDEMNIFICATION: I agree to indemnify and hold harmless the Releasees from any loss, liability, damage, or cost they may incur due to my participation in the event.

5. MEDICAL CARE: I consent to receive medical treatment which may be deemed advisable in the event of injury, accident, or illness during my participation.

6. REPRESENTATIONS: I represent that I am physically fit and have no medical conditions that would prevent my safe participation in the event.

BY SIGNING THIS WAIVER, I ACKNOWLEDGE THAT I HAVE READ AND UNDERSTAND THIS RELEASE AND WAIVER OF LIABILITY, AND I VOLUNTARILY AGREE TO BE BOUND BY ITS TERMS.
''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liability Waiver'),
        actions: const [
          LanguageToggle(isCompact: true),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scroll progress indicator
          LinearProgressIndicator(
            value: _hasScrolledToEnd
                ? 1.0
                : _scrollController.hasClients
                    ? (_scrollController.position.pixels / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0)
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
                    'LIABILITY WAIVER AND RELEASE OF CLAIMS',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PLEASE READ CAREFULLY BEFORE SIGNING',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    waiverContent,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 48),
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
                              'Please scroll to the end of the waiver to continue',
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasScrolledToEnd
                      ? () {
                          Navigator.of(context).pushNamed('/waiver-signature');
                        }
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('I Understand'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}