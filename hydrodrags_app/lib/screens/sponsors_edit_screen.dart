import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_toggle.dart';

/// Full-screen screen for editing racer sponsors list.
/// Automatically saves changes when sponsors are added or removed.
class SponsorsEditScreen extends StatefulWidget {
  final List<String> initialSponsors;
  final Function(List<String>)? onSponsorsChanged;

  const SponsorsEditScreen({
    super.key,
    this.initialSponsors = const [],
    this.onSponsorsChanged,
  });

  @override
  State<SponsorsEditScreen> createState() => _SponsorsEditScreenState();
}

class _SponsorsEditScreenState extends State<SponsorsEditScreen> {
  late List<String> _items;
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initialSponsors);
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _saveSponsors() {
    widget.onSponsorsChanged?.call(List<String>.from(_items));
  }

  void _add() {
    final t = _addController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.add(t);
      _addController.clear();
    });
    _saveSponsors();
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
    _saveSponsors();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editSponsors ?? 'Edit Sponsors'),
        actions: [
          const LanguageToggle(isCompact: true),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No sponsors yet. Add one below.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final sponsor = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.star,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(sponsor),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _remove(index),
                            tooltip: 'Remove',
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    focusNode: _addFocus,
                    decoration: InputDecoration(
                      labelText: l10n.sponsors ?? 'Sponsors',
                      hintText: 'Add sponsor',
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
