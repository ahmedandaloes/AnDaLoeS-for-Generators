import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final adminUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('profiles')
      .select('id, full_name, phone, role')
      .order('role', ascending: true)
      .limit(200);
  return (data as List).cast<Map<String, dynamic>>();
});

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key, required this.ref});
  final WidgetRef ref;

  Future<void> _setRole(
      BuildContext context, String uid, String newRole) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', uid);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to $newRole')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showRoleDialog(
      BuildContext context, Map<String, dynamic> user) async {
    final current = user['role']?.toString() ?? 'customer';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user['full_name']?.toString() ?? 'User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current role: $current',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            for (final role in ['customer', 'owner', 'admin'])
              ListTile(
                dense: true,
                leading: Icon(_roleIcon(role),
                    color: _roleColor(role, Theme.of(ctx).colorScheme)),
                title: Text(role[0].toUpperCase() + role.substring(1)),
                selected: current == role,
                onTap: () {
                  Navigator.pop(ctx);
                  if (role != current) {
                    _setRole(context, user['id'].toString(), role);
                  }
                },
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) => switch (role) {
        'admin' => Icons.shield_outlined,
        'owner' => Icons.storefront_outlined,
        _ => Icons.person_outline_rounded,
      };

  Color _roleColor(String role, ColorScheme cs) => switch (role) {
        'admin' => cs.error,
        'owner' => cs.secondary,
        _ => cs.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef _ref) {
    final usersAsync = _ref.watch(adminUsersProvider);
    final cs = Theme.of(context).colorScheme;

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        // Group by role
        final byRole = <String, List<Map<String, dynamic>>>{};
        for (final u in users) {
          final r = u['role']?.toString() ?? 'customer';
          byRole.putIfAbsent(r, () => []).add(u);
        }
        final order = ['admin', 'owner', 'customer'];
        return RefreshIndicator(
          onRefresh: () => _ref.refresh(adminUsersProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Summary chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(spacing: 8, children: [
                  for (final role in order)
                    if (byRole[role] != null)
                      Chip(
                        avatar: Icon(_roleIcon(role),
                            size: 14, color: _roleColor(role, cs)),
                        label: Text(
                            '${byRole[role]!.length} ${role[0].toUpperCase()}${role.substring(1)}s',
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                ]),
              ),
              for (final role in order)
                if (byRole.containsKey(role)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '${role[0].toUpperCase()}${role.substring(1)}s (${byRole[role]!.length})',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5),
                    ),
                  ),
                  for (final user in byRole[role]!)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: _roleColor(role, cs).withValues(alpha: 0.15),
                        child: Icon(_roleIcon(role),
                            size: 16, color: _roleColor(role, cs)),
                      ),
                      title: Text(
                          user['full_name']?.toString().isNotEmpty == true
                              ? user['full_name']!.toString()
                              : '(no name)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          user['phone']?.toString() ?? user['id'].toString().substring(0, 8),
                          style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _roleColor(role, cs).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _roleColor(role, cs).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          role[0].toUpperCase() + role.substring(1),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _roleColor(role, cs)),
                        ),
                      ),
                      onTap: () => _showRoleDialog(context, user),
                    ),
                ],
            ],
          ),
        );
      },
    );
  }
}
