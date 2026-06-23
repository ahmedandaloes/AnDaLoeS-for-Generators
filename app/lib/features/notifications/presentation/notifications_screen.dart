import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final data = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;
  final data = await supabase
      .from('notifications')
      .select('id')
      .eq('user_id', uid)
      .eq('is_read', false);
  return (data as List).length;
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
    _markAllRead();
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        size: 56, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text('No notifications yet',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Rental updates and owner alerts will appear here.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (_, i) {
                final n = items[i];
                final isRead = n['is_read'] == true;
                final type = n['type']?.toString() ?? '';
                final data = n['data'] as Map<String, dynamic>? ?? {};

                return InkWell(
                  onTap: () => _onNotificationTap(context, type, data),
                  child: Container(
                    color: isRead
                        ? null
                        : cs.primaryContainer.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _iconBg(type, cs),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconFor(type),
                            size: 20,
                            color: _iconColor(type, cs),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Content
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
                                _timeAgo(
                                    DateTime.tryParse(
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
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(
      BuildContext context, String type, Map<String, dynamic> data) {
    switch (type) {
      case 'rental_status':
        context.push('/my-rentals');
      case 'new_request':
        context.push('/owner-dashboard');
      default:
        break;
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'rental_status' => Icons.receipt_long_outlined,
        'new_request' => Icons.notifications_active_outlined,
        _ => Icons.info_outline,
      };

  Color _iconBg(String type, ColorScheme cs) => switch (type) {
        'rental_status' => cs.secondaryContainer,
        'new_request' => cs.primaryContainer,
        _ => cs.surfaceContainerHighest,
      };

  Color _iconColor(String type, ColorScheme cs) => switch (type) {
        'rental_status' => cs.onSecondaryContainer,
        'new_request' => cs.onPrimaryContainer,
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
