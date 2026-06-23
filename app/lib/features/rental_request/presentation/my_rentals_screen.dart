import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase.dart';
import '../../chat/providers/chat_providers.dart';
import '../../../core/routing/app_routes.dart';

final myRentalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva, city, photos), companies(name)')
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

  static const _tabs = ['All', 'Active', 'Pending', 'Done'];

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> items, int tabIndex) {
    return switch (tabIndex) {
      1 => items
          .where((r) =>
              r['status'] == 'accepted' || r['status'] == 'active')
          .toList(),
      2 => items.where((r) => r['status'] == 'pending').toList(),
      3 => items
          .where((r) =>
              r['status'] == 'completed' ||
              r['status'] == 'cancelled' ||
              r['status'] == 'rejected')
          .toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rentals = ref.watch(myRentalsProvider);
    final cs = Theme.of(context).colorScheme;
    final all = rentals.valueOrNull ?? [];

    // Build per-tab counts for badges
    final counts = [
      all.length,
      all
          .where((r) =>
              r['status'] == 'accepted' || r['status'] == 'active')
          .length,
      all.where((r) => r['status'] == 'pending').length,
      all
          .where((r) =>
              r['status'] == 'completed' ||
              r['status'] == 'cancelled' ||
              r['status'] == 'rejected')
          .length,
    ];

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Rentals'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: List.generate(
              _tabs.length,
              (i) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tabs[i]),
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        body: rentals.when(
          loading: () => _RentalsSkeleton(cs: cs),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyRentals(cs: cs, onBrowse: () => context.go(AppRoutes.home));
            }
            return TabBarView(
              children: List.generate(_tabs.length, (tabIndex) {
                final filtered = _filter(items, tabIndex);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myRentalsProvider.future),
                    child: ListView(children: [
                      SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'No ${_tabs[tabIndex].toLowerCase()} rentals',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  );
                }
                // Spending summary at top of Done tab
                Widget? header;
                if (tabIndex == 3 && filtered.isNotEmpty) {
                  final completedOnly = filtered
                      .where((r) => r['status'] == 'completed')
                      .toList();
                  final total = completedOnly.fold<num>(
                      0,
                      (sum, r) =>
                          sum + ((r['price_total'] as num?) ?? 0));
                  if (total > 0) {
                    final avgSpend = completedOnly.isNotEmpty
                        ? (total / completedOnly.length)
                        : 0.0;
                    final totalDays = completedOnly.fold<num>(
                        0,
                        (s, r) =>
                            s + ((r['total_days'] as num?) ?? 0));
                    final avgDays = completedOnly.isNotEmpty
                        ? (totalDays / completedOnly.length)
                        : 0.0;
                    header = Column(
                      children: [
                      Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade700,
                            Colors.green.shade500,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(Icons.payments_outlined,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Total spent',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11)),
                            Text('EGP ${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            const Text('Rentals completed',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11)),
                            Text('${completedOnly.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ]),
                    ),
                    // Avg spend stats row
                    if (avgSpend > 0)
                      Container(
                        margin:
                            const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat(
                                label: 'Avg spend',
                                value:
                                    'EGP ${avgSpend.toStringAsFixed(0)}',
                                cs: cs),
                            Container(
                                width: 1,
                                height: 32,
                                color: cs.outlineVariant),
                            _MiniStat(
                                label: 'Avg duration',
                                value:
                                    '${avgDays.toStringAsFixed(1)} days',
                                cs: cs),
                            Container(
                                width: 1,
                                height: 32,
                                color: cs.outlineVariant),
                            _MiniStat(
                                label: 'Total days',
                                value: '$totalDays days',
                                cs: cs),
                          ],
                        ),
                      ),
                    ]);
                  }
                }

                // Build interleaved list with month header sentinels
                final grouped = <dynamic>[];
                String? lastMonth;
                for (final r in filtered) {
                  final raw = r['created_at']?.toString();
                  String monthKey = '';
                  String monthLabel = '';
                  if (raw != null) {
                    try {
                      final dt = DateTime.parse(raw).toLocal();
                      monthKey = '${dt.year}-${dt.month}';
                      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
                        'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      final now = DateTime.now();
                      monthLabel = dt.year == now.year
                          ? months[dt.month]
                          : '${months[dt.month]} ${dt.year}';
                    } catch (_) {}
                  }
                  if (monthKey.isNotEmpty && monthKey != lastMonth) {
                    grouped.add(monthLabel);
                    lastMonth = monthKey;
                  }
                  grouped.add(r);
                }
                final extraHeader = header != null ? 1 : 0;

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(myRentalsProvider.future),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, header != null ? 8 : 16, 16, 16),
                    itemCount: grouped.length + extraHeader,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      if (header != null && i == 0) return header;
                      final item = grouped[i - extraHeader];
                      // Month header sentinel
                      if (item is String) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }
                      final rental = item as Map<String, dynamic>;
                      final status =
                          rental['status']?.toString() ?? '';
                      final rentalId =
                          rental['id']?.toString() ?? '';

                      // Swipe-right → view doc; swipe-left → cancel pending
                      final canViewDoc = status == 'accepted' ||
                          status == 'active' ||
                          status == 'completed';
                      final canCancel = status == 'pending';

                      return Dismissible(
                        key: ValueKey('rental_$rentalId'),
                        direction: canViewDoc
                            ? DismissDirection.startToEnd
                            : canCancel
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                        confirmDismiss: (dir) async {
                          if (dir == DismissDirection.startToEnd &&
                              canViewDoc) {
                            final route = status == 'completed'
                                ? '/invoice/$rentalId'
                                : '/offer/$rentalId';
                            if (ctx.mounted) ctx.push(route);
                            return false;
                          }
                          if (dir == DismissDirection.endToStart &&
                              canCancel) {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: const Text('Cancel request?'),
                                content: const Text(
                                    'This will cancel your rental request.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('No'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: cs.error),
                                    child: const Text('Yes, cancel'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && ctx.mounted) {
                              await supabase
                                  .from('rental_requests')
                                  .update({'status': 'cancelled'}).eq(
                                      'id', rentalId);
                              ref.invalidate(myRentalsProvider);
                            }
                            return false;
                          }
                          return false;
                        },
                        background: canViewDoc
                            ? Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(children: [
                                  Icon(
                                    status == 'completed'
                                        ? Icons.receipt_long_outlined
                                        : Icons.description_outlined,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status == 'completed'
                                        ? 'Invoice'
                                        : 'Offer',
                                    style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                              )
                            : Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: cs.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      Icon(Icons.cancel_outlined,
                                          color: cs.error),
                                      const SizedBox(width: 8),
                                      Text('Cancel',
                                          style: TextStyle(
                                              color: cs.error,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                              ),
                        child: _RentalCard(
                            rental: rental, cs: cs, ref: ref),
                      );
                    },
                  ),
                );
              }),
            );
          },
        ),
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

    // Overdue: active rental whose end_date is in the past
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
        onTap: () => context.push(AppRoutes.generatorDetail(rental['generator_id'].toString())),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOverdue)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                color: Colors.red.shade700,
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text('Overdue — please contact owner',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
              ),
            Padding(
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
                  Expanded(
                    child: Text(
                      '${_fmt(rental['start_date'])}  →  ${_fmt(rental['end_date'])}',
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ),
                  if (status == 'active') Builder(builder: (_) {
                    final raw = rental['end_date']?.toString();
                    final end = raw != null ? DateTime.tryParse(raw) : null;
                    if (end == null) return const SizedBox.shrink();
                    final remaining = end.difference(DateTime.now()).inDays;
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
                        content: const Text('Rental ID copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    child: Tooltip(
                      message: 'Copy rental ID for support',
                      child: Icon(Icons.copy_outlined,
                          size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
              // Status timeline — hide for rejected/cancelled
              if (status != 'rejected' && status != 'cancelled') ...[
                const SizedBox(height: 14),
                _StatusTimeline(status: status, cs: cs),
              ],
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
                          rental['owner_note'].toString().isNotEmpty) ...[
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
                    minimumSize: const Size.fromHeight(40),
                    foregroundColor: cs.primary,
                  ),
                  onPressed: () =>
                      context.push(AppRoutes.offer(rental['id'].toString())),
                  icon: const Icon(Icons.description_outlined, size: 15),
                  label: const Text('View Offer',
                      style: TextStyle(fontSize: 13)),
                ),
                if (status == 'active') ...[
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Mark as received?'),
                          content: const Text(
                              'Confirm the generator was delivered and is in use. '
                              'The owner will be notified.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Not yet')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes, received')),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      try {
                        await supabase
                            .from('rental_requests')
                            .update({'status': 'completed'})
                            .eq('id', rental['id'].toString());
                        ref.invalidate(myRentalsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Marked as received!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: const Text('Mark as Received',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
                Builder(builder: (_) {
                  final note = rental['note']?.toString() ?? '';
                  final prefix = 'Delivery address: ';
                  final addressLine =
                      note.split('\n').firstWhere(
                          (l) => l.startsWith(prefix),
                          orElse: () => '');
                  final address = addressLine.isNotEmpty
                      ? addressLine.substring(prefix.length).trim()
                      : '';
                  if (address.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        foregroundColor: cs.secondary,
                      ),
                      onPressed: () async {
                        final q = Uri.encodeComponent(address);
                        final url =
                            Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text('Track Delivery',
                          style: TextStyle(fontSize: 13)),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                _ChatButton(
                  rentalId: rental['id'].toString(),
                  label: 'Chat with owner',
                  otherPartyName: (rental['companies'] as Map<String, dynamic>?)?['name']
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
                          rental['owner_note'].toString().isNotEmpty) ...[
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
                      context.push(AppRoutes.invoice(rental['id'].toString())),
                  icon: const Icon(Icons.receipt_long_outlined,
                      size: 15),
                  label: const Text('View Invoice',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(38),
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      context.push(AppRoutes.receipt(rental['id'].toString())),
                  icon: const Icon(Icons.receipt_outlined, size: 15),
                  label: const Text('View receipt',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
              if (status == 'completed' || status == 'active') ...[
                const SizedBox(height: 4),
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
      ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, String id) async {
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
          title: const Text('Cancel request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you cancelling?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final reason in reasons)
                RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (v) => setS(() => selectedReason = v),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep request')),
            FilledButton(
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Cancel request')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await supabase.from('rental_requests').update({
        'status': 'cancelled',
        if (selectedReason != null) 'note': 'Cancelled: $selectedReason',
      }).eq('id', id);
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

// ── Status progress timeline ──────────────────────────────────────────────────
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status, required this.cs});
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIndex = (i - 1) ~/ 2;
          final done = _currentIndex > stepIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: done
                  ? cs.primary
                  : cs.outlineVariant,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = _currentIndex > stepIndex;
        final active = _currentIndex == stepIndex;
        final color = done || active ? cs.primary : cs.outlineVariant;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 28 : 22,
              height: active ? 28 : 22,
              decoration: BoxDecoration(
                color: done || active ? cs.primary : cs.surfaceContainerHighest,
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
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                color: active ? cs.primary : color,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _EmptyRentals extends StatelessWidget {
  const _EmptyRentals({required this.cs, required this.onBrowse});
  final ColorScheme cs;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stacked icon illustration
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
            Text('No rentals yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 10),
            Text(
              'Browse available generators nearby\nand send your first rental request.',
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Browse generators'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton shown while rentals load ─────────────────────────────────────────
class _RentalsSkeleton extends StatefulWidget {
  const _RentalsSkeleton({required this.cs});
  final ColorScheme cs;

  @override
  State<_RentalsSkeleton> createState() => _RentalsSkeletonState();
}

class _RentalsSkeletonState extends State<_RentalsSkeleton>
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
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 160, height: 14,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 100, height: 11,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                  ]),
                  const Spacer(),
                  Container(width: 60, height: 22,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(11))),
                ]),
                Row(children: [
                  Container(width: 90, height: 11,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  Container(width: 70, height: 11,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatButton extends StatelessWidget {
  const _ChatButton({
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
    final unread = wRef.watch(unreadMessagesProvider(rentalId)).valueOrNull ?? 0;
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
        ),
        onPressed: () => context.push(
            '/chat/$rentalId?name=${Uri.encodeComponent(otherPartyName)}'),
        icon: const Icon(Icons.chat_outlined, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.cs});
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
            style:
                TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
