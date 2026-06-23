import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show unreadCountProvider;

// Local alias used by the bell badge in this file.
final _unreadCountProvider = unreadCountProvider;

// Search + filter state
enum _SortBy { newest, priceLow, priceHigh, ratingTop, capacityLow }

const _sortLabels = {
  _SortBy.newest: 'Newest first',
  _SortBy.priceLow: 'Price: low → high',
  _SortBy.priceHigh: 'Price: high → low',
  _SortBy.ratingTop: 'Top rated',
  _SortBy.capacityLow: 'Capacity: low → high',
};

class _Filter {
  final String query;
  final String? governorate;
  final double? maxKva;
  final double? maxPrice;
  final String? fuelType;
  final _SortBy sort;

  const _Filter({
    this.query = '',
    this.governorate,
    this.maxKva,
    this.maxPrice,
    this.fuelType,
    this.sort = _SortBy.newest,
  });

  _Filter withQuery(String q) =>
      _Filter(query: q, governorate: governorate, maxKva: maxKva, maxPrice: maxPrice, fuelType: fuelType, sort: sort);
  _Filter withGovernorate(String? g) =>
      _Filter(query: query, governorate: g, maxKva: maxKva, maxPrice: maxPrice, fuelType: fuelType, sort: sort);
  _Filter withMaxKva(double? k) =>
      _Filter(query: query, governorate: governorate, maxKva: k, maxPrice: maxPrice, fuelType: fuelType, sort: sort);
  _Filter withMaxPrice(double? p) =>
      _Filter(query: query, governorate: governorate, maxKva: maxKva, maxPrice: p, fuelType: fuelType, sort: sort);
  _Filter withFuelType(String? f) =>
      _Filter(query: query, governorate: governorate, maxKva: maxKva, maxPrice: maxPrice, fuelType: f, sort: sort);
  _Filter withSort(_SortBy s) =>
      _Filter(query: query, governorate: governorate, maxKva: maxKva, maxPrice: maxPrice, fuelType: fuelType, sort: s);
}

final _filterProvider = StateProvider<_Filter>((ref) => const _Filter());

// Autocomplete suggestions based on partial query (min 2 chars).
final _autocompleteProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, q) async {
  if (q.length < 2) return [];
  final data = await supabase
      .from('generators')
      .select('title, city, governorate')
      .or('title.ilike.%$q%,city.ilike.%$q%')
      .eq('is_available', true)
      .limit(8);
  final suggestions = <String>{};
  for (final g in (data as List)) {
    final title = g['title']?.toString() ?? '';
    final city = g['city']?.toString() ?? '';
    if (title.toLowerCase().contains(q.toLowerCase())) suggestions.add(title);
    if (city.toLowerCase().contains(q.toLowerCase())) suggestions.add(city);
  }
  return suggestions.take(6).toList();
});

// Tracks recent non-empty search terms within the current session (max 5).
final _recentSearchesProvider =
    StateProvider<List<String>>((ref) => const []);

// Loads the current user's saved generator IDs from Supabase (if logged in).
final _remoteFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('user_favorites')
      .select('generator_id')
      .eq('user_id', uid);
  return {for (final r in (data as List)) r['generator_id'].toString()};
});

// In-session saved/favourite generator IDs — seeded from Supabase on first load.
final favoritesProvider =
    StateProvider<Set<String>>((ref) => const {});

// When true, the generator list shows only saved generators.
final _showFavoritesOnlyProvider =
    StateProvider<bool>((ref) => false);

