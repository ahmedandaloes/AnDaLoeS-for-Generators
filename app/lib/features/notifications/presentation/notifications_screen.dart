import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../core/routing/app_routes.dart';
import '../providers/notifications_providers.dart'
    show notificationsProvider, unreadCountProvider;

export '../providers/notifications_providers.dart' show unreadCountProvider;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    _channel = supabase
        .channel('notifications-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          },
        )
        .subscribe();
  }

  Future<void> _markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markOneRead(String id) async {
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _dismiss(String id) async {
    await supabase.from('notifications').delete().eq('id', id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Layered bell illustration
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer glow ring
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primaryContainer
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  // Mid ring
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primaryContainer
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  // Inner circle
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primaryContainer,
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_outlined,
                                      size: 28,
                                      color: cs.primary,
                                    ),
                                  ),
                                  // Small checkmark badge
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade500,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: cs.surface, width: 2),
                                      ),
                                      child: const Icon(Icons.check,
                                          size: 12,
                                          color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('All caught up',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(
                              'Rental updates and owner alerts will appear here.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by day
          final groups = _groupByDay(items);
          // Flatten into a mixed list of headers + items
          final rows = <_Row>[];
          for (final entry in groups.entries) {
            rows.add(_Row.header(entry.key));
            for (final n in entry.value) {
              rows.add(_Row.item(n));
            }
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final row = rows[i];
                if (row.isHeader) {
                  return _DayHeader(label: row.label!, cs: cs);
                }
                final n = row.item!;
                final id = n['id']?.toString() ?? '';
                final isRead = n['is_read'] == true;
                final type = n['type']?.toString() ?? '';
                final rentalId = n['rental_request_id']?.toString();

                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: cs.errorContainer,
                    child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                  ),
                  onDismissed: (_) => _dismiss(id),
                  child: InkWell(
                    onTap: () {
                      if (!isRead) _markOneRead(id);
                      _navigate(context, type, rentalId, n);
                    },
                    child: Container(
                      color: isRead
                          ? null
                          : cs.primaryContainer.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _iconBg(type, cs),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconFor(type),
                                size: 20, color: _iconColor(type, cs)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      n['title']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ]),
                                if (n['body'] != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    n['body'].toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  _timeAgo(DateTime.tryParse(
                                          n['created_at']?.toString() ?? '') ??
                                      DateTime.now()),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Group notifications into Today / Yesterday / date buckets
  Map<String, List<Map<String, dynamic>>> _groupByDay(
      List<Map<String, dynamic>> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final n in items) {
      final ts = DateTime.tryParse(n['created_at']?.toString() ?? '');
      if (ts == null) continue;
      final day = DateTime(ts.year, ts.month, ts.day);
      String label;
      if (day == today) {
        label = 'Today';
      } else if (day == yesterday) {
        label = 'Yesterday';
      } else {
        label = '${day.day}/${day.month}/${day.year}';
      }
      groups.putIfAbsent(label, () => []).add(n);
    }
    return groups;
  }

  void _navigate(
      BuildContext context, String type, String? rentalId, Map<String, dynamic> n) {
    switch (type) {
      case 'request_accepted':
        // Owner accepted → show the formal offer document
        if (rentalId != null) context.push(AppRoutes.offer(rentalId));
      case 'request_rejected':
        // Rejected → land on My Rentals so user sees the rejection note
        context.push(AppRoutes.myRentals);
      case 'rental_started':
      case 'rental_status':
        // Rental went active → My Rentals overview
        context.push(AppRoutes.myRentals);
      case 'rental_completed':
        // Completed → tax invoice
        if (rentalId != null) context.push(AppRoutes.invoice(rentalId));
      case 'new_request':
        // Owner gets new request → Owner Dashboard
        context.push(AppRoutes.ownerDashboard);
      case 'new_message':
        // Chat message → open chat thread
        final otherName = n['data']?['sender_name']?.toString() ?? 'Chat';
        if (rentalId != null) {
          context.push(AppRoutes.chat(rentalId, otherName: otherName));
        }
      case 'rating_reminder':
        // Prompt to rate → rate screen (need ratee info from data)
        final data = n['data'] as Map<String, dynamic>?;
        final rateeId = data?['ratee_id']?.toString();
        final rateeName = data?['ratee_name']?.toString() ?? 'User';
        if (rentalId != null && rateeId != null) {
          context.push(AppRoutes.rate(rentalId, rateeId: rateeId, rateeName: rateeName));
        }
      default:
        // Fallback: open My Rentals
        if (rentalId != null) context.push(AppRoutes.myRentals);
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'request_accepted' => Icons.check_circle_outline,
        'request_rejected' => Icons.cancel_outlined,
        'rental_started' => Icons.bolt_outlined,
        'rental_completed' => Icons.verified_outlined,
        'new_request' => Icons.notifications_active_outlined,
        'rental_status' => Icons.receipt_long_outlined,
        _ => Icons.info_outline,
      };

  Color _iconBg(String type, ColorScheme cs) => switch (type) {
        'request_accepted' || 'rental_completed' =>
          Colors.green.withValues(alpha: 0.12),
        'request_rejected' => cs.errorContainer,
        'rental_started' => cs.primaryContainer,
        'new_request' => cs.secondaryContainer,
        _ => cs.surfaceContainerHighest,
      };

  Color _iconColor(String type, ColorScheme cs) => switch (type) {
        'request_accepted' || 'rental_completed' => Colors.green.shade700,
        'request_rejected' => cs.error,
        'rental_started' => cs.primary,
        'new_request' => cs.onSecondaryContainer,
        _ => cs.onSurfaceVariant,
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Row {
  const _Row.header(String label)
      : isHeader = true,
        label = label,
        item = null;
  const _Row.item(Map<String, dynamic> item)
      : isHeader = false,
        label = null,
        item = item;

  final bool isHeader;
  final String? label;
  final Map<String, dynamic>? item;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
