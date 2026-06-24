import 'dart:io';

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase.dart';
import '../../../core/utils/db_error.dart';
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
              final l = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l.newRequestReceived),
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
    final l = AppLocalizations.of(context)!;
    final companyAsync = ref.watch(myCompanyProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.ownerDashboard),
        actions: [
          // Pending requests count badge in AppBar
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
    final l = AppLocalizations.of(context)!;
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
            Text(l.listYourGenerators,
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
              child: Text(l.registerYourCompany),
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
    final l = AppLocalizations.of(context)!;
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
                      Text(l.earnings,
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
            tabs: [
              Tab(text: l.tabRequests),
              Tab(text: l.tabGenerators),
              Tab(text: l.tabHistory),
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
    final l = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(ownerRequestsProvider(companyId));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
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
                        Text(l.noRequestsYet,
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
                          label: Text(l.addAGenerator),
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
        final pendingItems =
            items.where((r) => r['status']?.toString() == 'pending').toList();
        final hasMultiplePending = pendingItems.length >= 2;

        return Stack(
          children: [
            RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerRequestsProvider(companyId).future),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, hasMultiplePending ? 68 : 16, 16, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final req = items[i];
              final reqId = req['id']?.toString() ?? '';
              final isPending = req['status']?.toString() == 'pending';

              if (!isPending) {
                return OwnerRequestCard(
                    request: req, ref: ref, companyId: companyId);
              }

              return Dismissible(
                key: ValueKey('owner_req_$reqId'),
                direction: DismissDirection.horizontal,
                confirmDismiss: (dir) async {
                  if (dir == DismissDirection.startToEnd) {
                    // Swipe right → accept
                    try {
                      await supabase
                          .from('rental_requests')
                          .update({'status': 'accepted'}).eq('id', reqId);
                      ref.invalidate(ownerRequestsProvider(companyId));
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(friendlyDbError(e,
                              fallback: 'Could not accept the request.'))),
                        );
                      }
                    }
                    return false;
                  } else {
                    // Swipe left → reject (with confirmation)
                    final confirmed = await showDialog<bool>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: Text(l.rejectRequestQ),
                        content: const Text(
                            'The customer will be notified that their request was rejected.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l.cancel)),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: cs.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l.reject),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await supabase
                          .from('rental_requests')
                          .update({'status': 'rejected'}).eq('id', reqId);
                      ref.invalidate(ownerRequestsProvider(companyId));
                    }
                    return false;
                  }
                },
                // Left side (swipe right = accept)
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsetsDirectional.only(start: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_rounded, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(l.accept,
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                // Right side (swipe left = reject)
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsetsDirectional.only(end: 20),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                    Icon(Icons.close_rounded, color: cs.error),
                    const SizedBox(width: 6),
                    Text(l.reject,
                        style: TextStyle(
                            color: cs.error, fontWeight: FontWeight.w700)),
                  ]),
                ),
                child: OwnerRequestCard(
                    request: req, ref: ref, companyId: companyId),
              );
            },
          ),
        ),
            if (hasMultiplePending)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: cs.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () =>
                        _acceptAll(context, pendingItems, companyId),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                        'Accept all ${pendingItems.length} pending requests'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _acceptAll(BuildContext context,
      List<Map<String, dynamic>> pending, String companyId) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.acceptAllQ),
        content: Text(
            'Accept all ${pending.length} pending requests at once?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.acceptAll)),
        ],
      ),
    );
    if (confirmed != true) return;
    // Accept one-by-one so non-conflicting requests still succeed; any that
    // overlap an already-accepted rental (DB exclusion constraint) are skipped.
    var accepted = 0;
    var skipped = 0;
    for (final r in pending) {
      try {
        await supabase
            .from('rental_requests')
            .update({'status': 'accepted'}).eq('id', r['id'].toString());
        accepted++;
      } catch (_) {
        skipped++;
      }
    }
    ref.invalidate(ownerRequestsProvider(companyId));
    if (context.mounted) {
      final msg = skipped == 0
          ? 'Accepted $accepted request${accepted == 1 ? '' : 's'}.'
          : 'Accepted $accepted; skipped $skipped with date conflicts.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

// _OwnerRequestCard moved to widgets/request_card.dart
// ── Generators tab ────────────────────────────────────────────────────────────
enum _GenSort { status, kva, price }

class _GeneratorsTab extends StatefulWidget {
  const _GeneratorsTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  State<_GeneratorsTab> createState() => _GeneratorsTabState();
}

class _GeneratorsTabState extends State<_GeneratorsTab> {
  _GenSort _sort = _GenSort.status;

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> items) {
    final copy = List<Map<String, dynamic>>.from(items);
    switch (_sort) {
      case _GenSort.status:
        const order = ['available', 'pending', 'unavailable'];
        copy.sort((a, b) {
          final ai = order.indexOf(a['status']?.toString() ?? '');
          final bi = order.indexOf(b['status']?.toString() ?? '');
          return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        });
      case _GenSort.kva:
        copy.sort((a, b) => ((b['capacity_kva'] as num?) ?? 0)
            .compareTo((a['capacity_kva'] as num?) ?? 0));
      case _GenSort.price:
        copy.sort((a, b) => ((a['price_per_day'] as num?) ?? 0)
            .compareTo((b['price_per_day'] as num?) ?? 0));
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = widget.cs;
    final ref = widget.ref;
    final companyId = widget.companyId;
    final generatorsAsync = ref.watch(ownerGeneratorsProvider(companyId));

    return generatorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (items) {
        final sorted = _sorted(items);
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerGeneratorsProvider(companyId).future),
          child: Column(
            children: [
              // Sort controls
              if (items.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(l.sort,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Wrap(spacing: 6, children: [
                        for (final s in _GenSort.values)
                          ChoiceChip(
                            label: Text(switch (s) {
                              _GenSort.status => 'Status',
                              _GenSort.kva => 'KVA ↓',
                              _GenSort.price => 'Price ↑',
                            }),
                            selected: _sort == s,
                            visualDensity: VisualDensity.compact,
                            labelStyle:
                                const TextStyle(fontSize: 12),
                            onSelected: (_) =>
                                setState(() => _sort = s),
                          ),
                      ]),
                    ],
                  ),
                ),
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
                              Text(l.emptyGeneratorsTitle,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _OwnerGeneratorTile(
                          gen: sorted[i],
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
                  label: Text(l.addGenerator),
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
    final l = AppLocalizations.of(context)!;
    final isAvailable = gen['status']?.toString() == 'available';
    final countsAsync = ref.watch(activeRentalCountsProvider(companyId));
    final activeCount = countsAsync.valueOrNull?[gen['id']?.toString()] ?? 0;
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: firstPhoto != null
                  ? Image.network(
                      firstPhoto,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _GenIcon(
                          isAvailable: isAvailable, cs: cs),
                    )
                  : _GenIcon(isAvailable: isAvailable, cs: cs),
            ),
            if (activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        title: Text(gen['title']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${gen['capacity_kva']} KVA  •  EGP ${gen['price_per_day']}/day'
          '${activeCount > 0 ? '  •  $activeCount active' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: l.edit,
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

class _GenIcon extends StatelessWidget {
  const _GenIcon({required this.isAvailable, required this.cs});
  final bool isAvailable;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: isAvailable ? cs.primaryContainer : cs.surfaceContainerHighest,
      child: Icon(Icons.bolt,
          color: isAvailable ? cs.primary : cs.onSurfaceVariant, size: 22),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  String? _selectedMonth; // 'YYYY-MM' or null for all

  String get companyId => widget.companyId;
  ColorScheme get cs => widget.cs;
  WidgetRef get ref => widget.ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(ownerHistoryProvider(companyId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
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
                  Text(l.noCompletedRentals,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }
        // Build month keys for filter chips
        final allMonths = <String>[];
        for (final r in items) {
          final raw = r['updated_at']?.toString() ?? r['created_at']?.toString();
          if (raw == null) continue;
          try {
            final dt = DateTime.parse(raw).toLocal();
            final k = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (!allMonths.contains(k)) allMonths.add(k);
          } catch (_) {}
        }
        allMonths.sort((a, b) => b.compareTo(a)); // newest first

        // Filter items by selected month
        final filteredItems = _selectedMonth == null
            ? items
            : items.where((r) {
                final raw = r['updated_at']?.toString() ??
                    r['created_at']?.toString();
                if (raw == null) return false;
                try {
                  final dt = DateTime.parse(raw).toLocal();
                  final k =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
                  return k == _selectedMonth;
                } catch (_) {
                  return false;
                }
              }).toList();

        // Compute earnings summary from history items
        final completed =
            filteredItems.where((r) => r['status'] == 'completed').toList();
        final totalEarned = completed.fold<double>(
          0,
          (s, r) => s + (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0),
        );
        final hasEarnings = completed.isNotEmpty && totalEarned > 0;

        // Earnings per generator (for breakdown bars)
        final genEarnings = <String, double>{};
        final genTitles = <String, String>{};
        for (final r in completed) {
          final gen = r['generators'] as Map<String, dynamic>?;
          final gid = r['generator_id']?.toString() ?? '';
          genEarnings[gid] =
              (genEarnings[gid] ?? 0) +
              (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0);
          if (gen != null && !genTitles.containsKey(gid)) {
            genTitles[gid] = gen['title']?.toString() ?? 'Generator';
          }
        }
        final sortedGens = genEarnings.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topGens = sortedGens.take(4).toList();

        // Monthly earnings (last 6 months)
        final monthlyEarnings = <String, double>{};
        for (final r in completed) {
          final raw = r['updated_at']?.toString() ?? r['created_at']?.toString();
          if (raw == null) continue;
          try {
            final dt = DateTime.parse(raw).toLocal();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            final amount = double.tryParse(r['price_total']?.toString() ?? '0') ?? 0;
            monthlyEarnings[key] = (monthlyEarnings[key] ?? 0) + amount;
          } catch (_) {}
        }
        final sortedMonths = monthlyEarnings.keys.toList()..sort();
        final recentMonths = sortedMonths.length > 6
            ? sortedMonths.sublist(sortedMonths.length - 6)
            : sortedMonths;
        final maxMonthly = recentMonths.isEmpty
            ? 1.0
            : recentMonths
                .map((k) => monthlyEarnings[k]!)
                .reduce((a, b) => a > b ? a : b);
        final hasMonthly = recentMonths.length >= 2;

        final extraCards = (hasEarnings ? 1 : 0) + (hasMonthly ? 1 : 0);

        final showMonthChips = allMonths.length >= 2;

        return Stack(
          children: [
            RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerHistoryProvider(companyId).future),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, showMonthChips ? 56 : 16, 16, 80),
            itemCount: filteredItems.length + extraCards,
            separatorBuilder: (_, i) =>
                SizedBox(height: i < extraCards ? 16 : 10),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.payments_outlined,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.totalEarned,
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
                            Text(l.jobsDone,
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
                      if (topGens.length > 1) ...[
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        ...topGens.map((e) {
                          final frac = totalEarned > 0
                              ? (e.value / totalEarned).clamp(0.0, 1.0)
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      genTitles[e.key] ?? 'Generator',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'EGP ${e.value.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: frac,
                                    minHeight: 5,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }

              // Second extra card: monthly breakdown
              if (hasMonthly && i == 1) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.bar_chart_rounded,
                              size: 16, color: cs.secondary),
                          const SizedBox(width: 6),
                          Text(l.monthlyEarnings,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                        ]),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: recentMonths.map((month) {
                            final val = monthlyEarnings[month] ?? 0;
                            final frac =
                                maxMonthly > 0 ? val / maxMonthly : 0.0;
                            final parts = month.split('-');
                            final label = parts.length == 2
                                ? _monthAbbr(int.tryParse(parts[1]) ?? 1)
                                : month;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3),
                                child: Column(
                                  children: [
                                    Text(
                                      val >= 1000
                                          ? '${(val / 1000).toStringAsFixed(1)}k'
                                          : val.toStringAsFixed(0),
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        height: 60 * frac + 4,
                                        color: cs.primary
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(label,
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: cs.onSurfaceVariant),
                                        textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final r = filteredItems[i - extraCards];
              final gen = r['generators'] as Map<String, dynamic>?;
              final customer = r['profiles'] as Map<String, dynamic>?;
              final status = r['status']?.toString() ?? '';
              final statusColor = switch (status) {
                'completed' => Colors.green.shade700,
                'cancelled' => cs.onSurfaceVariant,
                _ => cs.error,
              };
              final statusLabel = switch (status) {
                'completed' => l.statusCompleted,
                'cancelled' => l.statusCancelled,
                _ => l.statusRejected,
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
                                Text(l.customerRated,
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
                            label: Text(l.rateCustomer),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: hasEarnings
              ? FloatingActionButton.extended(
                  heroTag: 'export_csv',
                  onPressed: () => _exportCsv(context, completed),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l.exportCsv),
                )
              : const SizedBox.shrink(),
        ),
        if (showMonthChips)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: cs.surface,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(l.tabAll,
                          style: TextStyle(fontSize: 11)),
                      selected: _selectedMonth == null,
                      onSelected: (_) =>
                          setState(() => _selectedMonth = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  for (final m in allMonths)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        label: Text(
                          () {
                            final parts = m.split('-');
                            if (parts.length != 2) return m;
                            final mn = int.tryParse(parts[1]) ?? 1;
                            return _monthAbbr(mn);
                          }(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: _selectedMonth == m,
                        onSelected: (_) =>
                            setState(() => _selectedMonth = m),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ],
        );
      },
    );
  }

  Future<void> _exportCsv(
      BuildContext context, List<Map<String, dynamic>> rows) async {
    final now = DateTime.now();
    final dateLabel = '${now.day}/${now.month}/${now.year}';
    final completed = rows.where((r) => r['status'] == 'completed').toList();
    final totalEarnings = completed.fold<num>(
        0, (s, r) => s + ((r['price_total'] as num?) ?? 0));

    // ── CSV file ──────────────────────────────────────────────────────
    final csv = StringBuffer('Generator,Customer,Start,End,Days,Total EGP\n');
    for (final r in rows) {
      final gen = (r['generators'] as Map?)?['title'] ?? '';
      final cust = (r['profiles'] as Map?)?['full_name'] ?? '';
      csv.writeln('"$gen","$cust","${r['start_date'] ?? ''}","${r['end_date'] ?? ''}","${r['total_days'] ?? ''}","${r['price_total'] ?? ''}"');
    }

    // ── Text earnings statement ────────────────────────────────────────
    final sep = '─' * 48;
    final stmt = StringBuffer()
      ..writeln('AnDaLoeS — Earnings Statement')
      ..writeln('Generated: $dateLabel')
      ..writeln(sep)
      ..writeln('COMPLETED RENTALS: ${completed.length}')
      ..writeln('TOTAL EARNINGS:    EGP ${totalEarnings.toStringAsFixed(2)}')
      ..writeln(sep);
    for (final r in completed) {
      final gen = (r['generators'] as Map?)?['title'] ?? '-';
      final cust = (r['profiles'] as Map?)?['full_name'] ?? '-';
      final total = (r['price_total'] as num?)?.toStringAsFixed(0) ?? '0';
      stmt.writeln('$gen  |  $cust  |  EGP $total');
    }
    stmt..writeln(sep)..writeln('AnDaLoeS Generator Rental Platform');

    final csvFile = File('${Directory.systemTemp.path}/andaloes_earnings.csv');
    final txtFile = File('${Directory.systemTemp.path}/andaloes_statement.txt');
    await Future.wait([
      csvFile.writeAsString(csv.toString()),
      txtFile.writeAsString(stmt.toString()),
    ]);
    await Share.shareXFiles(
      [
        XFile(csvFile.path, mimeType: 'text/csv'),
        XFile(txtFile.path, mimeType: 'text/plain'),
      ],
      subject: 'AnDaLoeS Earnings Export — $dateLabel',
      text: '${completed.length} completed rentals · EGP ${totalEarnings.toStringAsFixed(0)} total',
    );
  }
}

String _monthAbbr(int m) => const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m];

// ── Dashboard summary stats ───────────────────────────────────────────────────
class _DashboardStats extends StatelessWidget {
  const _DashboardStats(
      {required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                  Text(l.activeCount(accepted + active),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                  Text(l.totalDoneCount(completed),
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
