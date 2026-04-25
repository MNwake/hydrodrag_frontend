import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/hydrodrags_config.dart';
import '../services/hydrodrags_config_service.dart';

class RulesTabScreen extends StatefulWidget {
  const RulesTabScreen({super.key});

  @override
  State<RulesTabScreen> createState() => _RulesTabScreenState();
}

class _RulesTabScreenState extends State<RulesTabScreen> {
  final HydroDragsConfigService _configService = HydroDragsConfigService();
  final TextEditingController _searchController = TextEditingController();

  HydroDragsConfig? _config;
  bool _loading = true;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = await _configService.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<RuleCategory> _filteredRules(List<RuleCategory> categories) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return categories;

    return categories
        .map((category) {
          final matchedRules = category.rules.where((rule) {
            return rule.title.toLowerCase().contains(query) ||
                rule.description.toLowerCase().contains(query);
          }).toList();

          if (category.category.toLowerCase().contains(query)) {
            return category;
          }

          return RuleCategory(category: category.category, rules: matchedRules);
        })
        .where((category) => category.rules.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allCategories = _config?.rules ?? const <RuleCategory>[];
    final visibleCategories = _filteredRules(allCategories);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rulesTab)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState(context)
          : RefreshIndicator(
              onRefresh: _loadConfig,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _buildSearchField(context),
                  const SizedBox(height: 12),
                  if (visibleCategories.isEmpty)
                    _buildEmptyState(context, allCategories.isEmpty)
                  else
                    ...visibleCategories.map(
                      (category) => _buildCategoryCard(context, category),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close),
              ),
        hintText: 'Search rules',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, RuleCategory category) {
    final visibleRules = category.rules.where(
      (rule) => rule.title.isNotEmpty || rule.description.isNotEmpty,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: _query.isNotEmpty,
        title: Text(
          category.category.isEmpty ? 'General' : category.category,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [
          ...visibleRules.map((rule) => _buildRuleTile(context, rule)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRuleTile(BuildContext context, RuleItem rule) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.rule_folder_outlined),
      title: Text(
        rule.title.isNotEmpty ? rule.title : 'Rule',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: rule.description.isEmpty ? null : Text(rule.description),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool noServerRules) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          noServerRules
              ? 'Rules are not published yet. Pull to refresh and check back soon.'
              : 'No rules match your search.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.serverUnavailableTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$_error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadConfig,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
