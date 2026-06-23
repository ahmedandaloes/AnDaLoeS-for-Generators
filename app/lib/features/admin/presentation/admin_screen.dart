import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import 'admin_companies_tab.dart';
import 'admin_generators_tab.dart';
import 'admin_ops_tab.dart';
import 'admin_reports_tab.dart' show AdminReportsTab, openReportsProvider;
import 'admin_revenue_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_users_tab.dart';

final _isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return false;
  final data = await supabase
      .from('profiles')
      .select('role')
      .eq('id', uid)
      .single();
  return data['role'] == 'admin';
});

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(_isAdminProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    size: 13, color: cs.onErrorContainer),
                const SizedBox(width: 4),
                Text('Admin',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  const Text('Access denied',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Admin access required.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }
          return DefaultTabController(
            length: 7,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                  const Tab(text: 'Companies'),
                  const Tab(text: 'Generators'),
                  Tab(
                    child: Builder(builder: (ctx) {
                      final count = ref
                              .watch(openReportsProvider)
                              .valueOrNull
                              ?.length ??
                          0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Reports'),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(ctx).colorScheme.onError,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                  const Tab(text: 'Ops'),
                  const Tab(text: 'Revenue'),
                  const Tab(text: 'Stats'),
                  const Tab(text: 'Users'),
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      AdminCompaniesTab(ref: ref),
                      AdminGeneratorsTab(ref: ref),
                      AdminReportsTab(ref: ref),
                      AdminOpsTab(ref: ref),
                      AdminRevenueTab(ref: ref),
                      AdminStatsTab(ref: ref),
                      AdminUsersTab(ref: ref),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
