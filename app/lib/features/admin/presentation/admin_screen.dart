import 'package:flutter/material.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminPanel),
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 12),
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
                Text(l.admin,
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
        error: (e, _) => const AppErrorState(),
        data: (isAdmin) {
          if (!isAdmin) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Text(l.accessDenied,
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(l.adminAccessRequired,
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
                  Tab(text: l.tabCompanies),
                  Tab(text: l.tabGenerators),
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
                          Text(l.tabReports),
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
                  Tab(text: l.tabOps),
                  Tab(text: l.tabRevenue),
                  Tab(text: l.tabStats),
                  Tab(text: l.tabUsers),
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
