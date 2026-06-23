import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/supabase.dart';

final _generatorDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await supabase
      .from('generators')
      .select('*, companies(name, city, verification_status)')
      .eq('id', id)
      .single();
  return data;
});

// Upcoming accepted/active bookings for this generator (next 90 days).
final _bookedDatesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final data = await supabase
      .from('rental_requests')
      .select('start_date, end_date, status')
      .eq('generator_id', generatorId)
      .inFilter('status', ['accepted', 'active'])
      .gte('end_date', today)
      .order('start_date');
  return (data as List).cast<Map<String, dynamic>>();
});

final _generatorReviewsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  // Step 1: get rental_request IDs for this generator
  final rrData = await supabase
      .from('rental_requests')
      .select('id')
      .eq('generator_id', generatorId);
  final ids =
      (rrData as List).map((r) => r['id'].toString()).toList();
  if (ids.isEmpty) return [];

  // Step 2: fetch ratings with comments for those requests
  final data = await supabase
      .from('ratings')
      .select('score, comment, created_at')
      .filter('rental_request_id', 'in', '(${ids.join(',')})')
      .not('comment', 'is', null)
      .order('created_at', ascending: false)
      .limit(10);
  return (data as List).cast<Map<String, dynamic>>();
});

class GeneratorDetailScreen extends ConsumerWidget {
  const GeneratorDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_generatorDetailProvider(id));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 16),
                Text('$e'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(_generatorDetailProvider(id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (gen) => _Body(gen: gen, cs: cs),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.gen, required this.cs});
  final Map<String, dynamic> gen;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = gen['companies'] as Map<String, dynamic>?;
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final generatorId = gen['id'].toString();
    final reviewsAsync = ref.watch(_generatorReviewsProvider(generatorId));
    final bookedAsync = ref.watch(_bookedDatesProvider(generatorId));

    return CustomScrollView(
      slivers: [
        // ── Photo header ───────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          flexibleSpace: FlexibleSpaceBar(
            background: photos.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primaryContainer.withValues(alpha: 0.8),
                          cs.secondaryContainer.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bolt, size: 64, color: cs.primary),
                      ),
                    ),
                  )
                : _PhotoCarousel(photos: photos),
          ),
        ),

        // ── Content ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + capacity badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        gen['title']?.toString() ?? 'Generator',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${gen['capacity_kva']} KVA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Company + location
                if (company != null) ...[
                  GestureDetector(
                    onTap: () => context
                        .push('/company/${gen['company_id']}'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          company['name']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: cs.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      [
                        gen['city'],
                        gen['governorate'],
                      ]
                          .where(
                              (v) => v != null && v.toString().isNotEmpty)
                          .join(', '),
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Pricing card
                _PricingCard(gen: gen, cs: cs),
                const SizedBox(height: 20),

                // Description
                if (gen['description'] != null &&
                    gen['description'].toString().isNotEmpty) ...[
                  Text(
                    'About this generator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gen['description'].toString(),
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                ],

                // Booked dates
                bookedAsync.maybeWhen(
                  data: (bookings) => bookings.isEmpty
                      ? const SizedBox.shrink()
                      : _BookedDatesSection(bookings: bookings, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Reviews
                reviewsAsync.maybeWhen(
                  data: (reviews) => reviews.isEmpty
                      ? const SizedBox.shrink()
                      : _ReviewsSection(reviews: reviews, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                ),

                // Info note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Owner delivers, sets up, and operates the generator. Payment in cash on delivery.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reviews section ───────────────────────────────────────────────────────────
// ── Booked dates section ───────────────────────────────────────────────────────
class _BookedDatesSection extends StatelessWidget {
  const _BookedDatesSection(
      {required this.bookings, required this.cs});
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
            border: Border.all(
                color: cs.error.withValues(alpha: 0.2), width: 1),
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
                    color: status == 'active'
                        ? cs.error
                        : cs.onSurfaceVariant,
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

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews, required this.cs});
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
        Row(
          children: [
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
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '  (${reviews.length})',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
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
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < score ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: i < score
                          ? Colors.amber.shade600
                          : cs.outlineVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
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

// ── Pricing card ─────────────────────────────────────────────────────────────
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.gen, required this.cs});
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
              highlight: true,
            ),
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
    return Row(
      children: [
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
      ],
    );
  }
}

// ── Photo carousel ────────────────────────────────────────────────────────────
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});
  final List<String> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => Image.network(
            widget.photos[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.bolt, size: 64),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Rent Now FAB — added by the scaffold wrapper in the router ────────────────
class GeneratorDetailWrapper extends ConsumerWidget {
  const GeneratorDetailWrapper({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final loggedIn = supabase.auth.currentSession != null;

    return Scaffold(
      body: GeneratorDetailScreen(id: id),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Share button
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FloatingActionButton.small(
              heroTag: 'share',
              backgroundColor: cs.surfaceContainerHighest,
              foregroundColor: cs.onSurfaceVariant,
              tooltip: 'Share',
              onPressed: () => _shareGenerator(ref, id),
              child: const Icon(Icons.share_outlined, size: 18),
            ),
          ),
          // Report button
          if (loggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FloatingActionButton.small(
                heroTag: 'report',
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
                tooltip: 'Report',
                onPressed: () => context.push(
                    '/report?type=generator&id=$id&name=Generator'),
                child: const Icon(Icons.flag_outlined, size: 18),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'rent',
            onPressed: () {
              if (!loggedIn) {
                context.push('/login');
                return;
              }
              context.push('/generators/$id/request');
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Rent Now'),
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
        ],
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _shareGenerator(WidgetRef ref, String id) async {
    final cached = ref.read(_generatorDetailProvider(id)).valueOrNull;
    final title = cached?['title']?.toString() ?? 'a generator';
    final kva = cached?['capacity_kva'];
    final text = kva != null
        ? 'Check out $title ($kva KVA) on AnDaLoeS for Generators!'
        : 'Check out $title on AnDaLoeS for Generators!';
    await Share.share(text, subject: title);
  }
}
