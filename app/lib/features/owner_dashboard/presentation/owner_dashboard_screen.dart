import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../providers/owner_providers.dart';
import '../../generators/providers/detail_providers.dart';
import 'widgets/request_card.dart';
import '../../../core/routing/app_routes.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState
    extends ConsumerState<OwnerDashboardScreen> {
  RealtimeChannel? _channel;
  String? _watchedCompanyId;

  void _subscribeToRequests(String companyId) {
    if (_watchedCompanyId == companyId) return;
    _channel?.unsubscribe();
    _watchedCompanyId = companyId;
    _channel = supabase
        .channel('owner-requests-$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rental_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (_) {
            ref.invalidate(ownerRequestsProvider(companyId));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('New rental request received!'),
                behavior: SnackBarBehavior.floating,
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
    final companyAsync = ref.watch(myCompanyProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Owner Dashboard')),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (company) {
          if (company == null) {
            return _NoCompanyState(cs: cs);
          }
          final status = company['verification_status']?.toString() ?? 'pending';
          if (status != 'approved') {
            return _PendingVerification(company: company, cs: cs);
          }
          // Subscribe to new rental requests in real-time
          _subscribeToRequests(company['id'].toString());
          return _Dashboard(company: company, cs: cs, ref: ref);
        },
      ),
    );
  }
}

