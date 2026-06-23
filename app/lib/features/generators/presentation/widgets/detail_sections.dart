import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SimilarGeneratorsSection extends StatelessWidget {
  const SimilarGeneratorsSection(
      {super.key, required this.generators, required this.cs});
  final List<Map<String, dynamic>> generators;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Similar generators nearby',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: generators.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = generators[i];
              final photo = (g['photos'] as List?)?.isNotEmpty == true
                  ? g['photos'][0].toString()
                  : null;
              final score =
                  (g['avg_score'] as num?)?.toStringAsFixed(1) ?? '–';
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/generator/${g['id']}');
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: photo != null
                            ? Image.network(
                                photo,
                                height: 80,
                                width: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholder(cs),
                              )
                            : _placeholder(cs),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g['title']?.toString() ?? '–',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(
                                '${g['capacity_kva']} KVA',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.star_rounded,
                                  size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(score,
                                  style: const TextStyle(fontSize: 10)),
                            ]),
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
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      height: 80,
      width: 140,
      color: cs.primaryContainer.withValues(alpha: 0.3),
      child: Icon(Icons.bolt, size: 32, color: cs.primary),
    );
  }
}

class BookedDatesSection extends StatelessWidget {
  const BookedDatesSection(
      {super.key, required this.bookings, required this.cs});
  final List<Map<String, dynamic>> bookings;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Already booked',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: cs.error.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            children: bookings.map((b) {
              final status = b['status']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(
                    status == 'active'
                        ? Icons.circle
                        : Icons.calendar_today_outlined,
                    size: 12,
                    color: status == 'active' ? cs.error : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${b['start_date']}  →  ${b['end_date']}',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        fontWeight: status == 'active'
                            ? FontWeight.w600
                            : FontWeight.normal),
                  ),
                  if (status == 'active') ...[
                    const SizedBox(width: 6),
                    Text('(active)',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.error,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class ReviewsSection extends StatelessWidget {
  const ReviewsSection({super.key, required this.reviews, required this.cs});
  final List<Map<String, dynamic>> reviews;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final avg = reviews.fold<double>(
            0, (s, r) => s + ((r['score'] as num?)?.toDouble() ?? 0)) /
        reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(children: [
          Text(
            'Reviews',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
          const SizedBox(width: 2),
          Text(avg.toStringAsFixed(1),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('  (${reviews.length})',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 12),
        ...reviews.map((r) => _ReviewCard(review: r, cs: cs)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.cs});
  final Map<String, dynamic> review;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final score = (review['score'] as num?)?.toInt() ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final date = review['created_at'] != null
        ? DateTime.tryParse(review['created_at'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: i < score ? Colors.amber.shade600 : cs.outlineVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
            ]),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(comment,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class PricingCard extends StatelessWidget {
  const PricingCard({super.key, required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _PriceRow(
                label: 'Per day (8 hrs)',
                value: gen['price_per_day'],
                cs: cs,
                highlight: true),
            if (gen['price_per_week'] != null) ...[
              const SizedBox(height: 8),
              _PriceRow(
                  label: 'Per week', value: gen['price_per_week'], cs: cs),
            ],
            if (gen['price_per_month'] != null) ...[
              const SizedBox(height: 8),
              _PriceRow(
                  label: 'Per month',
                  value: gen['price_per_month'],
                  cs: cs),
            ],
            const SizedBox(height: 8),
            Text(
              '1 rental day = 8 operating hours. Best rate is applied automatically.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(
      {required this.label,
      required this.value,
      required this.cs,
      this.highlight = false});
  final String label;
  final dynamic value;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
              fontWeight:
                  highlight ? FontWeight.w600 : FontWeight.normal)),
      const Spacer(),
      Text(
        'EGP ${value ?? '-'}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: highlight ? cs.primary : cs.onSurface,
        ),
      ),
    ]);
  }
}
