import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../features/ratings/presentation/rate_rental_screen.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final _myCompanyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('companies')
      .select()
      .eq('owner_user_id', uid)
      .maybeSingle();
  return data;
});

final _ownerRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
      .eq('company_id', companyId)
      .inFilter('status', ['pending', 'accepted', 'active'])
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

final _ownerHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
      .eq('company_id', companyId)
      .inFilter('status', ['completed', 'rejected', 'cancelled'])
      .order('updated_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

// Rental IDs the owner (current user) has already submitted a rating for.
final _ownerRatedRentalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('ratings')
      .select('rental_request_id')
      .eq('rater_id', uid);
  return {for (final r in (data as List)) r['rental_request_id'].toString()};
});

final _ownerGeneratorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, city, status')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

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
            ref.invalidate(_ownerRequestsProvider(companyId));
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
    final companyAsync = ref.watch(_myCompanyProvider);
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
              onPressed: () => context.push('/company/onboard'),
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
    final requestsAsync = ref.watch(_ownerRequestsProvider(companyId));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No active requests',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(_ownerRequestsProvider(companyId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) =>
                _OwnerRequestCard(request: items[i], cs: cs, ref: ref, companyId: companyId),
          ),
        );
      },
    );
  }
}

class _OwnerRequestCard extends StatelessWidget {
  const _OwnerRequestCard(
      {required this.request, required this.cs, required this.ref, required this.companyId});
  final Map<String, dynamic> request;
  final ColorScheme cs;
  final WidgetRef ref;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final gen = request['generators'] as Map<String, dynamic>?;
    final customer = request['profiles'] as Map<String, dynamic>?;
    final status = request['status']?.toString() ?? 'pending';
    final isPending = status == 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: status, cs: cs),
                const Spacer(),
                Text('EGP ${request['price_total'] ?? '-'}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Text(gen?['title']?.toString() ?? 'Generator',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                customer?['full_name'] ??
                    customer?['phone'] ??
                    'Customer',
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${_fmt(request['start_date'])}  →  ${_fmt(request['end_date'])}  (${request['total_days']} days)',
                style:
                    TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ]),
            if (request['note'] != null &&
                request['note'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(request['note'].toString(),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () =>
                          _updateStatus(context, request['id'].toString(), 'rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(40)),
                      onPressed: () =>
                          _updateStatus(context, request['id'].toString(), 'accepted'),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'accepted') ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40)),
                onPressed: () =>
                    _updateStatus(context, request['id'].toString(), 'active'),
                child: const Text('Mark as started'),
              ),
            ],
            if (status == 'active') ...[
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40)),
                onPressed: () =>
                    _updateStatus(context, request['id'].toString(), 'completed'),
                child: const Text('Mark as completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, String requestId, String newStatus) async {
    try {
      await supabase
          .from('rental_requests')
          .update({'status': newStatus}).eq('id', requestId);
      ref.invalidate(_ownerRequestsProvider(companyId));
      // Prompt owner to rate the customer after completion
      if (newStatus == 'completed' && context.mounted) {
        final customerId = request['customer_id']?.toString() ?? '';
        final customerName =
            (request['profiles'] as Map<String, dynamic>?)?['full_name'] ??
                (request['profiles'] as Map<String, dynamic>?)?['phone'] ??
                'Customer';
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RateRentalScreen(
            rentalRequestId: requestId,
            rateeId: customerId,
            rateeName: customerName.toString(),
            isOwnerRating: true,
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _fmt(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }
}

// ── Generators tab ────────────────────────────────────────────────────────────
class _GeneratorsTab extends StatelessWidget {
  const _GeneratorsTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final generatorsAsync = ref.watch(_ownerGeneratorsProvider(companyId));

    return generatorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(_ownerGeneratorsProvider(companyId).future),
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
                      context.push('/owner/generator/add?company=$companyId'),
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
                  context.push('/owner/generator/${gen['id']}/edit'),
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
      ref.invalidate(_ownerGeneratorsProvider(companyId));
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
    final historyAsync = ref.watch(_ownerHistoryProvider(companyId));

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
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(_ownerHistoryProvider(companyId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = items[i];
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
                              .watch(_ownerRatedRentalIdsProvider)
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

// ── Status chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.cs});
  final String status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'accepted' => Colors.green,
      'active' => cs.primary,
      'completed' => Colors.green.shade700,
      'rejected' => cs.error,
      _ => cs.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