// ── No company yet ─────────────────────────────────────────────────────────────
class _NoCompanyState extends StatelessWidget {
  const _NoCompanyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.business_outlined, size: 36, color: cs.primary),
            ),
            const SizedBox(height: 20),
            const Text('List your generators',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Register your company to start listing generators and receiving rental requests.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push(AppRoutes.companyOnboard),
              child: const Text('Register your company'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending verification ────────────────────────────────────────────────────────
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
                color: isRejected
                    ? cs.errorContainer
                    : cs.tertiaryContainer,
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
                  : 'Your company is being reviewed by our team. You\'ll be notified once approved.',
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
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full dashboard ─────────────────────────────────────────────────────────────
class _Dashboard extends StatelessWidget {
  const _Dashboard(
      {required this.company, required this.cs, required this.ref});
  final Map<String, dynamic> company;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Company chip + earnings button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => context.push(
                      '/owner/earnings?company=${company['id']}'),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      const Text('Earnings',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DashboardStats(
              companyId: company['id'].toString(), cs: cs, ref: ref),
          TabBar(
            tabs: const [
              Tab(text: 'Requests'),
              Tab(text: 'Generators'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestsTab(
                    companyId: company['id'].toString(), cs: cs, ref: ref),
                _GeneratorsTab(
                    companyId: company['id'].toString(), cs: cs, ref: ref),
                _HistoryTab(
                    companyId: company['id'].toString(), cs: cs, ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  const _RequestsTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(ownerRequestsProvider(companyId));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(ownerRequestsProvider(companyId).future),
            child: ListView(children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.3),
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.5),
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer,
                            ),
                            child: Icon(Icons.inbox_outlined,
                                size: 26, color: cs.primary),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        const Text('No requests yet',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Customers will appear here once they request a generator you own.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.bolt_outlined, size: 16),
                          label: const Text('Add a generator'),
                          onPressed: () => context.push(
                              AppRoutes.addGenerator(companyId)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerRequestsProvider(companyId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) =>
                OwnerRequestCard(request: items[i], ref: ref, companyId: companyId),
          ),
        );
      },
    );
  }
}

// _OwnerRequestCard moved to widgets/request_card.dart
// ── Generators tab ────────────────────────────────────────────────────────────
class _GeneratorsTab extends StatelessWidget {
  const _GeneratorsTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final generatorsAsync = ref.watch(ownerGeneratorsProvider(companyId));

    return generatorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerGeneratorsProvider(companyId).future),
          child: Column(
            children: [
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt,
                                  size: 48, color: cs.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text('No generators yet',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _OwnerGeneratorTile(
                          gen: items[i],
                          cs: cs,
                          ref: ref,
                          companyId: companyId,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () =>
                      context.push(AppRoutes.addGenerator(companyId)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add generator'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerGeneratorTile extends StatelessWidget {
  const _OwnerGeneratorTile(
      {required this.gen, required this.cs, required this.ref, required this.companyId});
  final Map<String, dynamic> gen;
  final ColorScheme cs;
  final WidgetRef ref;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final isAvailable = gen['status']?.toString() == 'available';

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isAvailable ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.bolt,
              color: isAvailable ? cs.primary : cs.onSurfaceVariant,
              size: 22),
        ),
        title: Text(gen['title']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${gen['capacity_kva']} KVA  •  EGP ${gen['price_per_day']}/day'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () =>
                  context.push(AppRoutes.editGenerator(gen['id'].toString())),
            ),
            Switch(
              value: isAvailable,
              onChanged: (v) => _toggleStatus(context, v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, bool available) async {
    try {
      await supabase.from('generators').update(
          {'status': available ? 'available' : 'unavailable'}).eq(
          'id', gen['id'].toString());
      ref.invalidate(ownerGeneratorsProvider(companyId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── History tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(ownerHistoryProvider(companyId));

    return historyAsync.when(
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
                  Icon(Icons.history, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No completed rentals yet',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }
        // Compute earnings summary from history items
        final completed =
            items.where((r) => r['status'] == 'completed').toList();
        final totalEarned = completed.fold<double>(
          0,
          (s, r) => s + (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0),
        );
        final hasEarnings = completed.isNotEmpty && totalEarned > 0;

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerHistoryProvider(companyId).future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: items.length + (hasEarnings ? 1 : 0),
            separatorBuilder: (_, i) =>
                SizedBox(height: i == 0 && hasEarnings ? 16 : 10),
            itemBuilder: (_, i) {
              // First item is the earnings summary card
              if (hasEarnings && i == 0) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade700,
                        Colors.green.shade500,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.payments_outlined,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total earned',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                            'EGP ${totalEarned.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Jobs done',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          '${completed.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ]),
                );
              }

              final r = items[hasEarnings ? i - 1 : i];
              final gen = r['generators'] as Map<String, dynamic>?;
              final customer = r['profiles'] as Map<String, dynamic>?;
              final status = r['status']?.toString() ?? '';
              final statusColor = switch (status) {
                'completed' => Colors.green.shade700,
                'cancelled' => cs.onSurfaceVariant,
                _ => cs.error,
              };
              final statusLabel = switch (status) {
                'completed' => 'Completed',
                'cancelled' => 'Cancelled',
                _ => 'Rejected',
              };
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(statusLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor)),
                          ),
                          const Spacer(),
                          if (r['price_total'] != null)
                            Text(
                              'EGP ${r['price_total']}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        gen?['title']?.toString() ?? 'Generator',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${gen?['capacity_kva']} KVA',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      if (customer != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.person_outline,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            customer['full_name']?.toString() ??
                                customer['phone']?.toString() ??
                                'Customer',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${r['start_date'] ?? '-'}  →  ${r['end_date'] ?? '-'}',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ]),
                      if (status == 'completed') ...[
                        const SizedBox(height: 10),
                        Builder(builder: (context) {
                          final rentalId = r['id']?.toString() ?? '';
                          final ratedIds = ref
                              .watch(ownerRatedRentalIdsProvider)
                              .valueOrNull;
                          final alreadyRated =
                              ratedIds?.contains(rentalId) == true;
                          final customerId =
                              r['customer_id']?.toString() ?? '';
                          final customerName =
                              customer?['full_name']?.toString() ??
                                  customer?['phone']?.toString() ??
                                  'Customer';
                          if (alreadyRated) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber.shade600),
                                const SizedBox(width: 4),
                                Text('Customer rated',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.shade700,
                                        fontWeight: FontWeight.w500)),
                              ],
                            );
                          }
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(36),
                              textStyle:
                                  const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => context.push(
                              '/rate/$rentalId?ratee=$customerId&name=$customerName&owner=true',
                            ),
                            icon: const Icon(
                                Icons.star_outline_rounded,
                                size: 15),
                            label: const Text('Rate customer'),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Dashboard summary stats ───────────────────────────────────────────────────
class _DashboardStats extends StatelessWidget {
  const _DashboardStats(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(ownerRequestsProvider(companyId));
    final historyAsync = ref.watch(ownerHistoryProvider(companyId));
    final pending = requestsAsync.valueOrNull?.where((r) => r['status'] == 'pending').length ?? 0;
    final accepted = requestsAsync.valueOrNull?.where((r) => r['status'] == 'accepted').length ?? 0;
    final active = requestsAsync.valueOrNull?.where((r) => r['status'] == 'active').length ?? 0;
    final completed = historyAsync.valueOrNull?.where((r) => r['status'] == 'completed').length ?? 0;

    // Today's earnings: sum of price_total for rentals updated today
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    num todayEarnings = 0;
    for (final r in historyAsync.valueOrNull ?? []) {
      if (r['status'] == 'completed') {
        final updated = r['updated_at']?.toString() ?? '';
        if (updated.startsWith(todayStr)) {
          todayEarnings += (r['price_total'] as num?) ?? 0;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's earnings banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.today_rounded, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's earnings",
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    todayEarnings > 0
                        ? 'EGP ${todayEarnings.toStringAsFixed(0)}'
                        : 'No completions yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: todayEarnings > 0
                            ? cs.primary
                            : cs.onSurfaceVariant),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${accepted + active} active',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                  Text('$completed total done',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // Chips row
          Row(children: [
            _StatChip(label: 'Pending', value: '$pending', color: Colors.orange, icon: Icons.hourglass_empty_rounded, cs: cs),
            const SizedBox(width: 8),
            _StatChip(label: 'Accepted', value: '$accepted', color: cs.secondary, icon: Icons.check_rounded, cs: cs),
            const SizedBox(width: 8),
            _StatChip(label: 'Active', value: '$active', color: cs.primary, icon: Icons.bolt, cs: cs),
          ]),
          const SizedBox(height: 8),
          _ResponseTimeChip(companyId: companyId, cs: cs, ref: ref),
        ],
      ),
    );
  }
}

class _ResponseTimeChip extends StatelessWidget {
  const _ResponseTimeChip(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  static const _targetMinutes = 120; // 2-hour goal

  @override
  Widget build(BuildContext context) {
    final avgAsync = ref.watch(avgResponseTimeProvider(companyId));
    return avgAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (avgMin) {
        if (avgMin == null) return const SizedBox.shrink();
        final hrs = avgMin ~/ 60;
        final mins = avgMin % 60;
        final label = hrs > 0 ? '~${hrs}h ${mins}m avg response' : '~${mins}m avg response';
        final onTarget = avgMin <= _targetMinutes;
        final color = onTarget ? Colors.green : cs.error;
        final icon = onTarget ? Icons.timer_outlined : Icons.timer_off_outlined;
        final goal = onTarget ? '✓ Under 2hr goal' : '⚠ Over 2hr goal';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const SizedBox(width: 6),
            Text('· $goal',
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ]),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color, required this.icon, required this.cs});
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
      ),
    );
  }
}
