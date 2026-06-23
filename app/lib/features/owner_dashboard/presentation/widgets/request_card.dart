import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/db_error.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../chat/providers/chat_providers.dart';
import '../../../ratings/presentation/rate_rental_screen.dart';
import '../../providers/owner_providers.dart' show ownerRequestsProvider;

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
              const Spacer(),
              Text('EGP ${request['price_total'] ?? '-'}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ]),
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
                    'Customer',
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
                    child: const Text('Reject'),
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
                      child: const Text('Accept'),
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
                label: const Text('View Offer',
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
                label: const Text('View Invoice',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40)),
                onPressed: () =>
                    _updateStatus(context, request['id'].toString(), 'active'),
                child: const Text('Mark as started'),
              ),
            ],
            if (status == 'active') ...[
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40)),
                onPressed: () => _updateStatus(
                    context, request['id'].toString(), 'completed'),
                child: const Text('Mark as completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acceptWithNote(
      BuildContext context, String requestId) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add an optional message to the customer:',
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept')),
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
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Let the customer know why (optional):',
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
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
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
        label: const Text('Chat with customer'),
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
    final (color, label) = switch (status) {
      'pending' => (Colors.orange, 'Pending'),
      'accepted' => (Colors.green, 'Accepted'),
      'active' => (cs.primary, 'Active'),
      'completed' => (Colors.green.shade700, 'Completed'),
      'rejected' => (cs.error, 'Rejected'),
      'cancelled' => (cs.onSurfaceVariant, 'Cancelled'),
      _ => (cs.onSurfaceVariant, status),
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
