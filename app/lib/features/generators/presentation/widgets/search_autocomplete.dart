import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../providers/generators_providers.dart' show autocompleteProvider;
import 'generator_filter.dart' show filterProvider, GeneratorFilter;

class SearchAutocomplete extends ConsumerStatefulWidget {
  const SearchAutocomplete({
    super.key,
    required this.controller,
    required this.filter,
    required this.onSaveRecent,
  });
  final TextEditingController controller;
  final GeneratorFilter filter;
  final void Function(String) onSaveRecent;

  @override
  ConsumerState<SearchAutocomplete> createState() =>
      _SearchAutocompleteState();
}

class _SearchAutocompleteState extends ConsumerState<SearchAutocomplete> {
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
        () => setState(() => _showSuggestions = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _selectSuggestion(String value) {
    widget.controller.text = value;
    widget.controller.selection =
        TextSelection.collapsed(offset: value.length);
    ref.read(filterProvider.notifier).state =
        widget.filter.withQuery(value);
    widget.onSaveRecent(value);
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final query = widget.filter.query;
    final suggestions =
        ref.watch(autocompleteProvider(query)).valueOrNull ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: (v) => ref
              .read(filterProvider.notifier)
              .state = widget.filter.withQuery(v),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onSaveRecent(v);
            setState(() => _showSuggestions = false);
          },
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: AppLocalizations.of(context)!.close,
                    onPressed: () {
                      if (query.trim().isNotEmpty) widget.onSaveRecent(query);
                      widget.controller.clear();
                      ref.read(filterProvider.notifier).state =
                          widget.filter.withQuery('');
                    },
                  )
                : null,
          ),
        ),
        if (_showSuggestions && suggestions.isNotEmpty)
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: suggestions
                  .map((s) => ListTile(
                        dense: true,
                        leading: Icon(Icons.search,
                            size: 16, color: cs.onSurfaceVariant),
                        title:
                            Text(s, style: const TextStyle(fontSize: 14)),
                        onTap: () => _selectSuggestion(s),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
