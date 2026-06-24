import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/commission.dart';
import '../../../../core/utils/db_error.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../ratings/presentation/rate_rental_screen.dart';
import '../../../rental_request/data/rental_repository.dart';
import '../../providers/owner_providers.dart'
    show ownerRequestsProvider, commissionConfigProvider;

class OwnerRequestCard extends StatelessWidget {
  const OwnerRequestCard({
    super.key,
    required this.request,
    required this.ref,
    required this.companyId,
  });
  final Map<String, dynamic> request;
  final WidgetRef ref;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final gen = request['generators'] as Map<String, dynamic>?;
    final customer = request['profiles'] as Map<String, dynamic>?;
    final status = request['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _RequestStatusChip(status: status, cs: cs),
              if (isPending) ...[
                const SizedBox(width: 8),
                Builder(builder: (_) {
                  final raw = request['created_at']?.toString();
                  final created = raw != null ? DateTime.tryParse(raw) : null;
                  if (created == null) return const SizedBox.shrink();
                  final mins = DateTime.now().difference(created).inMinutes;
                  final Color c = mins < 60
                      ? Colors.green.shade700
                      : mins < 240
                          ? Colors.orange.shade800
                          : Colors.red.shade700;
                  final label = mins < 60
                      ? l.minsAgo(mins)
                      : mins < 240
                          ? l.hrsAgo(mins ~/ 60)
                          : l.hrsAgoRespond(mins ~/ 60);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer_outlined, size: 11, color: c),
                      const SizedBox(width: 3),
                      Text(label,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: c)),
                    ]),
                  );
                }),
              ],
              const Spacer(),
              Text('EGP ${request['price_total'] ?? '-'}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ]),
            // Projected net payout (rental total minus platform commission).
            ref.watch(commissionConfigProvider(companyId)).maybeWhen(
                  data: (rule) {
                    final total = (request['price_total'] as num?) ?? 0;
                    final p = projectCommission(total, rule);
                    if (p.commission <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 13, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(l.youReceiveEgp(p.net.toStringAsFixed(0)),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('· ${p.label}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ),
                      ]),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
            const SizedBox(height: 12),
            Text(gen?['title']?.toString() ?? 'Generator',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                customer?['full_name'] ??
                    customer?['phone'] ??
                    l.customer,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${_fmt(request['start_date'])}  →  ${_fmt(request['end_date'])}  (${request['total_days']} days)',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ]),
            // Delivery details (where/when the customer wants the generator)
            if ((request['delivery_address']?.toString().isNotEmpty ?? false) ||
                (request['delivery_time']?.toString().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.local_shipping_outlined,
                    size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (request['delivery_address']?.toString().isNotEmpty ??
                          false)
                        request['delivery_address'].toString(),
                      if (request['delivery_time']?.toString().isNotEmpty ??
                          false)
                        '(${request['delivery_time']})',
                    ].join(' '),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                ),
              ]),
            ],
            // Deposit collection reminder for active/accepted rentals
            Builder(builder: (_) {
              final deposit =
                  (request['deposit_amount'] as num?)?.toDouble() ?? 0;
              if (deposit <= 0 ||
                  !['accepted', 'active'].contains(status)) {
                return const SizedBox.shrink();
              }
              final amt = deposit.toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.payments_outlined,
                        size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.collectDepositOnDelivery(amt),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900),
                      ),
                    ),
                  ]),
                ),
              );
            }),
            if (request['note'] != null &&
                request['note'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(request['note'].toString(),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side:
                          BorderSide(color: cs.error.withValues(alpha: 0.4)),
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () =>
                        _rejectWithNote(context, request['id'].toString()),
                    child: Text(l.reject),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressScale(
                    onTap: () =>
                        _acceptWithNote(context, request['id'].toString()),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
                      onPressed: () =>
                          _acceptWithNote(context, request['id'].toString()),
                      child: Text(l.accept),
                    ),
                  ),
                ),
              ]),
            ],
            if (status == 'accepted' || status == 'active') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: cs.primary,
                ),
                onPressed: () =>
                    context.push(AppRoutes.offer(request['id'].toString())),
                icon: const Icon(Icons.description_outlined, size: 15),
                label: Text(l.viewOffer,
                    style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 4),
              _OwnerChatButton(request: request, ref: ref),
            ],
            if (status == 'completed') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(
                      color: Colors.green.withValues(alpha: 0.4)),
                ),
                onPressed: () =>
                    context.push(AppRoutes.invoice(request['id'].toString())),
                icon: const Icon(Icons.receipt_long_outlined, size: 15),
                label: Text(l.viewInvoice,
                    style: TextStyle(fontSize: 13)),
              ),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 8),
              if (request['delivered_at'] == null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _markOutForDelivery(context),
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: Text(l.outForDelivery),
                )
              else ...[
                Row(children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(l.outForDelivery,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                ]),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _updateStatus(
                      context, request['id'].toString(), 'active'),
                  child: Text(l.confirmDeliveredStart),
                ),
              ],
            ],
            if (status == 'active') ...[
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () => _updateStatus(
                    context, request['id'].toString(), 'completed'),
                child: Text(l.markAsCompleted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acceptWithNote(
      BuildContext context, String requestId) async {
    final l = AppLocalizations.of(context)!;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.acceptRequest),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.optionalMessageToCustomer,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'e.g. I will arrive at 9am. Please ensure access.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.accept)),
        ],
      ),
    );
    if (confirmed == true) {
      final note = noteController.text.trim();
      await _updateStatus(context, requestId, 'accepted',
          ownerNote: note.isNotEmpty ? note : null);
    }
  }

  Future<void> _rejectWithNote(
      BuildContext context, String requestId) async {
    final l = AppLocalizations.of(context)!;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.rejectRequest),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.letCustomerKnowWhy,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Generator is already booked for those dates.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.reject),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final note = noteController.text.trim();
      await _updateStatus(context, requestId, 'rejected',
          ownerNote: note.isNotEmpty ? note : null);
    }
  }

  Future<void> _markOutForDelivery(BuildContext context) async {
    try {
      await ref
          .read(rentalRepositoryProvider)
          .markOutForDelivery(request['id'].toString());
      ref.invalidate(ownerRequestsProvider(companyId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyDbError(e))));
      }
    }
  }

  Future<void> _updateStatus(
      BuildContext context, String requestId, String newStatus,
      {String? ownerNote}) async {
    try {
      final update = <String, dynamic>{'status': newStatus};
      if (ownerNote != null) update['owner_note'] = ownerNote;
      await supabase
          .from('rental_requests')
          .update(update)
          .eq('id', requestId);
      ref.invalidate(ownerRequestsProvider(companyId));
      if (newStatus == 'completed' && context.mounted) {
        final customerId = request['customer_id']?.toString() ?? '';
        final customerName =
            (request['profiles'] as Map<String, dynamic>?)?['full_name'] ??
                (request['profiles'] as Map<String, dynamic>?)?['phone'] ??
                'Customer';
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RateRentalScreen(
            rentalRequestId: requestId,
            rateeId: customerId,
            rateeName: customerName.toString(),
            isOwnerRating: true,
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyDbError(e))));
      }
    }
  }

  static String _fmt(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }
}

class _OwnerChatButton extends ConsumerWidget {
  const _OwnerChatButton({required this.request, required this.ref});
  final Map<String, dynamic> request;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final l = AppLocalizations.of(context)!;
    final rentalId = request['id'].toString();
    final unread =
        wRef.watch(unreadMessagesProvider(rentalId)).valueOrNull ?? 0;
    final customer = request['profiles'] as Map<String, dynamic>?;
    final name = (customer?['full_name'] ?? customer?['phone'] ?? 'Customer').toString();

    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40)),
        onPressed: () => context.push(
            '/chat/$rentalId?name=${Uri.encodeComponent(name)}'),
        icon: const Icon(Icons.chat_outlined, size: 16),
        label: Text(l.chatWithCustomer),
      ),
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.status, required this.cs});
  final String status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = rentalStatusColor(status, cs);
    final label = switch (status) {
      'pending' => l.statusPending,
      'accepted' => l.statusAccepted,
      'active' => l.statusActive,
      'completed' => l.statusCompleted,
      'rejected' => l.statusRejected,
      'cancelled' => l.statusCancelled,
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