final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count')
      .eq('status', 'available')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  bool _favoritesSeeded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _seedFavoritesIfNeeded(Set<String> remote) {
    if (_favoritesSeeded || remote.isEmpty) return;
    _favoritesSeeded = true;
    if (ref.read(favoritesProvider).isEmpty) {
      ref.read(favoritesProvider.notifier).state = remote;
    }
  }

  void _saveRecentSearch(String term) {
    final trimmed = term.trim();
    if (trimmed.length < 2) return;
    final current = ref.read(_recentSearchesProvider);
    final updated = [
      trimmed,
      ...current.where((s) => s != trimmed),
    ].take(5).toList();
    ref.read(_recentSearchesProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final allGenerators = ref.watch(generatorsProvider);
    final filter = ref.watch(_filterProvider);
    final recentSearches = ref.watch(_recentSearchesProvider);
    final showFavoritesOnly = ref.watch(_showFavoritesOnlyProvider);
    final favorites = ref.watch(favoritesProvider);
    final loggedIn = supabase.auth.currentSession != null;
    final cs = Theme.of(context).colorScheme;

    // Seed local favorites from Supabase once on first build.
    ref.watch(_remoteFavoritesProvider).whenData(_seedFavoritesIfNeeded);

    // Apply client-side filter
    final generators = allGenerators.whenData((items) => items.where((g) {
      if (showFavoritesOnly &&
          !favorites.contains(g['id']?.toString() ?? '')) {
        return false;
      }
      final q = filter.query.toLowerCase();
      if (q.isNotEmpty) {
        final title = (g['title'] ?? '').toString().toLowerCase();
        final city = (g['city'] ?? '').toString().toLowerCase();
        final gov = (g['governorate'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !city.contains(q) && !gov.contains(q)) {
          return false;
        }
      }
      if (filter.governorate != null &&
          filter.governorate!.isNotEmpty &&
          (g['governorate'] ?? '') != filter.governorate) {
        return false;
      }
      if (filter.maxKva != null) {
        final kva = double.tryParse(g['capacity_kva']?.toString() ?? '0') ?? 0;
        if (kva > filter.maxKva!) return false;
      }
      if (filter.maxPrice != null) {
        final price =
            double.tryParse(g['price_per_day']?.toString() ?? '0') ?? 0;
        if (price > filter.maxPrice!) return false;
      }
      if (filter.fuelType != null &&
          (g['fuel_type'] ?? 'diesel') != filter.fuelType) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        switch (filter.sort) {
          case _SortBy.priceLow:
            return (a['price_per_day'] as num)
                .compareTo(b['price_per_day'] as num);
          case _SortBy.priceHigh:
            return (b['price_per_day'] as num)
                .compareTo(a['price_per_day'] as num);
          case _SortBy.ratingTop:
            final ra = (a['avg_score'] as num?)?.toDouble() ?? 0;
            final rb = (b['avg_score'] as num?)?.toDouble() ?? 0;
            return rb.compareTo(ra);
          case _SortBy.capacityLow:
            return (a['capacity_kva'] as num)
                .compareTo(b['capacity_kva'] as num);
          case _SortBy.newest:
            return 0; // DB already ordered by created_at desc
        }
      }));

    final hasFilter = filter.query.isNotEmpty ||
        filter.governorate != null ||
        filter.maxKva != null ||
        filter.maxPrice != null ||
        filter.fuelType != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(generatorsProvider);
          ref.invalidate(_remoteFavoritesProvider);
        },
        child: CustomScrollView(
        slivers: [
          // ── Brand header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            actions: [
              if (loggedIn) ...[
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'My Rentals',
                  onPressed: () => context.push('/my-rentals'),
                ),
                // Notification bell with unread badge
                Consumer(
                  builder: (context, watchRef, _) {
                    final count = watchRef
                        .watch(_unreadCountProvider)
                        .valueOrNull ?? 0;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: IconButton(
                        icon: const Icon(
                            Icons.notifications_outlined),
                        tooltip: 'Notifications',
                        onPressed: () =>
                            context.push('/notifications'),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.person_outline,
                        size: 18, color: cs.onPrimaryContainer),
                  ),
                  onPressed: () => context.push('/profile'),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => context.push('/login'),
                    child: Text(l.loginTitle,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.blurBackground],
              background: _HeroBanner(cs: cs, l: l),
            ),
          ),

          // ── Search bar + filter ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchAutocomplete(
                      controller: _searchController,
                      filter: filter,
                      ref: ref,
                      onSaveRecent: _saveRecentSearch,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: hasFilter && filter.query.isEmpty
                        ? (filter.governorate != null || filter.maxKva != null)
                        : false,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: hasFilter
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        foregroundColor:
                            hasFilter ? cs.onPrimary : cs.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.tune),
                      onPressed: () =>
                          _showFilterSheet(context, ref, filter, cs),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Active filter pills ───────────────────────────────────────
          if (filter.governorate != null || filter.maxKva != null || filter.maxPrice != null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  children: [
                    if (filter.governorate != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text(filter.governorate!,
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => ref
                              .read(_filterProvider.notifier)
                              .state = filter.withGovernorate(null),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (filter.maxKva != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text('≤ ${filter.maxKva!.toInt()} KVA',
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => ref
                              .read(_filterProvider.notifier)
                              .state = filter.withMaxKva(null),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (filter.maxPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text('≤ ${filter.maxPrice!.toInt()} EGP',
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => ref
                              .read(_filterProvider.notifier)
                              .state = filter.withMaxPrice(null),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (filter.fuelType != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          avatar: const Icon(Icons.local_gas_station_outlined,
                              size: 12),
                          label: Text(
                              _fuelLabel(filter.fuelType!),
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () => ref
                              .read(_filterProvider.notifier)
                              .state = filter.withFuelType(null),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── Governorate quick-chips ───────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final gov in [
                    'Cairo', 'Giza', 'Alexandria', 'Minya',
                    'Assiut', 'Sharqia', 'Aswan', 'Luxor'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.location_on_outlined, size: 12),
                        label: Text(gov,
                            style: const TextStyle(fontSize: 12)),
                        selected: filter.governorate == gov,
                        onSelected: (on) => ref
                            .read(_filterProvider.notifier)
                            .state = filter.withGovernorate(on ? gov : null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Recent searches ───────────────────────────────────────────
          if (filter.query.isEmpty && recentSearches.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: recentSearches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final term = recentSearches[i];
                    return ActionChip(
                      avatar: Icon(Icons.history,
                          size: 14, color: cs.onSurfaceVariant),
                      label: Text(term,
                          style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.text = term;
                        ref.read(_filterProvider.notifier).state =
                            filter.withQuery(term);
                      },
                    );
                  },
                ),
              ),
            ),

          // ── Quick KVA filters ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final kva in [50.0, 100.0, 200.0, 500.0])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('≤ ${kva.toInt()} KVA'),
                        selected: filter.maxKva == kva,
                        onSelected: (on) => ref
                            .read(_filterProvider.notifier)
                            .state = filter.withMaxKva(on ? kva : null),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    hasFilter ? 'Results' : 'Available generators',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const Spacer(),
                  generators.maybeWhen(
                    data: (items) => Text(
                      '${items.length} found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  // Saved filter toggle
                  Consumer(
                    builder: (context, ref, _) {
                      final favs = ref.watch(favoritesProvider);
                      final showingFavs =
                          ref.watch(_showFavoritesOnlyProvider);
                      if (favs.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => ref
                            .read(_showFavoritesOnlyProvider.notifier)
                            .state = !showingFavs,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: showingFavs
                                ? Colors.red.shade100
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 13,
                                color: showingFavs
                                    ? Colors.red.shade600
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${favs.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: showingFavs
                                      ? Colors.red.shade600
                                      : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () => _showSortSheet(context, ref, filter, cs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: filter.sort != _SortBy.newest
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort,
                              size: 14,
                              color: filter.sort != _SortBy.newest
                                  ? cs.primary
                                  : cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            filter.sort == _SortBy.newest
                                ? 'Sort'
                                : _sortLabels[filter.sort]!.split(':').first.trim(),
                            style: TextStyle(
                              fontSize: 11,
                              color: filter.sort != _SortBy.newest
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Generator list ────────────────────────────────────────────
          generators.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(generatorsProvider)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  child: hasFilter
                      ? _NoResultsState(
                          onClear: () => ref
                              .read(_filterProvider.notifier)
                              .state = const _Filter(),
                        )
                      : _EmptyState(l: l),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _GeneratorCard(generator: items[i], cs: cs),
                ),
              );
            },
          ),
        ],
        ),
      ),
    );
  }

  void _showSortSheet(
      BuildContext context, WidgetRef ref, _Filter filter, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Sort by',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 12),
            ..._SortBy.values.map((s) => RadioListTile<_SortBy>(
                  title: Text(_sortLabels[s]!),
                  value: s,
                  groupValue: filter.sort,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(_filterProvider.notifier).state =
                          filter.withSort(v);
                    }
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, _Filter filter, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(filter: filter, ref: ref, cs: cs),
    );
  }
}

// ── Hero banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.cs, required this.l});
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.6),
            cs.secondaryContainer.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt,
                        color: cs.onPrimary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AnDaLoeS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.welcomeSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search autocomplete ───────────────────────────────────────────────────────
class _SearchAutocomplete extends ConsumerStatefulWidget {
  const _SearchAutocomplete({
    required this.controller,
    required this.filter,
    required this.ref,
    required this.onSaveRecent,
    required this.cs,
  });
  final TextEditingController controller;
  final _Filter filter;
  final WidgetRef ref;
  final void Function(String) onSaveRecent;
  final ColorScheme cs;

  @override
  ConsumerState<_SearchAutocomplete> createState() =>
      _SearchAutocompleteState();
}

class _SearchAutocompleteState extends ConsumerState<_SearchAutocomplete> {
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    });
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
    widget.ref.read(_filterProvider.notifier).state =
        widget.filter.withQuery(value);
    widget.onSaveRecent(value);
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.filter.query;
    final suggestionsAsync =
        ref.watch(_autocompleteProvider(query));
    final suggestions = suggestionsAsync.valueOrNull ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: (v) {
            widget.ref.read(_filterProvider.notifier).state =
                widget.filter.withQuery(v);
          },
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) widget.onSaveRecent(v);
            setState(() => _showSuggestions = false);
          },
          decoration: InputDecoration(
            hintText: 'Search generators, city…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      if (query.trim().isNotEmpty) widget.onSaveRecent(query);
                      widget.controller.clear();
                      widget.ref.read(_filterProvider.notifier).state =
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
              children: suggestions.map((s) {
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.search,
                      size: 16, color: widget.cs.onSurfaceVariant),
                  title: Text(s, style: const TextStyle(fontSize: 14)),
                  onTap: () => _selectSuggestion(s),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

String _fuelLabel(String fuel) => switch (fuel) {
      'diesel' => 'Diesel',
      'gas' => 'Gas',
      'natural_gas' => 'Natural Gas',
      'solar' => 'Solar',
      'petrol' => 'Petrol',
      _ => fuel,
    };

// ── Generator card ───────────────────────────────────────────────────────────
class _GeneratorCard extends ConsumerWidget {
  const _GeneratorCard({required this.generator, required this.cs});
  final Map<String, dynamic> generator;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = generator['id']?.toString() ?? '';
    final isFav = ref.watch(favoritesProvider).contains(id);
    final location = [
      generator['city'],
      generator['governorate'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/generators/${generator['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Photo thumbnail or icon accent
              _CardPhoto(
                photos: (generator['photos'] as List?)?.cast<String>() ?? [],
                cs: cs,
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            generator['title']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((generator['avg_score'] as num?)
                                    ?.toDouble() !=
                                null &&
                            (generator['avg_score'] as num).toDouble() >=
                                4.5 &&
                            (generator['rating_count'] as num?)
                                    ?.toInt() !=
                                null &&
                            (generator['rating_count'] as num).toInt() >=
                                3)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 10,
                                    color: Colors.amber.shade700),
                                const SizedBox(width: 2),
                                Text(
                                  'Top',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.electric_bolt,
                          label:
                              '${generator['capacity_kva']} KVA',
                          cs: cs,
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Chip(
                            icon: Icons.location_on_outlined,
                            label: location,
                            cs: cs,
                          ),
                        ],
                      ],
                    ),
                    if ((generator['rating_count'] as num?)?.toInt() != null &&
                        (generator['rating_count'] as num).toInt() > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            '${generator['avg_score']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            '  (${generator['rating_count']})',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Price + save button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final current = ref.read(favoritesProvider);
                      final next = Set<String>.from(current);
                      final uid = supabase.auth.currentUser?.id;
                      if (next.contains(id)) {
                        next.remove(id);
                        if (uid != null) {
                          supabase
                              .from('user_favorites')
                              .delete()
                              .eq('user_id', uid)
                              .eq('generator_id', id)
                              .then((_) {});
                        }
                      } else {
                        next.add(id);
                        if (uid != null) {
                          supabase
                              .from('user_favorites')
                              .upsert({
                                'user_id': uid,
                                'generator_id': id,
                              })
                              .then((_) {});
                        }
                      }
                      ref.read(favoritesProvider.notifier).state = next;
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(isFav),
                        size: 20,
                        color: isFav ? Colors.red.shade400 : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${generator['price_per_day']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'EGP/day',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.cs});
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Empty & error states ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bolt, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No generators yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generators listed by owners will appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No generators match',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Try adjusting your filters.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────
const _egyptGovernorates = [
  'Cairo', 'Giza', 'Alexandria', 'Dakahlia', 'Red Sea', 'Beheira',
  'Fayoum', 'Gharbia', 'Ismailia', 'Menofia', 'Minya', 'Qaliubiya',
  'New Valley', 'Suez', 'Aswan', 'Assiut', 'Beni Suef', 'Port Said',
  'Damietta', 'Sharqia', 'South Sinai', 'Kafr El Sheikh', 'Matrouh',
  'Luxor', 'Qena', 'North Sinai', 'Sohag',
];

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.filter, required this.ref, required this.cs});
  final _Filter filter;
  final WidgetRef ref;
  final ColorScheme cs;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _governorate;
  late double? _maxKva;
  late double? _maxPrice;
  late String? _fuelType;

  static const _fuelOptions = [
    ('diesel', 'Diesel'),
    ('petrol', 'Petrol'),
    ('gas', 'Gas'),
    ('natural_gas', 'Natural Gas'),
    ('solar', 'Solar'),
  ];

  @override
  void initState() {
    super.initState();
    _governorate = widget.filter.governorate;
    _maxKva = widget.filter.maxKva;
    _maxPrice = widget.filter.maxPrice;
    _fuelType = widget.filter.fuelType;
  }

  void _apply() {
    widget.ref.read(_filterProvider.notifier).state = widget.filter
        .withGovernorate(_governorate)
        .withMaxKva(_maxKva)
        .withMaxPrice(_maxPrice)
        .withFuelType(_fuelType);
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _governorate = null;
      _maxKva = null;
      _maxPrice = null;
      _fuelType = null;
    });
    widget.ref.read(_filterProvider.notifier).state = widget.filter
        .withGovernorate(null)
        .withMaxKva(null)
        .withMaxPrice(null)
        .withFuelType(null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Filter',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(onPressed: _clear, child: const Text('Clear all')),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Governorate',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _governorate,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            hint: const Text('Any governorate'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              ..._egyptGovernorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g))),
            ],
            onChanged: (v) => setState(() => _governorate = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Max capacity (KVA)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(
                _maxKva == null ? 'Any' : '≤ ${_maxKva!.toInt()} KVA',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: _maxKva ?? 1000,
            min: 10,
            max: 1000,
            divisions: 99,
            label: _maxKva == null
                ? 'Any'
                : '${_maxKva!.toInt()} KVA',
            onChanged: (v) => setState(() => _maxKva = v),
          ),
          if (_maxKva != null && _maxKva == 1000)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _maxKva = null),
                child: const Text('Remove limit'),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Max daily price (EGP)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text(
                _maxPrice == null ? 'Any' : '≤ ${_maxPrice!.toInt()} EGP',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: _maxPrice ?? 5000,
            min: 100,
            max: 5000,
            divisions: 49,
            label: _maxPrice == null
                ? 'Any'
                : '${_maxPrice!.toInt()} EGP',
            onChanged: (v) => setState(() => _maxPrice = v < 5000 ? v : null),
          ),
          if (_maxPrice != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _maxPrice = null),
                child: const Text('Remove limit'),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'FUEL TYPE',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fuelOptions.map((opt) {
              final (value, label) = opt;
              final selected = _fuelType == value;
              return FilterChip(
                avatar: Icon(Icons.local_gas_station_outlined,
                    size: 12,
                    color: selected
                        ? widget.cs.onSecondaryContainer
                        : widget.cs.onSurfaceVariant),
                label: Text(label,
                    style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (on) => setState(
                    () => _fuelType = on ? value : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _apply, child: const Text('Apply filters')),
        ],
      ),
    );
  }
}

// ── Card photo thumbnail ──────────────────────────────────────────────────────
class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.photos, required this.cs});
  final List<String> photos;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.bolt, color: cs.primary, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        photos.first,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 52,
          height: 52,
          color: cs.primaryContainer,
          child: Icon(Icons.bolt, color: cs.primary, size: 28),
        ),
      ),
    );
  }
}
