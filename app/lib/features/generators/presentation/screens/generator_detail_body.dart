import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/constants/generator_use_cases.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../company/data/company_repository.dart';
import '../providers/detail_providers.dart';
import '../widgets/detail_sections.dart';
import '../widgets/photo_carousel.dart';
import 'generator_rental_calculator.dart';

class GeneratorDetailBody extends ConsumerWidget {
  const GeneratorDetailBody(
      {required this.gen, required this.cs, this.scrollController});
  final Map<String, dynamic> gen;
  final ColorScheme cs;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final company = gen['companies'] as Map<String, dynamic>?;
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final generatorId = gen['id'].toString();
    final companyId = gen['company_id']?.toString() ?? '';
    final reviewsAsync = ref.watch(generatorReviewsProvider(generatorId));
    final responseTimeAsync = ref.watch(avgResponseTimeProvider(companyId));
    final acceptanceRateAsync =
        ref.watch(ownerAcceptanceRateProvider(companyId));
    final reliabilityAsync =
        ref.watch(companyReliabilityProvider(companyId));
    final bookedAsync = ref.watch(bookedDatesProvider(generatorId));
    final similarAsync = ref.watch(similarGeneratorsProvider(gen));
    final isFav =
        ref.watch(isFavProvider(generatorId)).valueOrNull ?? false;
    final loggedIn = supabase.auth.currentUser?.isAnonymous == false;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // ── Photo header ───────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          stretch: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l.share,
              onPressed: () => _shareGenerator(ref, generatorId),
            ),
            IconButton(
              icon: const Icon(Icons.link_rounded),
              tooltip: l.copyLink,
              onPressed: () => _copyLink(context, generatorId),
            ),
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border,
                color: isFav ? Colors.red.shade400 : null,
              ),
              tooltip: isFav ? l.removeFromSaved : l.save,
              onPressed: () => _toggleFav(ref, generatorId, isFav),
            ),
            if (loggedIn)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'report') {
                    _showReportSheet(context, ref, generatorId, cs);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(children: [
                      Icon(Icons.flag_outlined,
                          size: 16, color: cs.error),
                      const SizedBox(width: 8),
                      Text(l.reportProblem),
                    ]),
                  ),
                ],
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.fadeTitle,
            ],
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
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      PhotoCarousel(photos: photos),
                      // Bottom gradient so title text remains readable
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Photo count badge
                      Positioned(
                        bottom: 10,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined,
                                  size: 11, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${photos.length}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        if (company['verification_status']?.toString() ==
                            'approved') ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              size: 14, color: cs.secondary),
                        ],
                        const SizedBox(width: 8),
                        ref.watch(companyAvgRatingProvider(companyId)).maybeWhen(
                          data: (r) => r.total == 0 ? const SizedBox.shrink() : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 13, color: Colors.amber.shade600),
                              const SizedBox(width: 2),
                              Text(r.avg.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                              const SizedBox(width: 2),
                              Text('(${r.total})',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ── Compact trust row ─────────────────────────────────
                  Builder(builder: (_) {
                    final chips = <Widget>[];

                    // Response time
                    final mins = responseTimeAsync.valueOrNull;
                    if (mins != null && mins > 0) {
                      final label = mins < 60
                          ? '~$mins min'
                          : mins < 1440
                              ? '~${(mins / 60).round()} hr'
                              : '~${(mins / 1440).round()} day';
                      chips.add(_trustChip(
                        Icons.timer_outlined,
                        'Responds in $label',
                        Colors.green.shade700,
                        cs,
                      ));
                    }

                    // Acceptance rate
                    final acceptance = acceptanceRateAsync.valueOrNull;
                    if (acceptance != null && acceptance > 0) {
                      final color = qualityColor(acceptance);
                      chips.add(_trustChip(
                        Icons.check_circle_outline,
                        l.acceptanceRatePct(acceptance.round()),
                        color,
                        cs,
                      ));
                    }

                    // On-time delivery
                    final rel = reliabilityAsync.valueOrNull;
                    if (rel != null &&
                        rel.completed >= 1 &&
                        rel.onTimeRate > 0) {
                      final pct = (rel.onTimeRate * 100).round();
                      final color = qualityColor(pct);
                      chips.add(_trustChip(
                        Icons.local_shipping_outlined,
                        l.onTimeStat(pct, rel.completed),
                        color,
                        cs,
                      ));
                    }

                    if (chips.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: chips,
                      ),
                    );
                  }),
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
                // Use-case tags (what this generator is best for)
                Builder(builder: (_) {
                  final useCases =
                      (gen['use_cases'] as List?)?.cast<String>() ?? const [];
                  if (useCases.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: useCases
                          .map((uc) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(useCaseLabel(uc),
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: cs.primary)),
                              ))
                          .toList(),
                    ),
                  );
                }),
                // Hire type / fuel policy / accessories
                Builder(builder: (_) {
                  final l = AppLocalizations.of(context)!;
                  final hireType = gen['hire_type']?.toString();
                  final fuelPolicy = gen['fuel_policy']?.toString();
                  final accessories =
                      (gen['accessories'] as List?)?.cast<String>() ??
                          const [];
                  final chips = <Widget>[];
                  if (hireType == 'operated') {
                    chips.add(_detailChip(
                        Icons.person_outline,
                        l.hireTypeOperated,
                        cs.secondary,
                        cs));
                  } else if (hireType == 'dry_hire') {
                    chips.add(_detailChip(
                        Icons.directions_car_outlined,
                        l.hireTypeDryHire,
                        cs.onSurfaceVariant,
                        cs));
                  }
                  if (fuelPolicy == 'included') {
                    chips.add(_detailChip(
                        Icons.local_gas_station_outlined,
                        l.fuelPolicyIncluded,
                        Colors.green.shade700,
                        cs));
                  }
                  final accLabels = {
                    'cables': l.accessoryCables,
                    'extension_board': l.accessoryExtensionBoard,
                    'fuel_tank': l.accessoryFuelTank,
                    'transfer_switch': l.accessoryTransferSwitch,
                  };
                  for (final acc in accessories) {
                    final label = accLabels[acc];
                    if (label != null) {
                      chips.add(_detailChip(
                          Icons.extension_outlined, label, cs.tertiary, cs));
                    }
                  }
                  if (chips.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child:
                        Wrap(spacing: 8, runSpacing: 6, children: chips),
                  );
                }),
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
                            label: Text(l.callOwner),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () {
                              final title =
                                  gen['title']?.toString() ?? 'your generator';
                              final kva = gen['capacity_kva'];
                              final msg = Uri.encodeComponent(
                                  'Hi, I\'m interested in renting your "$title"'
                                  '${kva != null ? ' ($kva KVA)' : ''}'
                                  ' listed on AnDaLoeS. Is it available?');
                              launchUrl(
                                  Uri.parse(
                                      'https://wa.me/$egPhone?text=$msg'),
                                  mode: LaunchMode.externalApplication);
                            },
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

                // Rental price calculator
                if (gen['price_per_day'] != null)
                  GeneratorRentalCalculator(
                    pricePerDay:
                        (gen['price_per_day'] as num).toDouble(),
                    cs: cs,
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

// ── Shared helpers (used by _Body actions + wrapper) ─────────────────────────

Future<void> _shareGenerator(WidgetRef ref, String id) async {
  final cached = ref.read(generatorDetailProvider(id)).valueOrNull;
  final title = cached?['title']?.toString() ?? 'a generator';
  final kva = cached?['capacity_kva'];
  final price = cached?['price_per_day'];
  final city = cached?['city']?.toString();
  final gov = cached?['governorate']?.toString();
  final companyName = (cached?['companies'] as Map?)?['name']?.toString();
  final avgScore = (cached?['avg_score'] as num?)?.toDouble();
  final ratingCount = (cached?['rating_count'] as num?)?.toInt() ?? 0;
  final photos = (cached?['photos'] as List?)?.cast<String>() ?? [];
  final photoUrl = photos.isNotEmpty ? photos.first : null;
  final location =
      [city, gov].where((v) => v != null && v.isNotEmpty).join(', ');
  final ratingStr = (avgScore != null && ratingCount > 0)
      ? '⭐ ${avgScore.toStringAsFixed(1)} ($ratingCount reviews)'
      : null;
  final listingUrl = 'https://andaloes.app/generators/$id';
  final lines = <String>[
    '🔌 $title',
    if (kva != null || price != null)
      [
        if (kva != null) '$kva KVA',
        if (price != null) 'EGP ${price}/day',
      ].join(' · '),
    if (location.isNotEmpty) '📍 $location',
    if (companyName != null) '🏢 $companyName',
    if (ratingStr != null) ratingStr,
    '',
    'احجز الآن على AnDaLoeS | Book now on AnDaLoeS for Generators',
    listingUrl,
    if (photoUrl != null) photoUrl,
  ];
  await Share.share(lines.join('\n'), subject: title);
}

Future<void> _copyLink(BuildContext context, String id) async {
  final link = 'https://andaloes.app/generators/$id';
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.linkCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
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
  ref.invalidate(isFavProvider(id));
}

void _showReportSheet(
    BuildContext context, WidgetRef ref, String id, ColorScheme cs) {
  final gen = ref.read(generatorDetailProvider(id)).valueOrNull;
  final name = gen?['title']?.toString() ?? 'Generator';
  final l = AppLocalizations.of(context)!;

  const issues = [
    ('misrepresentation', Icons.info_outline, 'Specs mismatch',
        'Capacity, price or photos don\'t match reality'),
    ('fraud', Icons.security_outlined, 'Suspected fraud',
        'Suspicious activity or payment request'),
    ('no_show', Icons.cancel_outlined, 'Generator unavailable',
        'Listed as available but owner not responding'),
    ('damage', Icons.build_outlined, 'Equipment damage',
        'Generator was returned damaged or in bad condition'),
    ('other', Icons.more_horiz, 'Other issue', 'Something else'),
  ];

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 18, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.reportProblemWith(name),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          ...issues.map((issue) => ListTile(
                leading: Icon(issue.$2, color: cs.onSurfaceVariant),
                title: Text(issue.$3,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(issue.$4,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.report(
                      type: 'generator',
                      id: id,
                      name: name,
                      reason: issue.$1));
                },
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}


// ── Shared chip helpers ───────────────────────────────────────────────────────
Widget _trustChip(
    IconData icon, String label, Color color, ColorScheme cs) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );

Widget _detailChip(
    IconData icon, String label, Color color, ColorScheme cs) =>
    _trustChip(icon, label, color, cs);
