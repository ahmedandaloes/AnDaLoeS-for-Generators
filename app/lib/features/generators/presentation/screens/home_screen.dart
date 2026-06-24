import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart'
    show unreadCountProvider;
import '../providers/generators_providers.dart'
    show
        favoritesProvider,
        generatorsProvider,
        remoteFavoritesProvider,
        showFavoritesOnlyProvider,
        recentSearchesProvider,
        currentProfileProvider;
import '../providers/saved_search_provider.dart';
import '../../../owner_dashboard/presentation/providers/owner_providers.dart'
    show ownerPendingCountProvider;
import '../widgets/fuel_chip.dart' show fuelLabel;
import '../widgets/generator_filter.dart';
import '../widgets/home_widgets.dart';
import '../widgets/search_autocomplete.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/db_error.dart';

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
    // Persist filters/sort whenever they change (best-effort).
    ref.listen<GeneratorFilter>(
        filterProvider, (_, next) => saveFilter(next));
    final allGenerators = ref.watch(generatorsProvider);
    final filter = ref.watch(filterProvider);
    final recentSearches = ref.watch(recentSearchesProvider);
    final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
    final favorites = ref.watch(favoritesProvider);
    final loggedIn = ref.read(authRepositoryProvider).currentUserId != null;
    final cs = Theme.of(context).colorScheme;

    ref.listen<AsyncValue<Set<String>>>(remoteFavoritesProvider, (_, next) {
      next.whenData(_seedFavoritesIfNeeded);
    });

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
          ..sort((a, b) {
            double n(Map<String, dynamic> m, String k) =>
                (m[k] as num?)?.toDouble() ?? 0;
            return switch (filter.sort) {
              GeneratorSortBy.priceLow =>
                n(a, 'price_per_day').compareTo(n(b, 'price_per_day')),
              GeneratorSortBy.priceHigh =>
                n(b, 'price_per_day').compareTo(n(a, 'price_per_day')),
              GeneratorSortBy.ratingTop =>
                n(b, 'avg_score').compareTo(n(a, 'avg_score')),
              GeneratorSortBy.capacityLow =>
                n(a, 'capacity_kva').compareTo(n(b, 'capacity_kva')),
              GeneratorSortBy.newest => 0,
            };
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
                tooltip: l.mapView,
                onPressed: () => context.push(AppRoutes.map),
              ),
              if (loggedIn) ...[
                IconButton(
                  icon: const Icon(Icons.bookmark_border_outlined),
                  tooltip: l.savedSearches,
                  onPressed: () => _showSavedSearchesSheet(context, ref, filter),
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: l.myRentals,
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
                        tooltip: l.notifications,
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
                  tooltip: l.navProfile,
                  onPressed: () => context.push(AppRoutes.profile),
                ),
              ] else
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
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
              background: HomeBanner(cs: cs, l: l),
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
                    final greeting = homeTimeGreeting();
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
                              child: Text(l.dashboard,
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
                              child: Text(l.adminPanel,
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
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ActionChip(
                        avatar: Icon(Icons.bookmark_add_outlined,
                            size: 14, color: cs.primary),
                        label: Text(l.saveSearch,
                            style: TextStyle(fontSize: 12, color: cs.primary)),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.35)),
                        onPressed: () =>
                            _showSaveSearchDialog(context, ref, filter),
                      ),
                    ),
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
                      padding: const EdgeInsetsDirectional.only(end: 8),
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
                      margin: const EdgeInsetsDirectional.only(end: 6),
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
                            ? l.sort
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
                (_, __) => const HomeSkeletonCard(),
                childCount: 5,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: HomeErrorState(
                  message: friendlyDbError(e),
                  onRetry: () => ref.invalidate(generatorsProvider)),
            ),
            data: (items) {
              if (items.isEmpty) {
                // Use SliverToBoxAdapter (not SliverFillRemaining) so the
                // featured carousel above remains accessible via scroll.
                return SliverToBoxAdapter(
                  child: hasFilter
                      ? HomeNoResultsState(
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
                      : HomeEmptyState(l: l),
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
                    (context, i) => HomeGeneratorCard(generator: items[i]),
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
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: onDelete,
        ),
      );

  void _showSortSheet(BuildContext context, GeneratorFilter filter) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
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
            Text(l.sortBy,
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

  Future<void> _showSaveSearchDialog(
      BuildContext context, WidgetRef widgetRef, GeneratorFilter filter) async {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.saveSearch),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.searchName,
            hintText: l.searchNameHint,
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.saveSearch)),
        ],
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty && context.mounted) {
      try {
        await saveSearch(ref: widgetRef, name: nameCtrl.text.trim(), filter: filter);
        widgetRef.invalidate(savedSearchesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.searchSaved)),
          );
        }
      } catch (_) {}
    }
  }

  void _showSavedSearchesSheet(
      BuildContext context, WidgetRef widgetRef, GeneratorFilter currentFilter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SavedSearchesSheet(
        currentFilter: currentFilter,
        onApply: (f) {
          widgetRef.read(filterProvider.notifier).state = f;
          Navigator.pop(sheetCtx);
        },
        onDelete: (id) async {
          await deleteSavedSearch(widgetRef, id);
          widgetRef.invalidate(savedSearchesProvider);
        },
        onSaveCurrent: currentFilter.hasActiveFilters
            ? () {
                Navigator.pop(sheetCtx);
                _showSaveSearchDialog(context, widgetRef, currentFilter);
              }
            : null,
      ),
    );
  }
}
