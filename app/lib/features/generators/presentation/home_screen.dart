import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/providers/notifications_providers.dart'
    show unreadCountProvider;
import '../providers/generators_providers.dart'
    show
        favoritesProvider,
        generatorsProvider,
        remoteFavoritesProvider,
        showFavoritesOnlyProvider,
        recentSearchesProvider,
        currentProfileProvider;
import '../../owner_dashboard/providers/owner_providers.dart'
    show ownerPendingCountProvider;
import 'widgets/fuel_chip.dart' show fuelLabel;
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
          if (filter.useCases.isNotEmpty) {
            final genUseCases =
                (g['use_cases'] as List?)?.cast<String>() ?? const [];
            if (!filter.useCases.any(genUseCases.contains)) return false;
          }
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

          // ── Personalized greeting card (role-aware) ──────────────────
          if (loggedIn)
            SliverToBoxAdapter(
              child: Consumer(builder: (context, watchRef, _) {
                final profile = watchRef.watch(currentProfileProvider);
                return profile.maybeWhen(
                  data: (p) {
                    if (p == null) return const SizedBox.shrink();
                    final role = p['role']?.toString() ?? 'customer';
                    final name = (p['full_name']?.toString() ?? '').split(' ').firstOrNull ?? '';
                    final greeting = _timeGreeting();
                    final (IconData icon, String label, String sub, Color bg,
                            Color fg) =
                        switch (role) {
                      'admin' => (
                          Icons.shield_outlined,
                          '$greeting, $name',
                          'Admin mode — full platform access.',
                          cs.surfaceContainerHigh,
                          cs.onSurface,
                        ),
                      'owner' => (
                          Icons.storefront_outlined,
                          '$greeting, $name',
                          '',
                          cs.secondaryContainer,
                          cs.onSecondaryContainer,
                        ),
                      _ => (
                          Icons.bolt,
                          '$greeting, ${name.isEmpty ? "there" : name}',
                          'Find your perfect generator rental today.',
                          cs.primaryContainer,
                          cs.onPrimaryContainer,
                        ),
                    };
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: role == 'admin'
                              ? Border.all(color: cs.outlineVariant)
                              : null,
                        ),
                        child: Row(children: [
                          Icon(icon,
                              size: 24,
                              color: role == 'admin' ? cs.primary : fg),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  )),
                              const SizedBox(height: 2),
                              if (role == 'owner')
                                Consumer(builder: (_, wr, __) {
                                  final pending = wr.watch(ownerPendingCountProvider).valueOrNull ?? 0;
                                  final txt = pending == 0
                                      ? 'No pending requests.'
                                      : '$pending pending request${pending == 1 ? '' : 's'} awaiting you.';
                                  return Text(txt,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: fg.withValues(alpha: 0.8)));
                                })
                              else
                                Text(sub,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: fg.withValues(alpha: 0.75),
                                    )),
                            ],
                          )),
                          if (role == 'owner')
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () => context.push(AppRoutes.ownerDashboard),
                              child: Text('Dashboard',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: fg)),
                            ),
                          if (role == 'admin')
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () => context.push(AppRoutes.admin),
                              child: Text('Admin Panel',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary)),
                            ),
                        ]),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              }),
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
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  for (final gov in const [
                    'Cairo', 'Giza', 'Alexandria', 'Minya',
                    'Assiut', 'Sharqia', 'Aswan', 'Luxor',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.location_on_outlined, size: 14),
                        label: Text(gov, style: const TextStyle(fontSize: 12.5)),
                        selected: filter.governorate == gov,
                        onSelected: (on) => ref
                            .read(filterProvider.notifier)
                            .state = filter.withGovernorate(on ? gov : null),
                      ),
                    ),
                ],
              ),
            ),
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
                  data: (items) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0, 0.4),
                                end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '${items.length} found',
                      key: ValueKey(items.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant),
                    ),
                  ),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _GridGeneratorCard(generator: items[i]),
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 90)),
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

// ── Grid card (Premium B2B / Trust: photo, title, verified + rating, price) ──
class _GridGeneratorCard extends StatelessWidget {
  const _GridGeneratorCard({required this.generator});
  final Map<String, dynamic> generator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photos = (generator['photos'] as List?)?.cast<String>() ?? const [];
    final photo = photos.isNotEmpty ? photos.first : null;
    final title = generator['title']?.toString() ?? 'Generator';
    final kva = generator['capacity_kva'];
    final city = generator['city']?.toString() ??
        generator['governorate']?.toString() ??
        '';
    final price = generator['price_per_day'];
    final score = (generator['avg_score'] as num?)?.toDouble() ?? 0;
    final ratingCount = (generator['rating_count'] as num?)?.toInt() ?? 0;
    final company =
        (generator['companies'] as Map?)?['name']?.toString() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context
            .push(AppRoutes.generatorDetail(generator['id'].toString())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: photo != null
                  ? Image.network(photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(cs))
                  : _placeholder(cs),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (company.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(children: [
                          Icon(Icons.storefront_outlined,
                              size: 11, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: cs.onSurfaceVariant)),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 3),
                    Text(
                        '${kva ?? '-'} KVA${city.isNotEmpty ? ' · $city' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.verified, size: 13, color: cs.secondary),
                      const SizedBox(width: 3),
                      Text('Verified',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: cs.secondary)),
                      if (ratingCount > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(score.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    const Spacer(),
                    Text('EGP ${price ?? '-'}/day',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: cs.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        child: Icon(Icons.bolt, color: cs.primary, size: 36),
      );
}

// ── Hero banner ───────────────────────────────────────────────────────────────

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

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
