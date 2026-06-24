import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/utils/ics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../data/rental_repository.dart'
    show rentalTimelineProvider, rentalHandoversProvider;
import '../providers/rental_providers.dart'
    show myRentalsProvider, rentalRepositoryProvider;

// ── Rental card ───────────────────────────────────────────────────────────────
// Private provider for rated rental IDs — lives with the widget that owns it.
final myRatedRentalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final repo = ref.read(rentalRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return {};
  return repo.fetchRatedRentalIds(uid);
});

class RentalCard extends ConsumerWidget {
  const RentalCard(
      {super.key, required this.rental, required this.cs, required this.ref});
  final Map<String, dynamic> rental;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final l = AppLocalizations.of(context)!;
    final gen = rental['generators'] as Map<String, dynamic>?;
    final status = rental['status']?.toString() ?? 'pending';
    final statusColor = rentalStatusColor(status, cs);
    final photos = (gen?['photos'] as List?)?.cast<String>() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final rentalId = rental['id']?.toString() ?? '';
    final alreadyRated = wRef
            .watch(myRatedRentalIdsProvider)
            .valueOrNull
            ?.contains(rentalId) ==
        true;

    final isOverdue = status == 'active' &&
        () {
          final raw = rental['end_date']?.toString();
          if (raw == null) return false;
          final end = DateTime.tryParse(raw);
          return end != null && end.isBefore(DateTime.now());
        }();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context
            .push(AppRoutes.generatorDetail(rental['generator_id'].toString())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOverdue)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.red.shade700,
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(l.overdueContactOwner,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
            if (status == 'accepted' && rental['delivered_at'] != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: cs.primary,
                child: Row(children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(l.outForDeliveryBanner,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l.confirmReceipt),
                    onPressed: () =>
                        _confirmReceipt(context, rental['id'] as String),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: firstPhoto != null
                            ? Image.network(
                                firstPhoto,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _photoPlaceholder(cs),
                              )
                            : _photoPlaceholder(cs),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(status, l),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'EGP ${rental['price_total'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              gen?['title']?.toString() ?? 'Generator',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${gen?['capacity_kva']} KVA  •  ${gen?['city'] ?? ''}',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_fmt(rental['start_date'])}  →  ${_fmt(rental['end_date'])}',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ),
                      if (status != 'cancelled' && status != 'rejected')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: l.addToCalendar,
                          icon: Icon(Icons.event_available_outlined,
                              size: 17, color: cs.primary),
                          onPressed: () {
                            final s = DateTime.tryParse(
                                rental['start_date']?.toString() ?? '');
                            final e = DateTime.tryParse(
                                rental['end_date']?.toString() ?? '');
                            if (s == null || e == null) return;
                            shareRentalCalendar(
                              id: rental['id'].toString(),
                              title: gen?['title']?.toString() ?? 'Generator',
                              start: s,
                              end: e,
                              location: gen?['city']?.toString(),
                            );
                          },
                        ),
                      const SizedBox(width: 4),
                      if (status == 'active')
                        Builder(builder: (_) {
                          final raw = rental['end_date']?.toString();
                          final end =
                              raw != null ? DateTime.tryParse(raw) : null;
                          if (end == null) return const SizedBox.shrink();
                          final remaining =
                              end.difference(DateTime.now()).inDays;
                          final overdue = remaining < 0;
                          final label = overdue
                              ? '${-remaining}d overdue'
                              : remaining == 0
                                  ? 'ends today'
                                  : '$remaining day${remaining == 1 ? '' : 's'} left';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: overdue
                                  ? Colors.red.withValues(alpha: 0.12)
                                  : remaining <= 2
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: overdue
                                        ? Colors.red.shade700
                                        : remaining <= 2
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700)),
                          );
                        })
                      else
                        Text(
                          '${rental['total_days']} day${rental['total_days'] == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500),
                        ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: rentalId));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(l.rentalIdCopied),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ));
                        },
                        child: Tooltip(
                          message: 'Copy rental ID for support',
                          child: Icon(Icons.copy_outlined,
                              size: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                      ),
                    ],
                  ),
                  if (status != 'rejected' && status != 'cancelled') ...[
                    const SizedBox(height: 14),
                    RentalStatusTimeline(
                        rentalId: rentalId, status: status, cs: cs),
                  ],
                  if (status == 'pending') ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: cs.error,
                        side: BorderSide(
                            color: cs.error.withValues(alpha: 0.4)),
                      ),
                      onPressed: () => _cancel(context, rental['id']),
                      child: Text(l.cancelRequest),
                    ),
                  ],
                  if (status == 'accepted') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Accepted — the owner will contact you soon.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green),
                              ),
                            ),
                          ]),
                          if (rental['owner_note'] != null &&
                              rental['owner_note']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.message_outlined,
                                    size: 13,
                                    color: Colors.green.shade700),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    rental['owner_note'].toString(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade800,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (status == 'accepted' || status == 'active') ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: cs.primary,
                      ),
                      onPressed: () => context
                          .push(AppRoutes.offer(rental['id'].toString())),
                      icon: const Icon(Icons.description_outlined, size: 15),
                      label: Text(l.viewOffer,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Builder(builder: (_) {
                      final address =
                          rental['delivery_address']?.toString() ?? '';
                      if (address.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: cs.secondary,
                          ),
                          onPressed: () async {
                            final q = Uri.encodeComponent(address);
                            final url = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=$q');
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.map_outlined, size: 15),
                          label: Text(l.trackDelivery,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      );
                    }),
                    Builder(builder: (_) {
                      final deposit =
                          (rental['deposit_amount'] as num?)?.toDouble() ?? 0;
                      if (deposit <= 0 ||
                          !['accepted', 'active', 'completed']
                              .contains(status)) {
                        return const SizedBox.shrink();
                      }
                      final amt = deposit.toStringAsFixed(0);
                      final text = switch (status) {
                        'completed' =>
                          'Deposit EGP $amt · returned after rental',
                        'active' => 'Refundable deposit: EGP $amt held',
                        _ =>
                          'Refundable deposit: EGP $amt (collected on delivery)',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.shield_outlined,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(text,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant)),
                          ),
                        ]),
                      );
                    }),
                    if (['active', 'completed'].contains(status))
                      Consumer(builder: (ctx, r, _) {
                        final handovers = r
                            .watch(rentalHandoversProvider(
                                rental['id'].toString()))
                            .valueOrNull;
                        if (handovers == null || handovers.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: handovers.map((h) {
                            final isDelivery = h['type'] == 'delivery';
                            final fuel = h['fuel_level'] as String?;
                            final meter = h['meter_reading'];
                            if (fuel == null && meter == null) {
                              return const SizedBox.shrink();
                            }
                            final fuelLabel = switch (fuel) {
                              'full' => AppLocalizations.of(ctx)!.fuelFull,
                              'three_quarters' =>
                                AppLocalizations.of(ctx)!.fuelThreeQuarters,
                              'half' => AppLocalizations.of(ctx)!.fuelHalf,
                              'quarter' =>
                                AppLocalizations.of(ctx)!.fuelQuarter,
                              'empty' => AppLocalizations.of(ctx)!.fuelEmpty,
                              _ => null,
                            };
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(children: [
                                Icon(
                                  isDelivery
                                      ? Icons.local_shipping_outlined
                                      : Icons.assignment_return_outlined,
                                  size: 13,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                if (fuelLabel != null)
                                  Text('⛽ $fuelLabel',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                if (fuelLabel != null && meter != null)
                                  Text(' · ',
                                      style: TextStyle(
                                          color: cs.onSurfaceVariant)),
                                if (meter != null)
                                  Text('${meter}h',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                              ]),
                            );
                          }).toList(),
                        );
                      }),
                    const SizedBox(height: 4),
                    RentalChatButton(
                      rentalId: rental['id'].toString(),
                      label: 'Chat with owner',
                      otherPartyName:
                          (rental['companies'] as Map<String, dynamic>?)?[
                                  'name']
                              ?.toString() ??
                              'Owner',
                      wRef: wRef,
                      context: context,
                    ),
                  ],
                  if (status == 'rejected') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.cancel_outlined,
                                size: 16, color: cs.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Request was rejected.',
                                style: TextStyle(
                                    fontSize: 12, color: cs.error),
                              ),
                            ),
                          ]),
                          if (rental['owner_note'] != null &&
                              rental['owner_note']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.message_outlined,
                                    size: 13, color: cs.onErrorContainer),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    rental['owner_note'].toString(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onErrorContainer,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (status == 'completed') ...[
                    const SizedBox(height: 12),
                    if (alreadyRated)
                      Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.amber.shade300, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber.shade600),
                            const SizedBox(width: 6),
                            Text(l.youRatedThis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.amber.shade800,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          context.push(
                            '/rate/${rental['id']}?ratee=${rental['company_id']}&name=Owner',
                          );
                        },
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: Text(l.rateThisRental),
                      ),
                  ],
                  if (status == 'completed') ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            minimumSize: const Size.fromHeight(48),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => context
                              .push(AppRoutes.invoice(rental['id'].toString())),
                          icon: const Icon(Icons.receipt_long_outlined,
                              size: 15),
                          label: Text(l.viewInvoice,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            minimumSize: const Size.fromHeight(48),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => context
                              .push(AppRoutes.receipt(rental['id'].toString())),
                          icon: const Icon(Icons.receipt_outlined, size: 15),
                          label: Text(l.viewReceipt,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                            minimumSize: const Size.fromHeight(48),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => context.push(
                              '/report?type=company&id=${rental['company_id']}&rental=${rental['id']}&name=Owner'),
                          icon: const Icon(Icons.flag_outlined, size: 15),
                          label: Text(l.reportAnIssue,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ]),
                  ],
                  if (status == 'active') ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurfaceVariant,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => context.push(
                        '/report?type=company&id=${rental['company_id']}&rental=${rental['id']}&name=Owner',
                      ),
                      icon: const Icon(Icons.flag_outlined, size: 15),
                      label: Text(l.reportAnIssue,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(ColorScheme cs) => Container(
        width: 56,
        height: 56,
        color: cs.primaryContainer,
        child: Icon(Icons.bolt, color: cs.primary, size: 24),
      );

  Future<void> _cancel(BuildContext context, String id) async {
    final l = AppLocalizations.of(context)!;
    const reasons = [
      'Changed my mind',
      'Found a better option',
      'Price too high',
      'Dates no longer available',
      'Other',
    ];
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.cancelRequest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.whyCancelling,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final reason in reasons)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (v) => setS(() => selectedReason = v),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.keepRequest)),
            FilledButton(
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(l.cancelRequest)),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(rentalRepositoryProvider).cancelRentalRequest(
            id,
            note: selectedReason != null ? 'Cancelled: $selectedReason' : null,
          );
      ref.invalidate(myRentalsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmReceipt(BuildContext context, String rentalId) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.markReceivedQ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.notYet)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.yesReceived)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(rentalRepositoryProvider).confirmRentalReceipt(rentalId);
      ref.invalidate(myRentalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.markedReceived)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.errorGeneric)),
        );
      }
    }
  }

  String _statusLabel(String status, AppLocalizations l) {
    return switch (status) {
      'pending' => l.statusPending,
      'accepted' => l.statusAccepted,
      'active' => l.statusActive,
      'completed' => l.statusCompleted,
      'rejected' => l.statusRejected,
      'cancelled' => l.statusCancelled,
      _ => status.toUpperCase(),
    };
  }

  String _fmt(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}

