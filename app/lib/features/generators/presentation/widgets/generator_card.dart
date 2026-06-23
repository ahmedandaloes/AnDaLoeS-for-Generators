import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase.dart';
import '../../providers/generators_providers.dart'
    show favoritesProvider, recentlyViewedProvider;
import 'fuel_chip.dart';
import '../../../../core/routing/app_routes.dart';

class GeneratorCard extends ConsumerStatefulWidget {
  const GeneratorCard({super.key, required this.generator});
  final Map<String, dynamic> generator;

  @override
  ConsumerState<GeneratorCard> createState() => _GeneratorCardState();
}

class _GeneratorCardState extends ConsumerState<GeneratorCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final generator = widget.generator;
    final id = generator['id']?.toString() ?? '';
    final isFav = ref.watch(favoritesProvider).contains(id);
    final location = [generator['city'], generator['governorate']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');
    final companyName = (generator['companies'] as Map<String, dynamic>?)?['name']?.toString();

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          // Track recently viewed
          final current =
              ref.read(recentlyViewedProvider);
          final id = generator['id']?.toString() ?? '';
          final updated = [
            generator,
            ...current.where((g) => g['id']?.toString() != id),
          ].take(5).toList();
          ref.read(recentlyViewedProvider.notifier).state = updated;
          context.push(AppRoutes.generatorDetail(generator['id'].toString()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CardPhoto(
                photos: (generator['photos'] as List?)?.cast<String>() ?? [],
                cs: cs,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
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
                      if (_isTopRated(generator))
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 10, color: Colors.amber.shade700),
                              const SizedBox(width: 2),
                              Text('Top',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade800,
                                  )),
                            ],
                          ),
                        ),
                      if (_isNew(generator))
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: Colors.green.shade300),
                          ),
                          child: Text('New',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade700,
                              )),
                        ),
                    ]),
                    if (companyName != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.storefront_outlined,
                            size: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            companyName,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      GeneratorAttributeChip(
                        icon: Icons.electric_bolt,
                        label: '${generator['capacity_kva']} KVA',
                        cs: cs,
                      ),
                      const SizedBox(width: 6),
                      FuelChip(
                          fuel: generator['fuel_type']?.toString() ?? 'diesel'),
                      if (location.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        GeneratorAttributeChip(
                          icon: Icons.location_on_outlined,
                          label: location,
                          cs: cs,
                        ),
                      ],
                    ]),
                    if (_hasRating(generator)) ...[
                      const SizedBox(height: 4),
                      Row(children: [
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
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _toggleFav(ref, id),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(isFav),
                        size: 20,
                        color: isFav
                            ? Colors.red.shade400
                            : cs.onSurfaceVariant,
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
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _toggleFav(WidgetRef ref, String id) {
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
            .upsert({'user_id': uid, 'generator_id': id})
            .then((_) {});
      }
    }
    ref.read(favoritesProvider.notifier).state = next;
  }

  static bool _isTopRated(Map<String, dynamic> g) =>
      (g['avg_score'] as num?)?.toDouble() != null &&
      (g['avg_score'] as num).toDouble() >= 4.5 &&
      (g['rating_count'] as num?)?.toInt() != null &&
      (g['rating_count'] as num).toInt() >= 3;

  static bool _isNew(Map<String, dynamic> g) {
    final raw = g['created_at']?.toString();
    if (raw == null) return false;
    try {
      final created = DateTime.parse(raw);
      return DateTime.now().difference(created).inHours < 48;
    } catch (_) {
      return false;
    }
  }

  static bool _hasRating(Map<String, dynamic> g) =>
      (g['rating_count'] as num?)?.toInt() != null &&
      (g['rating_count'] as num).toInt() > 0;
}

// ── Shared chip widgets ───────────────────────────────────────────────────────

class GeneratorAttributeChip extends StatelessWidget {
  const GeneratorAttributeChip(
      {super.key, required this.icon, required this.label, required this.cs});
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
          Text(label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Card photo thumbnail ──────────────────────────────────────────────────────

class CardPhoto extends StatelessWidget {
  const CardPhoto({super.key, required this.photos, required this.cs});
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
