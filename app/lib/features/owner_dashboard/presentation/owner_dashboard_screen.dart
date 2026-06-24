import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/owner_providers.dart';
import 'widgets/owner_generators_tab.dart';
import 'widgets/owner_history_tab.dart';
import 'widgets/owner_requests_tab.dart';
import 'widgets/owner_stats_widgets.dart';
import 'widgets/thin_supply_nudge.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  RealtimeChannel? _channel;
  String? _watchedCompanyId;

  void _subscribeToRequests(String companyId) {
    if (_watchedCompanyId == companyId) return;
    _channel?.unsubscribe();
    _watchedCompanyId = companyId;
    _channel = ref
        .read(ownerRepositoryProvider)
        .ownerRequestsChannel(companyId, () {
      ref.invalidate(ownerRequestsProvider(companyId));
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.newRequestReceived),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }).subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final companyAsync = ref.watch(myCompanyProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.ownerDashboard),
        actions: [
          companyAsync.maybeWhen(
            data: (company) {
              if (company == null) return const SizedBox.shrink();
              final cid = company['id']?.toString() ?? '';
              final pending = ref
                      .watch(ownerRequestsProvider(cid))
                      .valueOrNull
                      ?.where((r) => r['status'] == 'pending')
                      .length ??
                  0;
              if (pending == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Badge(
                  label: Text('$pending'),
                  child: const Icon(Icons.pending_actions_outlined),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (company) {
          if (company == null) {
            return const _NoCompanyState();
          }
          final status =
              company['verification_status']?.toString() ?? 'pending';
          if (status != 'approved') {
            return _PendingVerification(company: company, cs: cs);
          }
          _subscribeToRequests(company['id'].toString());
          return _Dashboard(company: company, cs: cs, ref: ref);
        },
      ),
    );
  }
}

class _NoCompanyState extends StatelessWidget {
  const _NoCompanyState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppEmptyState(
      icon: Icons.business_center_rounded,
      title: l.listYourGenerators,
      subtitle:
          'Create a company profile to start listing your generators.',
      action: () => context.go(AppRoutes.companyOnboard),
      actionLabel: l.registerYourCompany,
    );
  }
}

class _PendingVerification extends StatelessWidget {
  const _PendingVerification(
      {required this.company, required this.cs});
  final Map<String, dynamic> company;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final status = company['verification_status']?.toString() ?? 'pending';
    final isRejected = status == 'rejected';

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
                color: isRejected ? cs.errorContainer : cs.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                size: 36,
                color: isRejected ? cs.error : cs.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isRejected ? 'Application rejected' : 'Under review',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              isRejected
                  ? (company['rejection_reason'] ??
                      'Your application was not approved. Please contact support.')
                  : "Your company is being reviewed by our team. You'll be notified once approved.",
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(company['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard(
      {required this.company, required this.cs, required this.ref});
  final Map<String, dynamic> company;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final companyId = company['id'].toString();
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 13, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(company['name']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => context
                      .push('/owner/earnings?company=$companyId'),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(l.earnings,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          OwnerDashboardStats(companyId: companyId, cs: cs, ref: ref),
          ThinSupplyNudge(companyId: companyId, cs: cs),
          TabBar(
            tabs: [
              Tab(text: l.tabRequests),
              Tab(text: l.tabGenerators),
              Tab(text: l.tabHistory),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                OwnerRequestsTab(companyId: companyId, cs: cs, ref: ref),
                OwnerGeneratorsTab(companyId: companyId, cs: cs, ref: ref),
                OwnerHistoryTab(companyId: companyId, cs: cs, ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
