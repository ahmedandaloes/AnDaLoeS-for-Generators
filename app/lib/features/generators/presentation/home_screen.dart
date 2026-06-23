import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/providers/notifications_providers.dart'
    show unreadCountProvider;
import '../providers/generators_providers.dart';
import 'widgets/fuel_chip.dart' show fuelLabel;
import 'widgets/generator_card.dart';
import 'widgets/generator_filter.dart';
import 'widgets/search_autocomplete.dart';
import '../../../core/routing/app_routes.dart';

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
    final current = ref.read(recentSearchesProvider);
    final updated = [trimmed, ...current.where((s) => s != trimmed)]
        .take(5)
        .toList();
    ref.read(recentSearchesProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final allGenerators = ref.watch(generatorsProvider);
    final filter = ref.watch(filterProvider);
    final recentSearches = ref.watch(recentSearchesProvider);
    final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
    final favorites = ref.watch(favoritesProvider);
    final loggedIn = supabase.auth.currentSession != null;
    final cs = Theme.of(context).colorScheme;

    ref.watch(remoteFavoritesProvider).whenData(_seedFavoritesIfNeeded);

    // Client-side filter + sort
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
              (g['governorate'] ?? '') != filter.governorate) return false;
          if (filter.maxKva != null) {
            final kva =
                double.tryParse(g['capacity_kva']?.toString() ?? '0') ?? 0;
            if (kva > filter.maxKva!) return false;
          }
          if (filter.maxPrice != null) {
            final price =
                double.tryParse(g['price_per_day']?.toString() ?? '0') ?? 0;
            if (price > filter.maxPrice!) return false;
          }
          if (filter.fuelType != null &&
              (g['fuel_type'] ?? 'diesel') != filter.fuelType) return false;
          return true;
        }).toList()
          ..sort((a, b) => switch (filter.sort) {
                GeneratorSortBy.priceLow =>
                  (a['price_per_day'] as num).compareTo(b['price_per_day'] as num),
                GeneratorSortBy.priceHigh =>
                  (b['price_per_day'] as num).compareTo(a['price_per_day'] as num),
                GeneratorSortBy.ratingTop =>
                  ((b['avg_score'] as num?)?.toDouble() ?? 0)
                      .compareTo((a['avg_score'] as num?)?.toDouble() ?? 0),
                GeneratorSortBy.capacityLow =>
                  (a['capacity_kva'] as num).compareTo(b['capacity_kva'] as num),
                GeneratorSortBy.newest => 0,
              }));

    final hasFilter = filter.hasActiveFilters || filter.query.isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(generatorsProvider);
          ref.invalidate(remoteFavoritesProvider);
        },
        child: CustomScrollView(slivers: [
          // ── Brand header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Map view',
                onPressed: () => context.push(AppRoutes.map),
              ),
              if (loggedIn) ...[
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'My Rentals',
                  onPressed: () => context.push(AppRoutes.myRentals),
                ),
                Consumer(
                  builder: (context, watchRef, _) {
                    final count =
                        watchRef.watch(unreadCountProvider).valueOrNull ?? 0;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Notifications',
                        onPressed: () => context.push(AppRoutes.notifications),
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
                  onPressed: () => context.push(AppRoutes.profile),
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
                    onPressed: () => context.push(AppRoutes.login),
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

          // ── Search + filter button ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(
                  child: SearchAutocomplete(
                    controller: _searchController,
                    filter: filter,
                    onSaveRecent: _saveRecentSearch,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: filter.hasActiveFilters &&
                      filter.query.isEmpty,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: filter.hasActiveFilters
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      foregroundColor: filter.hasActiveFilters
                          ? cs.onPrimary
                          : cs.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.tune),
                    onPressed: () => _showFilterSheet(context, filter),
                  ),
                ),
              ]),
            ),
          ),

          // ── Active filter pills ───────────────────────────────────────
          if (filter.hasActiveFilters)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  children: [
                    if (filter.governorate != null)
                      _filterPill(filter.governorate!, () => ref
                          .read(filterProvider.notifier)
                          .state = filter.withGovernorate(null)),
                    if (filter.maxKva != null)
                      _filterPill('≤ ${filter.maxKva!.toInt()} KVA', () => ref
                          .read(filterProvider.notifier)
                          .state = filter.withMaxKva(null)),
                    if (filter.maxPrice != null)
                      _filterPill('≤ ${filter.maxPrice!.toInt()} EGP', () => ref
                          .read(filterProvider.notifier)
                          .state = filter.withMaxPrice(null)),
                    if (filter.fuelType != null)
                      _filterPill(fuelLabel(filter.fuelType!), () => ref
                          .read(filterProvider.notifier)
                          .state = filter.withFuelType(null)),
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
                    'Assiut', 'Sharqia', 'Aswan', 'Luxor',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.location_on_outlined, size: 12),
                        label: Text(gov, style: const TextStyle(fontSize: 12)),
                        selected: filter.governorate == gov,
                        onSelected: (on) => ref
                            .read(filterProvider.notifier)
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
                      label:
                          Text(term, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.text = term;
                        ref.read(filterProvider.notifier).state =
                            filter.withQuery(term);
                      },
                    );
                  },
                ),
              ),
            ),

          // ── Governorate quick-filter chips ────────────────────────────
          SliverToBoxAdapter(
            child: _GovernorateChips(ref: ref, filter: filter),
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
                            .read(filterProvider.notifier)
                            .state = filter.withMaxKva(on ? kva : null),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Top Rated carousel ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _FeaturedCarousel(ref: ref, cs: cs),
          ),

          // ── New arrivals ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Consumer(
              builder: (_, ref, __) {
                final newAsync = ref.watch(newArrivalsProvider);
                return newAsync.maybeWhen(
                  data: (items) => items.isEmpty
                      ? const SizedBox.shrink()
                      : _NewArrivalsSection(items: items, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          ),

          // ── Popular in your area ─────────────────────────────────────
          SliverToBoxAdapter(
            child: generators.maybeWhen(
              data: (items) => _PopularInArea(
                  items: items, cs: cs, ref: ref),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // ── Recently viewed ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _RecentlyViewed(ref: ref, cs: cs),
          ),

          // ── Near me ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _NearMeSection(ref: ref, cs: cs),
          ),

          // ── Section header + sort ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                Text(
                  hasFilter ? 'Results' : 'Available generators',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.3),
                ),
                const Spacer(),
                generators.maybeWhen(
                  data: (items) => Text('${items.length} found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant)),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Consumer(builder: (context, ref, _) {
                  final favs = ref.watch(favoritesProvider);
                  final showingFavs = ref.watch(showFavoritesOnlyProvider);
                  if (favs.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => ref
                        .read(showFavoritesOnlyProvider.notifier)
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
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.favorite_rounded,
                            size: 13,
                            color: showingFavs
                                ? Colors.red.shade600
                                : cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${favs.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: showingFavs
                                  ? Colors.red.shade600
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            )),
                      ]),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () => _showSortSheet(context, filter),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: filter.sort != GeneratorSortBy.newest
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sort,
                          size: 14,
                          color: filter.sort != GeneratorSortBy.newest
                              ? cs.primary
                              : cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        filter.sort == GeneratorSortBy.newest
                            ? 'Sort'
                            : sortLabels[filter.sort]!.split(':').first.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          color: filter.sort != GeneratorSortBy.newest
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── Generator list ────────────────────────────────────────────
          generators.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _SkeletonCard(),
                childCount: 5,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(generatorsProvider)),
            ),
            data: (items) {
              if (items.isEmpty) {
                // Use SliverToBoxAdapter (not SliverFillRemaining) so the
                // featured carousel above remains accessible via scroll.
                return SliverToBoxAdapter(
                  child: hasFilter
                      ? _NoResultsState(
                          onClear: () => ref
                              .read(filterProvider.notifier)
                              .state = const GeneratorFilter(),
                          filterSummary: [
                            if (filter.query.isNotEmpty) '"${filter.query}"',
                            if (filter.governorate != null &&
                                filter.governorate!.isNotEmpty)
                              filter.governorate!,
                            if (filter.maxKva != null)
                              '≤ ${filter.maxKva!.toStringAsFixed(0)} KVA',
                            if (filter.maxPrice != null)
                              '≤ EGP ${filter.maxPrice}',
                          ].join(' · '),
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
                      GeneratorCard(generator: items[i]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _filterPill(String label, VoidCallback onDelete) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: onDelete,
          visualDensity: VisualDensity.compact,
        ),
      );

  void _showSortSheet(BuildContext context, GeneratorFilter filter) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Sort by',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
            const SizedBox(height: 12),
            ...GeneratorSortBy.values.map((s) => RadioListTile<GeneratorSortBy>(
                  title: Text(sortLabels[s]!),
                  value: s,
                  groupValue: filter.sort,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(filterProvider.notifier)
                          .state = filter.withSort(v);
                    }
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, GeneratorFilter filter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FilterSheet(filter: filter, ref: ref),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

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
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bolt, color: cs.onPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('AnDaLoeS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    )),
              ]),
              const SizedBox(height: 8),
              Text(l.welcomeSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeleton loading card ─────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final base = cs.surfaceContainerLow;
        final highlight = cs.surfaceContainerHighest;
        final color = Color.lerp(base, highlight, _anim.value)!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              // Photo placeholder
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(15)),
                child: Container(width: 100, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6))),
                      Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6))),
                      Row(children: [
                        Container(
                            height: 22,
                            width: 60,
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20))),
                        const SizedBox(width: 8),
                        Container(
                            height: 22,
                            width: 70,
                            decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20))),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ),
        );
      },
    );
  }
}