// ── Status progress timeline ──────────────────────────────────────────────────
class RentalStatusTimeline extends ConsumerWidget {
  const RentalStatusTimeline(
      {super.key, required this.rentalId, required this.status, required this.cs});
  final String rentalId;
  final String status;
  final ColorScheme cs;

  static const _steps = ['pending', 'accepted', 'active', 'completed'];
  static const _labels = ['Submitted', 'Accepted', 'Active', 'Done'];
  static const _icons = [
    Icons.send_rounded,
    Icons.check_circle_outline,
    Icons.bolt,
    Icons.verified_outlined,
  ];

  int get _currentIndex => _steps.indexOf(status);

  String _tsFor(String step, List<Map<String, dynamic>> events) {
    final match = events.lastWhere(
      (e) => e['event'] == step,
      orElse: () => {},
    );
    final raw = match['created_at']?.toString();
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} $h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(rentalTimelineProvider(rentalId)).valueOrNull ?? const [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = (i - 1) ~/ 2;
          final done = _currentIndex > stepIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Container(
                height: 2,
                color: done ? cs.primary : cs.outlineVariant,
              ),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = _currentIndex > stepIndex;
        final active = _currentIndex == stepIndex;
        final color = done || active ? cs.primary : cs.outlineVariant;
        final ts = _tsFor(_steps[stepIndex], events);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 28 : 22,
              height: active ? 28 : 22,
              decoration: BoxDecoration(
                color: done || active
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(
                        color: cs.primary.withValues(alpha: 0.35), width: 3)
                    : null,
              ),
              child: Icon(
                _icons[stepIndex],
                size: active ? 14 : 11,
                color: done || active ? cs.onPrimary : cs.outlineVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _labels[stepIndex],
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? cs.primary : color,
              ),
            ),
            if (ts.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                ts,
                style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class RentalsEmptyState extends StatelessWidget {
  const RentalsEmptyState(
      {super.key, required this.cs, required this.onBrowse});
  final ColorScheme cs;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt, size: 44, color: cs.primary),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.1),
                              blurRadius: 8),
                        ],
                      ),
                      child: Icon(Icons.receipt_long,
                          size: 20, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(l.noRentalsYet,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 10),
            Text(
              'Browse available generators nearby\nand send your first rental request.',
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: Text(l.browseGenerators),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class RentalsSkeleton extends StatefulWidget {
  const RentalsSkeleton({super.key, required this.cs});
  final ColorScheme cs;

  @override
  State<RentalsSkeleton> createState() => _RentalsSkeletonState();
}

class _RentalsSkeletonState extends State<RentalsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = cs.onSurface.withValues(alpha: _anim.value * 0.18);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(
            height: 130,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 160,
                            height: 14,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Container(
                            width: 100,
                            height: 11,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(4))),
                      ]),
                  const Spacer(),
                  Container(
                      width: 60,
                      height: 22,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(11))),
                ]),
                Row(children: [
                  Container(
                      width: 90,
                      height: 11,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  Container(
                      width: 70,
                      height: 11,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Chat button with unread badge ─────────────────────────────────────────────
class RentalChatButton extends StatelessWidget {
  const RentalChatButton({
    super.key,
    required this.rentalId,
    required this.label,
    required this.otherPartyName,
    required this.wRef,
    required this.context,
  });
  final String rentalId;
  final String label;
  final String otherPartyName;
  final WidgetRef wRef;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    final unread =
        wRef.watch(unreadMessagesProvider(rentalId)).valueOrNull ?? 0;
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: () => context.push(
            '/chat/$rentalId?name=${Uri.encodeComponent(otherPartyName)}'),
        icon: const Icon(Icons.chat_outlined, size: 16),
        label: Text(label),
      ),
    );
  }
}

// ── Mini stat chip (used in rentals header) ───────────────────────────────────
class MiniRentalStat extends StatelessWidget {
  const MiniRentalStat(
      {super.key, required this.label, required this.value, required this.cs});
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
