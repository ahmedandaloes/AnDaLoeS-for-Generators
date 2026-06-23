import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import 'admin_companies_tab.dart';
import 'admin_generators_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_stats_tab.dart';

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
            length: 4,
            child: Column(
              children: [
                const TabBar(tabs: [
                  Tab(text: 'Companies'),
                  Tab(text: 'Generators'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Stats'),
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      AdminCompaniesTab(ref: ref),
                      AdminGeneratorsTab(ref: ref),
                      AdminReportsTab(ref: ref),
                      AdminStatsTab(ref: ref),
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
