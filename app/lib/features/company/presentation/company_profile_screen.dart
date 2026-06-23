import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../core/routing/app_routes.dart';

final _companyProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('companies')
      .select('id, name, city, governorate, phone, verification_status')
      .eq('id', companyId)
      .maybeSingle();
  return data;
});

final _companyGeneratorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, photos, avg_score, rating_count')
      .eq('company_id', companyId)
      .eq('status', 'available')
      .order('avg_score', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key, required this.companyId});
  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(_companyProfileProvider(companyId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (company) {
          if (company == null) {
            return const Center(child: Text('Company not found'));
          }
          return _CompanyBody(
              company: company, companyId: companyId, cs: cs, ref: ref);
        },
      ),
    );
  }
}

class _CompanyBody extends StatelessWidget {
  const _CompanyBody({
    required this.company,
    required this.companyId,
    required this.cs,
    required this.ref,
  });
  final Map<String, dynamic> company;
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final name = company['name']?.toString() ?? 'Company';
    final city = company['city']?.toString() ?? '';
    final governorate = company['governorate']?.toString() ?? '';
    final location = [city, governorate]
        .where((v) => v.isNotEmpty)
        .join(', ');
    final isVerified =
        company['verification_status']?.toString() == 'approved';
    final generatorsAsync =
        ref.watch(_companyGeneratorsProvider(companyId));

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          stretch: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primaryContainer.withValues(alpha: 0.9),
                    cs.secondaryContainer.withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.business,
                                size: 28, color: cs.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                if (location.isNotEmpty)
                                  Text(
                                    location,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Verification badge ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                if (isVerified) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 14, color: Colors.green),
                        SizedBox(width: 5),
                        Text(
                          'Verified business',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(
                          'Pending verification',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                generatorsAsync.maybeWhen(
                  data: (gens) {
                    if (gens.isEmpty) return const SizedBox.shrink();
                    final rated = gens
                        .where((g) =>
                            (g['rating_count'] as num?)?.toInt() != null &&
                            (g['rating_count'] as num).toInt() > 0)
                        .toList();
                    if (rated.isEmpty) return const SizedBox.shrink();
                    final avg = rated.fold<double>(
                            0,
                            (s, g) =>
                                s +
                                ((g['avg_score'] as num?)?.toDouble() ??
                                    0)) /
                        rated.length;
                    return Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 3),
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),

        // ── Stats chips ───────────────────────────────────────────────
        generatorsAsync.maybeWhen(
          data: (gens) {
            final totalRentals = gens.fold<int>(
                0,
                (s, g) =>
                    s + ((g['rating_count'] as num?)?.toInt() ?? 0));
            return SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _StatChip(
                      icon: Icons.bolt_rounded,
                      label: '${gens.length} generators',
                      cs: cs,
                    ),
                    if (totalRentals > 0)
                      _StatChip(
                        icon: Icons.receipt_long_rounded,
                        label: '$totalRentals completed rentals',
                        cs: cs,
                      ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // ── Generators section ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Available generators',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        generatorsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text('$e')),
          ),
          data: (gens) {
            if (gens.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_outlined,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No available generators',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    if (i.isOdd) return const SizedBox(height: 10);
                    final g = gens[i ~/ 2];
                    return _CompanyGeneratorTile(gen: g, cs: cs);
                  },
                  childCount: gens.length * 2 - 1,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CompanyGeneratorTile extends StatelessWidget {
  const _CompanyGeneratorTile({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final ratingCount = (gen['rating_count'] as num?)?.toInt() ?? 0;
    final avgScore = gen['avg_score'];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.generatorDetail(gen['id'].toString())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: firstPhoto != null
                    ? Image.network(
                        firstPhoto,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: cs.primaryContainer,
                          child:
                              Icon(Icons.bolt, color: cs.primary, size: 24),
                        ),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: cs.primaryContainer,
                        child:
                            Icon(Icons.bolt, color: cs.primary, size: 24),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gen['title']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${gen['capacity_kva']} KVA',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    if (ratingCount > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            '$avgScore ($ratingCount)',
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${gen['price_per_day']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    'EGP/day',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.cs,
  });
  final IconData icon;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
