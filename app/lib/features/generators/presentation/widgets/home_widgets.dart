import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../providers/saved_search_provider.dart';
import 'generator_filter.dart';

// ── Grid card (Premium B2B / Trust: photo, title, verified + rating, price) ──
class HomeGeneratorCard extends StatelessWidget {
  const HomeGeneratorCard({super.key, required this.generator});
  final Map<String, dynamic> generator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
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
    final companyMap = generator['companies'] as Map?;
    final company = companyMap?['name']?.toString() ?? '';
    final isVerified =
        companyMap?['verification_status']?.toString() == 'approved';

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
                      if (isVerified) ...[
                        Icon(Icons.verified, size: 13, color: cs.secondary),
                        const SizedBox(width: 3),
                        Text(l.verified,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: cs.secondary)),
                        if (ratingCount > 0) const SizedBox(width: 8),
                      ],
                      if (ratingCount > 0) ...[
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

String homeTimeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.cs, required this.l});
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

class HomeSkeletonCard extends StatefulWidget {
  const HomeSkeletonCard({super.key});

  @override
  State<HomeSkeletonCard> createState() => _HomeSkeletonCardState();
}

class _HomeSkeletonCardState extends State<HomeSkeletonCard>
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

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.l});
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
            Text(l.emptyGeneratorsTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(l.emptyGeneratorsSubtitle,
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

class HomeErrorState extends StatelessWidget {
  const HomeErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(l.errorGeneric,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            FilledButton.tonal(
                onPressed: onRetry, child: Text(l.tryAgain)),
          ],
        ),
      ),
    );
  }
}

// ── Saved searches bottom sheet ───────────────────────────────────────────────
class SavedSearchesSheet extends ConsumerWidget {
  const SavedSearchesSheet({
    super.key,
    required this.onApply,
    required this.onDelete,
    required this.currentFilter,
    this.onSaveCurrent,
  });
  final void Function(GeneratorFilter) onApply;
  final Future<void> Function(String id) onDelete;
  final GeneratorFilter currentFilter;
  final VoidCallback? onSaveCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final searches = ref.watch(savedSearchesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              Text(l.savedSearches,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (onSaveCurrent != null)
                TextButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(l.saveSearch,
                      style: const TextStyle(fontSize: 13)),
                  onPressed: onSaveCurrent,
                ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: searches.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l.noSavedSearches,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 14)),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final name = s['name'] as String? ?? '';
                    final filterJson =
                        (s['filter'] as Map?)?.cast<String, dynamic>() ??
                            const {};
                    final f = GeneratorFilter.fromJson(filterJson);
                    final parts = <String>[
                      if (f.governorate != null) f.governorate!,
                      if (f.maxKva != null) '≤${f.maxKva!.toInt()} KVA',
                      if (f.maxPrice != null)
                        '≤${f.maxPrice!.toInt()} EGP/day',
                      if (f.fuelType != null) f.fuelType!,
                    ];
                    return ListTile(
                      leading:
                          Icon(Icons.bookmark_outline, color: cs.primary),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: parts.isNotEmpty
                          ? Text(parts.join(' · '),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                              onPressed: () => onApply(f),
                              child: Text(l.apply)),
                          IconButton(
                            icon:
                                Icon(Icons.delete_outline, color: cs.error),
                            tooltip: l.delete,
                            onPressed: () => onDelete(s['id'] as String),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeNoResultsState extends StatelessWidget {
  const HomeNoResultsState({
    super.key,
    required this.onClear,
    this.filterSummary,
  });
  final VoidCallback onClear;
  final String? filterSummary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(l.noMatchTitle,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
            Text(l.noMatchSubtitle,
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(
                onPressed: onClear, child: Text(l.clearAllFilters)),
          ],
        ),
      ),
    );
  }
}
