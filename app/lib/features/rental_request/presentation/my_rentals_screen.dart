import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';

final myRentalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva, city, photos)')
      .eq('customer_id', uid)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

// Rental request IDs that the current user has already submitted a rating for.
final _myRatedRentalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('ratings')
      .select('rental_request_id')
      .eq('rater_id', uid);
  return {
    for (final r in (data as List))
      r['rental_request_id'].toString()
  };
});

const _statusLabels = {
  'accepted': 'Rental accepted',
  'rejected': 'Rental rejected',
  'active': 'Rental is now active',
  'completed': 'Rental completed',
  'cancelled': 'Rental cancelled',
};

class MyRentalsScreen extends ConsumerStatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  ConsumerState<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends ConsumerState<MyRentalsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    _channel = supabase
        .channel('my-rentals-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rental_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: uid,
          ),
          callback: (payload) {
            ref.invalidate(myRentalsProvider);
            final newStatus =
                (payload.newRecord['status'] as String?) ?? '';
            final label = _statusLabels[newStatus];
            if (label != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(label),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ));
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rentals = ref.watch(myRentalsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Rentals')),
      body: rentals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.receipt_long, size: 36, color: cs.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text('No rentals yet',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Browse generators and send your first request.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: () => context.go('/'),
                      child: const Text('Browse generators'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myRentalsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) =>
                  _RentalCard(rental: items[i], cs: cs, ref: ref),
            ),
          );
        },
      ),
    );
  }
}

class _RentalCard extends ConsumerWidget {
  const _RentalCard(
      {required this.rental, required this.cs, required this.ref});
  final Map<String, dynamic> rental;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final gen = rental['generators'] as Map<String, dynamic>?;
    final status = rental['status']?.toString() ?? 'pending';
    final statusColor = _statusColor(status, cs);
    final photos = (gen?['photos'] as List?)?.cast<String>() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final rentalId = rental['id']?.toString() ?? '';
    final alreadyRated = wRef
            .watch(_myRatedRentalIdsProvider)
            .valueOrNull
            ?.contains(rentalId) ==
        true;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/generators/${rental['generator_id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: thumbnail + status chip + price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Generator photo thumbnail
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
                              child: Icon(Icons.bolt,
                                  color: cs.primary, size: 24),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: cs.primaryContainer,
                            child: Icon(Icons.bolt,
                                color: cs.primary, size: 24),
                          ),
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
                                _statusLabel(status),
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
              // Date row
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmt(rental['start_date'])}  →  ${_fmt(rental['end_date'])}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${rental['total_days']} day${rental['total_days'] == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              // Action buttons by status
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                  ),
                  onPressed: () => _cancel(context, rental['id']),
                  child: const Text('Cancel request'),
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
                  child: const Row(children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Accepted — the owner will contact you soon.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ]),
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
                        Text('You rated this rental',
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
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: () {
                      context.push(
                        '/rate/${rental['id']}?ratee=${rental['company_id']}&name=Owner',
                      );
                    },
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Rate this rental'),
                  ),
              ],
              if (status == 'completed' || status == 'active') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    minimumSize: const Size.fromHeight(36),
                  ),
                  onPressed: () => context.push(
                    '/report?type=company&id=${rental['company_id']}&rental=${rental['id']}&name=Owner',
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 15),
                  label: const Text('Report an issue',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel request'),
        content: const Text('Are you sure you want to cancel this rental request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await supabase
          .from('rental_requests')
          .update({'status': 'cancelled'}).eq('id', id);
      ref.invalidate(myRentalsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    return switch (status) {
      'pending' => Colors.orange,
      'accepted' => Colors.green,
      'active' => cs.primary,
      'completed' => Colors.green.shade700,
      'rejected' => cs.error,
      'cancelled' => cs.onSurfaceVariant,
      _ => cs.onSurfaceVariant,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => 'PENDING',
      'accepted' => 'ACCEPTED',
      'active' => 'ACTIVE',
      'completed' => 'COMPLETED',
      'rejected' => 'REJECTED',
      'cancelled' => 'CANCELLED',
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