// ── Empty / error / no-results states ────────────────────────────────────────

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
                  color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.bolt, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('No generators yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Generators listed by owners will appear here.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
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
                onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onClear, this.filterSummary});
  final VoidCallback onClear;
  final String? filterSummary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Layered ring illustration
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest,
                ),
                child: Icon(Icons.search_off_rounded,
                    size: 26, color: cs.onSurfaceVariant),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('No generators match',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (filterSummary != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  filterSummary!,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Try different KVA, city, or price range.',
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onClear,
                child: const Text('Clear all filters')),
          ],
        ),
      ),
    );
  }
}

// ── Top Rated Featured Carousel ───────────────────────────────────────────────
class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({required this.ref, required this.cs});
  final WidgetRef ref;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(featuredGeneratorsProvider);
    return featuredAsync.when(
      loading: () => _FeaturedSkeleton(cs: cs),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(children: [
                Icon(Icons.star_rounded,
                    size: 16, color: Colors.amber.shade600),
                const SizedBox(width: 6),
                Text('Top Rated',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ]),
            ),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    _FeaturedCard(gen: items[i], cs: cs),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

// ── Featured carousel skeleton ────────────────────────────────────────────────
class _FeaturedSkeleton extends StatefulWidget {
  const _FeaturedSkeleton({required this.cs});
  final ColorScheme cs;

  @override
  State<_FeaturedSkeleton> createState() => _FeaturedSkeletonState();
}

class _FeaturedSkeletonState extends State<_FeaturedSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              width: 90,
              height: 14,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest
                    .withValues(alpha: 0.4 + 0.4 * _anim.value),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Container(
                width: 150,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                      .withValues(alpha: 0.3 + 0.35 * _anim.value),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final photo = (gen['photos'] as List?)?.isNotEmpty == true
        ? gen['photos'][0].toString()
        : null;
    final score = (gen['avg_score'] as num?)?.toStringAsFixed(1) ?? '–';
    final id = gen['id'].toString();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.generatorDetail(id)),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerLow,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: photo != null
                  ? Image.network(
                      photo,
                      height: 90,
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gen['title']?.toString() ?? 'Generator',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.star_rounded,
                        size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text(score,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      'EGP ${gen['price_per_day']}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.primary),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 10, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        gen['city']?.toString() ?? '',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 90,
        width: 150,
        color: cs.primaryContainer,
        child: Icon(Icons.bolt, size: 36, color: cs.primary),
      );
}

// ── New Arrivals Section ──────────────────────────────────────────────────────
class _NewArrivalsSection extends StatelessWidget {
  const _NewArrivalsSection({required this.items, required this.cs});
  final List<Map<String, dynamic>> items;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('New this week',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green)),
              ]),
            ),
            const SizedBox(width: 10),
            Text('New Arrivals',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${items.length}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant)),
            ),
          ]),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                _NewArrivalCard(gen: items[i], cs: cs),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _NewArrivalCard extends StatelessWidget {
  const _NewArrivalCard({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return 'New';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'New';
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final photo = photos.isNotEmpty ? photos.first : null;
    final kva = gen['capacity_kva'];
    final price = gen['price_per_day'];
    final city = gen['city']?.toString();
    final title = gen['title']?.toString() ?? '-';
    final age = _timeAgo(gen['created_at']?.toString());

    return GestureDetector(
      onTap: () => context.push(AppRoutes.generatorDetail(gen['id'].toString())),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.green.withValues(alpha: 0.3)),
          color: cs.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                  child: photo != null
                      ? Image.network(photo,
                          height: 76, width: 140, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                height: 76,
                                color: cs.primaryContainer,
                                child: Icon(Icons.bolt,
                                    size: 28, color: cs.primary),
                              ))
                      : Container(
                          height: 76,
                          color: cs.primaryContainer,
                          child: Icon(Icons.bolt,
                              size: 28, color: cs.primary),
                        ),
                ),
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(age,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (kva != null || city != null)
                    Text(
                      [if (kva != null) '$kva KVA', if (city != null) city]
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant),
                    ),
                  if (price != null) ...[
                    const SizedBox(height: 2),
                    Text('EGP $price/day',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Popular In Area Section ───────────────────────────────────────────────────
class _PopularInArea extends StatelessWidget {
  const _PopularInArea(
      {required this.items, required this.cs, required this.ref});
  final List<Map<String, dynamic>> items;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Find most common city
    final cityCount = <String, int>{};
    for (final g in items) {
      final city = g['city']?.toString() ?? '';
      if (city.isNotEmpty) cityCount[city] = (cityCount[city] ?? 0) + 1;
    }
    if (cityCount.isEmpty) return const SizedBox.shrink();

    final topCity = cityCount.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final cityItems = items
        .where((g) => g['city']?.toString() == topCity)
        .take(6)
        .toList();
    if (cityItems.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(children: [
            Icon(Icons.location_city_rounded,
                size: 16, color: cs.secondary),
            const SizedBox(width: 6),
            Text('Popular in $topCity',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${cityItems.length}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer)),
            ),
          ]),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            itemCount: cityItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                _PopularCard(gen: cityItems[i], cs: cs),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final photo = photos.isNotEmpty ? photos.first : null;
    final kva = gen['capacity_kva'];
    final price = gen['price_per_day'];
    final score = gen['avg_score'];
    final title = gen['title']?.toString() ?? '-';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.generatorDetail(gen['id'].toString())),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4)),
          color: cs.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: photo != null
                  ? Image.network(photo,
                      height: 80, width: 130, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: cs.primaryContainer,
                            child: Icon(Icons.bolt,
                                size: 28, color: cs.primary),
                          ))
                  : Container(
                      height: 80,
                      color: cs.primaryContainer,
                      child:
                          Icon(Icons.bolt, size: 28, color: cs.primary),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (kva != null) ...[
                      Text('$kva KVA',
                          style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(width: 6),
                    ],
                    if (score != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded,
                            size: 10, color: Colors.amber.shade600),
                        Text('$score',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant)),
                      ]),
                  ]),
                  if (price != null) ...[
                    const SizedBox(height: 2),
                    Text('EGP $price/day',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recently Viewed Section ───────────────────────────────────────────────────
class _RecentlyViewed extends StatelessWidget {
  const _RecentlyViewed({required this.ref, required this.cs});
  final WidgetRef ref;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentlyViewedProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Row(children: [
            Icon(Icons.history_rounded,
                size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Recently viewed',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  ref.read(recentlyViewedProvider.notifier).state = [],
              child: Text('Clear',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          cs.onSurfaceVariant.withValues(alpha: 0.4))),
            ),
          ]),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                _RecentCard(gen: recent[i], cs: cs),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final photo = photos.isNotEmpty ? photos.first : null;
    final title = gen['title']?.toString() ?? '-';
    final price = gen['price_per_day'];
    final city = gen['city']?.toString() ?? '';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.generatorDetail(gen['id'].toString())),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          // Photo strip on left
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(11)),
            child: photo != null
                ? Image.network(photo,
                    width: 44, height: 88, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          color: cs.primaryContainer,
                          child: Icon(Icons.bolt,
                              size: 20, color: cs.primary),
                        ))
                : Container(
                    width: 44,
                    color: cs.primaryContainer,
                    child: Icon(Icons.bolt, size: 20, color: cs.primary),
                  ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  if (city.isNotEmpty)
                    Text(city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                  if (price != null) ...[
                    const SizedBox(height: 2),
                    Text('EGP $price',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Governorate quick-filter chips ────────────────────────────────────────────
// Derives the top-5 most frequent governorates from loaded generators and shows
// them as one-tap filter chips so users can narrow by location instantly.
class _GovernorateChips extends StatelessWidget {
  const _GovernorateChips({required this.ref, required this.filter});
  final WidgetRef ref;
  final GeneratorFilter filter;

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(generatorsProvider);
    final all = allAsync.valueOrNull ?? [];
    if (all.isEmpty) return const SizedBox.shrink();

    // Count occurrences per governorate
    final counts = <String, int>{};
    for (final g in all) {
      final gov = g['governorate']?.toString();
      if (gov != null && gov.isNotEmpty) {
        counts[gov] = (counts[gov] ?? 0) + 1;
      }
    }
    // Take top 5 by count
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).map((e) => e.key).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: top.map((gov) {
          final selected = filter.governorate == gov;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(Icons.location_on_outlined,
                  size: 12,
                  color: selected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              label: Text(gov),
              selected: selected,
              onSelected: (on) => ref
                  .read(filterProvider.notifier)
                  .state = filter.withGovernorate(on ? gov : null),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Near Me Section ───────────────────────────────────────────────────────────
class _NearMeSection extends StatelessWidget {
  const _NearMeSection({required this.ref, required this.cs});
  final WidgetRef ref;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nearMeProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result.governorate == null || result.generators.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Near you · ${result.governorate}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: result.generators.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final g = result.generators[i];
                  final photos =
                      (g['photos'] as List?)?.cast<String>() ?? [];
                  final kva = g['capacity_kva'];
                  final price = g['price_per_day'];
                  return GestureDetector(
                    onTap: () =>
                        context.push(AppRoutes.generatorDetail(g['id'].toString())),
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14)),
                            child: photos.isNotEmpty
                                ? Image.network(photos.first,
                                    height: 80,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _NearMePlaceholder(cs: cs))
                                : _NearMePlaceholder(cs: cs),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g['title']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${kva} KVA · EGP $price/d',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _NearMePlaceholder extends StatelessWidget {
  const _NearMePlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        width: double.infinity,
        color: cs.primaryContainer,
        child: Icon(Icons.bolt, color: cs.primary, size: 28),
      );
}
