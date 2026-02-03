import 'package:flutter/material.dart';

/// A searchable dropdown widget for selecting from a list of items
class SearchableDropdown<T> extends StatefulWidget {
  final String? value;
  final List<T> items;
  final String Function(T) getLabel;
  final String Function(T) getValue;
  final String? Function(T)? getSearchText;
  final ValueChanged<String?> onChanged;
  final String? labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final VoidCallback? onTap;

  const SearchableDropdown({
    super.key,
    this.value,
    required this.items,
    required this.getLabel,
    required this.getValue,
    this.getSearchText,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.validator,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  void _showSearchDialog() {
    _searchController.clear();
    _isSearching = true;

    showDialog(
      context: context,
      builder: (context) => _SearchDialog<T>(
        items: widget.items,
        searchController: _searchController,
        getLabel: widget.getLabel,
        getValue: widget.getValue,
        getSearchText: widget.getSearchText,
        currentValue: widget.value,
        onItemSelected: (value) {
          widget.onChanged(value);
          Navigator.of(context).pop();
        },
      ),
    ).then((_) {
      setState(() {
        _isSearching = false;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.value != null
        ? widget.items.firstWhere(
            (item) => widget.getValue(item) == widget.value,
            orElse: () => widget.items.first,
          )
        : null;

    return InkWell(
      onTap: widget.enabled ? () {
        widget.onTap?.call();
        _showSearchDialog();
      } : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText ?? 'Tap to select',
          suffixIcon: const Icon(Icons.arrow_drop_down),
          errorText: widget.validator != null && widget.value != null
              ? widget.validator!(widget.value)
              : null,
        ),
        child: Text(
          selectedItem != null ? widget.getLabel(selectedItem) : '',
          style: TextStyle(
            color: widget.value != null
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final List<T> items;
  final TextEditingController searchController;
  final String Function(T) getLabel;
  final String Function(T) getValue;
  final String? Function(T)? getSearchText;
  final String? currentValue;
  final ValueChanged<String?> onItemSelected;

  const _SearchDialog({
    required this.items,
    required this.searchController,
    required this.getLabel,
    required this.getValue,
    this.getSearchText,
    this.currentValue,
    required this.onItemSelected,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final query = widget.searchController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredItems = widget.items;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        final label = widget.getLabel(item).toLowerCase();
        final searchText = widget.getSearchText != null
            ? (widget.getSearchText!(item) ?? '').toLowerCase()
            : label;
        return label.contains(lowerQuery) || searchText.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type to search...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No results found'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final value = widget.getValue(item);
                        final isSelected = widget.currentValue == value;
                        
                        return ListTile(
                          title: Text(widget.getLabel(item)),
                          selected: isSelected,
                          onTap: () => widget.onItemSelected(value),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
