import 'package:flutter/material.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/admin_repository.dart';
import '../../auth/data/repositories/auth_repository.dart';
import 'admin_companies_tab.dart';
import 'admin_generators_tab.dart';
import 'admin_ops_tab.dart';
import 'admin_rentals_tab.dart';
import 'admin_reports_tab.dart' show AdminReportsTab, openReportsProvider;
import 'admin_revenue_tab.dart';
import 'admin_stats_tab.dart';
import 'admin_users_tab.dart';

final _isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return false;
  return ref.read(adminRepositoryProvider).isAdmin(uid);
});

enum _AdminSection { customers, owners, platform }

final _adminSectionProvider =
    StateProvider<_AdminSection>((_) => _AdminSection.customers);

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(_isAdminProvider);
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final section = ref.watch(_adminSectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.adminPanel),
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(l.adminAccessRequired,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ── Section switcher ──────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SegmentedButton<_AdminSection>(
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  segments: [
                    ButtonSegment(
                      value: _AdminSection.customers,
                      icon: const Icon(Icons.people_outline, size: 16),
                      label: Text(l.customerSupport),
                    ),
                    ButtonSegment(
                      value: _AdminSection.owners,
                      icon: const Icon(Icons.business_outlined, size: 16),
                      label: Text(l.ownerSupport),
                    ),
                    ButtonSegment(
                      value: _AdminSection.platform,
                      icon: const Icon(Icons.bar_chart_outlined, size: 16),
                      label: Text(l.platformSection),
                    ),
                  ],
                  selected: {section},
                  onSelectionChanged: (s) => ref
                      .read(_adminSectionProvider.notifier)
                      .state = s.first,
                ),
              ),
              // ── Section content ───────────────────────────────────
              Expanded(
                child: switch (section) {
                  _AdminSection.customers => _CustomerSupportSection(ref: ref),
                  _AdminSection.owners => _OwnerSupportSection(ref: ref),
                  _AdminSection.platform => _PlatformSection(ref: ref),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Customer Support: Rentals, Reports, Users ─────────────────────────────────
class _CustomerSupportSection extends StatelessWidget {
  const _CustomerSupportSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final openCount =
        ref.watch(openReportsProvider).valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.tabRentals),
              Tab(
                child: Builder(builder: (ctx) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.tabReports),
                      if (openCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$openCount',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(ctx).colorScheme.onError,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),
              Tab(text: l.tabUsers),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminRentalsTab(ref: ref),
                AdminReportsTab(ref: ref),
                AdminUsersTab(ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner Support: Companies, Generators, Ops ─────────────────────────────────
class _OwnerSupportSection extends StatelessWidget {
  const _OwnerSupportSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.tabCompanies),
              Tab(text: l.tabGenerators),
              Tab(text: l.tabOps),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminCompaniesTab(ref: ref),
                AdminGeneratorsTab(ref: ref),
                AdminOpsTab(ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Platform: Revenue, Stats ──────────────────────────────────────────────────
class _PlatformSection extends StatelessWidget {
  const _PlatformSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l.tabRevenue),
              Tab(text: l.tabStats),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminRevenueTab(ref: ref),
                AdminStatsTab(ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
