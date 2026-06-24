import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../l10n/app_localizations.dart';
import 'providers/rental_providers.dart'
    show myRentalsProvider, rentalRepositoryProvider;
import 'widgets/my_rentals_widgets.dart';

String? _statusMessage(String status, AppLocalizations l) => switch (status) {
      'accepted' => l.rentalAccepted,
      'rejected' => l.rentalRejected,
      'active' => l.rentalActiveMsg,
      'completed' => l.rentalCompletedMsg,
      'cancelled' => l.rentalCancelledMsg,
      _ => null,
    };

class MyRentalsScreen extends ConsumerStatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  ConsumerState<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends ConsumerState<MyRentalsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(rentalRepositoryProvider);
    final uid = repo.currentUserId;
    if (uid == null) return;
    _channel = repo
        .myRentalsChannel(uid, (newRecord) {
          ref.invalidate(myRentalsProvider);
          final newStatus = (newRecord['status'] as String?) ?? '';
          if (!mounted) return;
          final label =
              _statusMessage(newStatus, AppLocalizations.of(context)!);
          if (label != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(label),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ));
          }
        })
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  static const _tabs = ['All', 'Active', 'Pending', 'Done'];

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> items, int tabIndex) {
    return switch (tabIndex) {
      1 => items
          .where((r) =>
              r['status'] == 'accepted' || r['status'] == 'active')
          .toList(),
      2 => items.where((r) => r['status'] == 'pending').toList(),
      3 => items
          .where((r) =>
              r['status'] == 'completed' ||
              r['status'] == 'cancelled' ||
              r['status'] == 'rejected')
          .toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rentals = ref.watch(myRentalsProvider);
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final tabLabels = [l.tabAll, l.tabActive, l.tabPending, l.tabDone];
    final all = rentals.valueOrNull ?? [];

    final counts = [
      all.length,
      all
          .where((r) =>
              r['status'] == 'accepted' || r['status'] == 'active')
          .length,
      all.where((r) => r['status'] == 'pending').length,
      all
          .where((r) =>
              r['status'] == 'completed' ||
              r['status'] == 'cancelled' ||
              r['status'] == 'rejected')
          .length,
    ];

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.myRentals),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: List.generate(
              _tabs.length,
              (i) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tabLabels[i]),
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        body: rentals.when(
          loading: () => RentalsSkeleton(cs: cs),
          error: (e, _) => AppErrorState(
            message: "Couldn't load your rentals.",
            onRetry: () => ref.invalidate(myRentalsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return RentalsEmptyState(
                  cs: cs,
                  onBrowse: () => context.go(AppRoutes.home));
            }
            return TabBarView(
              children: List.generate(_tabs.length, (tabIndex) {
                final filtered = _filter(items, tabIndex);
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myRentalsProvider.future),
                    child: ListView(children: [
                      SizedBox(
                        height: 300,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 48,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                '${tabLabels[tabIndex]} — ${l.noRentalsYet}',
                                style:
                                    TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  );
                }
                Widget? header;
                if (tabIndex == 3 && filtered.isNotEmpty) {
                  final completedOnly = filtered
                      .where((r) => r['status'] == 'completed')
                      .toList();
                  final total = completedOnly.fold<num>(
                      0,
                      (sum, r) =>
                          sum + ((r['price_total'] as num?) ?? 0));
                  if (total > 0) {
                    final avgSpend = completedOnly.isNotEmpty
                        ? (total / completedOnly.length)
                        : 0.0;
                    final totalDays = completedOnly.fold<num>(
                        0,
                        (s, r) =>
                            s + ((r['total_days'] as num?) ?? 0));
                    final avgDays = completedOnly.isNotEmpty
                        ? (totalDays / completedOnly.length)
                        : 0.0;
                    header = Column(children: [
                      Container(
                        margin:
                            const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade700,
                              Colors.green.shade500,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.payments_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(l.totalSpent,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11)),
                              Text(
                                  'EGP ${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5)),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Text(l.rentalsCompleted,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11)),
                              Text('${completedOnly.length}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ]),
                      ),
                      if (avgSpend > 0)
                        Container(
                          margin:
                              const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              MiniRentalStat(
                                  label: 'Avg spend',
                                  value:
                                      'EGP ${avgSpend.toStringAsFixed(0)}',
                                  cs: cs),
                              Container(
                                  width: 1,
                                  height: 32,
                                  color: cs.outlineVariant),
                              MiniRentalStat(
                                  label: 'Avg duration',
                                  value:
                                      '${avgDays.toStringAsFixed(1)} days',
                                  cs: cs),
                              Container(
                                  width: 1,
                                  height: 32,
                                  color: cs.outlineVariant),
                              MiniRentalStat(
                                  label: 'Total days',
                                  value: '$totalDays days',
                                  cs: cs),
                            ],
                          ),
                        ),
                    ]);
                  }
                }

                final grouped = <dynamic>[];
                String? lastMonth;
                for (final r in filtered) {
                  final raw = r['created_at']?.toString();
                  String monthKey = '';
                  String monthLabel = '';
                  if (raw != null) {
                    try {
                      final dt = DateTime.parse(raw).toLocal();
                      monthKey = '${dt.year}-${dt.month}';
                      const months = [
                        '',
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec'
                      ];
                      final now = DateTime.now();
                      monthLabel = dt.year == now.year
                          ? months[dt.month]
                          : '${months[dt.month]} ${dt.year}';
                    } catch (_) {}
                  }
                  if (monthKey.isNotEmpty && monthKey != lastMonth) {
                    grouped.add(monthLabel);
                    lastMonth = monthKey;
                  }
                  grouped.add(r);
                }
                final extraHeader = header != null ? 1 : 0;

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(myRentalsProvider.future),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, header != null ? 8 : 16, 16, 16),
                    itemCount: grouped.length + extraHeader,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      if (header != null && i == 0) return header;
                      final item = grouped[i - extraHeader];
                      if (item is String) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }
                      final rental = item as Map<String, dynamic>;
                      final status = rental['status']?.toString() ?? '';
                      final rentalId = rental['id']?.toString() ?? '';

                      final canViewDoc = status == 'accepted' ||
                          status == 'active' ||
                          status == 'completed';
                      final canCancel = status == 'pending';

                      return Dismissible(
                        key: ValueKey('rental_$rentalId'),
                        direction: canViewDoc
                            ? DismissDirection.startToEnd
                            : canCancel
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                        confirmDismiss: (dir) async {
                          if (dir == DismissDirection.startToEnd &&
                              canViewDoc) {
                            final route = status == 'completed'
                                ? '/invoice/$rentalId'
                                : '/offer/$rentalId';
                            if (ctx.mounted) ctx.push(route);
                            return false;
                          }
                          if (dir == DismissDirection.endToStart &&
                              canCancel) {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                title: Text(l.cancelRequestQ),
                                content: const Text(
                                    'This will cancel your rental request.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: Text(l.no),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: cs.error),
                                    child: Text(l.yesCancel),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && ctx.mounted) {
                              await ref
                                  .read(rentalRepositoryProvider)
                                  .cancelRentalRequest(rentalId);
                              ref.invalidate(myRentalsProvider);
                            }
                            return false;
                          }
                          return false;
                        },
                        background: canViewDoc
                            ? Container(
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsetsDirectional.only(
                                        start: 20),
                                decoration: BoxDecoration(
                                  color:
                                      cs.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(children: [
                                  Icon(
                                    status == 'completed'
                                        ? Icons.receipt_long_outlined
                                        : Icons.description_outlined,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    status == 'completed'
                                        ? l.invoice
                                        : 'Offer',
                                    style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ]),
                              )
                            : Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsetsDirectional.only(
                                        end: 20),
                                decoration: BoxDecoration(
                                  color:
                                      cs.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      Icon(Icons.cancel_outlined,
                                          color: cs.error),
                                      const SizedBox(width: 8),
                                      Text(l.cancel,
                                          style: TextStyle(
                                              color: cs.error,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ]),
                              ),
                        child: RentalCard(
                            rental: rental, cs: cs, ref: ref),
                      );
                    },
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
