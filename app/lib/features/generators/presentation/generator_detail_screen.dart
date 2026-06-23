import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase.dart';
import '../providers/detail_providers.dart';
import 'widgets/detail_sections.dart';
import 'widgets/photo_carousel.dart';
import '../../../core/routing/app_routes.dart';

class GeneratorDetailScreen extends ConsumerWidget {
  const GeneratorDetailScreen(
      {super.key, required this.id, this.scrollController});
  final String id;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(generatorDetailProvider(id));
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
                  onPressed: () => ref.invalidate(generatorDetailProvider(id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (gen) =>
            _Body(gen: gen, cs: cs, scrollController: scrollController),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(
      {required this.gen, required this.cs, this.scrollController});
  final Map<String, dynamic> gen;
  final ColorScheme cs;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = gen['companies'] as Map<String, dynamic>?;
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final generatorId = gen['id'].toString();
    final companyId = gen['company_id']?.toString() ?? '';
    final reviewsAsync = ref.watch(generatorReviewsProvider(generatorId));
    final responseTimeAsync = ref.watch(avgResponseTimeProvider(companyId));
    final bookedAsync = ref.watch(bookedDatesProvider(generatorId));
    final similarAsync = ref.watch(similarGeneratorsProvider(gen));

    return CustomScrollView(
      controller: scrollController,
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
                : PhotoCarousel(photos: photos),
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
                  // Avg response time badge
                  responseTimeAsync.maybeWhen(
                    data: (mins) {
                      if (mins == null || mins <= 0) {
                        return const SizedBox.shrink();
                      }
                      final label = mins < 60
                          ? '~$mins min'
                          : mins < 1440
                              ? '~${(mins / 60).round()} hr'
                              : '~${(mins / 1440).round()} day';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.timer_outlined,
                                size: 11, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Responds in $label',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700),
                            ),
                          ]),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
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
                // Contact buttons
                Builder(builder: (_) {
                  final phone = company?['contact_phone']?.toString();
                  if (phone == null || phone.isEmpty) {
                    return const SizedBox(height: 24);
                  }
                  final cleaned = phone.replaceAll(RegExp(r'\D'), '');
                  final egPhone = cleaned.startsWith('20')
                      ? cleaned
                      : '20${cleaned.startsWith('0') ? cleaned.substring(1) : cleaned}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => launchUrl(
                                Uri.parse('tel:$phone'),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.call_outlined, size: 16),
                            label: const Text('Call owner'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () => launchUrl(
                                Uri.parse(
                                    'https://wa.me/$egPhone'),
                                mode: LaunchMode.externalApplication),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_outlined,
                                    size: 16,
                                    color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Text('WhatsApp',
                                    style: TextStyle(
                                        color:
                                            Colors.green.shade700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Pricing card
                PricingCard(gen: gen, cs: cs),
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
                      : BookedDatesSection(bookings: bookings, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),

                // Reviews
                reviewsAsync.maybeWhen(
                  data: (reviews) => reviews.isEmpty
                      ? const SizedBox.shrink()
                      : ReviewsSection(reviews: reviews, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                ),

                // Similar generators
                similarAsync.maybeWhen(
                  data: (similar) => similar.isEmpty
                      ? const SizedBox.shrink()
                      : SimilarGeneratorsSection(
                          generators: similar, cs: cs),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

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

// ── Similar generators ────────────────────────────────────────────────────────

// ── Rent Now FAB — scroll-aware sticky wrapper ────────────────────────────────
class GeneratorDetailWrapper extends ConsumerStatefulWidget {
  const GeneratorDetailWrapper({super.key, required this.id});
  final String id;

  @override
  ConsumerState<GeneratorDetailWrapper> createState() =>
      _GeneratorDetailWrapperState();
}

class _GeneratorDetailWrapperState
    extends ConsumerState<GeneratorDetailWrapper> {
  final _scrollController = ScrollController();
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final visible = offset < 100 || _scrollController.position.userScrollDirection.name == 'forward';
      if (visible != _fabVisible) setState(() => _fabVisible = visible);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loggedIn = supabase.auth.currentSession != null;
    final isFavAsync = ref.watch(isFavProvider(widget.id));
    final isFav = isFavAsync.valueOrNull ?? false;
    final id = widget.id;

    return Scaffold(
      body: GeneratorDetailScreen(id: id, scrollController: _scrollController),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        offset: _fabVisible ? Offset.zero : const Offset(0, 1.5),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _fabVisible ? 1.0 : 0.0,
          child: Row(
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
              // Favorite button
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FloatingActionButton.small(
                  heroTag: 'fav',
                  backgroundColor: isFav
                      ? Colors.red.shade50
                      : cs.surfaceContainerHighest,
                  foregroundColor:
                      isFav ? Colors.red.shade400 : cs.onSurfaceVariant,
                  tooltip: isFav ? 'Remove from saved' : 'Save',
                  onPressed: () => _toggleFav(ref, id, isFav),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(isFav),
                    tween: Tween(begin: 1.4, end: 1.0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border,
                        key: ValueKey(isFav),
                        size: 18,
                      ),
                    ),
                  ),
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
                  HapticFeedback.mediumImpact();
                  if (!loggedIn) {
                    context.push(AppRoutes.login);
                    return;
                  }
                  context.push(AppRoutes.generatorRequest(id));
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Rent Now'),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _shareGenerator(WidgetRef ref, String id) async {
    final cached = ref.read(generatorDetailProvider(id)).valueOrNull;
    final title = cached?['title']?.toString() ?? 'a generator';
    final kva = cached?['capacity_kva'];
    final price = cached?['price_per_day'];
    final city = cached?['city']?.toString();
    final gov = cached?['governorate']?.toString();
    final location = [city, gov]
        .where((v) => v != null && v.isNotEmpty)
        .join(', ');
    final parts = <String>[
      title,
      if (kva != null) '$kva KVA',
      if (price != null) 'EGP $price/day',
      if (location.isNotEmpty) location,
    ];
    final text =
        '${parts.join(' · ')}\n\nFind it on AnDaLoeS for Generators 🔌';
    await Share.share(text, subject: title);
  }

  Future<void> _toggleFav(WidgetRef ref, String id, bool isFav) async {
    HapticFeedback.lightImpact();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (isFav) {
      await supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', uid)
          .eq('generator_id', id);
    } else {
      await supabase
          .from('user_favorites')
          .upsert({'user_id': uid, 'generator_id': id});
    }
    ref.invalidate(isFavProvider(widget.id));
  }
}
