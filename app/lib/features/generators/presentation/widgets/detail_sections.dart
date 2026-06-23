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
                  context.push('/generators/${g['id']}');
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
                            if (g['price_per_day'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'EGP ${g['price_per_day']}/day',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.secondary,
                                ),
                              ),
                            ],
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

  // Build a set of booked DateTime days from booking ranges
  Set<DateTime> _bookedDays() {
    final days = <DateTime>{};
    for (final b in bookings) {
      try {
        final start = DateTime.parse(b['start_date'].toString());
        final end = DateTime.parse(b['end_date'].toString());
        for (var d = start;
            !d.isAfter(end);
            d = d.add(const Duration(days: 1))) {
          days.add(DateTime(d.year, d.month, d.day));
        }
      } catch (_) {}
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final bookedDays = _bookedDays();
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'Availability',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          _LegendDot(color: cs.error, label: 'Booked', cs: cs),
          const SizedBox(width: 12),
          _LegendDot(color: Colors.green, label: 'Available', cs: cs),
        ]),
        const SizedBox(height: 10),
        // Show current month and next month
        _MiniCalendarMonth(
          year: now.year,
          month: now.month,
          bookedDays: bookedDays,
          cs: cs,
        ),
        const SizedBox(height: 12),
        _MiniCalendarMonth(
          year: now.month == 12 ? now.year + 1 : now.year,
          month: now.month == 12 ? 1 : now.month + 1,
          bookedDays: bookedDays,
          cs: cs,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(
      {required this.color, required this.label, required this.cs});
  final Color color;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
    ]);
  }
}

class _MiniCalendarMonth extends StatelessWidget {
  const _MiniCalendarMonth({
    required this.year,
    required this.month,
    required this.bookedDays,
    required this.cs,
  });
  final int year;
  final int month;
  final Set<DateTime> bookedDays;
  final ColorScheme cs;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    // weekday: 1=Mon … 7=Sun → offset 0-6
    final startOffset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    // Leading blanks
    for (var i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final isBooked = bookedDays.contains(date);
      final isPast = date.isBefore(todayNorm);
      final isToday = date == todayNorm;

      Color? bg;
      Color textColor;
      FontWeight fw = FontWeight.normal;

      if (isBooked) {
        bg = cs.error;
        textColor = cs.onError;
        fw = FontWeight.w600;
      } else if (isToday) {
        bg = cs.primaryContainer;
        textColor = cs.primary;
        fw = FontWeight.w700;
      } else if (isPast) {
        bg = null;
        textColor = cs.onSurface.withValues(alpha: 0.3);
      } else {
        // Available future day — subtle green tint
        bg = Colors.green.withValues(alpha: 0.12);
        textColor = Colors.green.shade800;
      }

      cells.add(
        Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$d',
              style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: fw,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthNames[month]} $year',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          // Day-of-week header
          Row(
            children: _weekdays
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: cells,
          ),
        ],
      ),
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
