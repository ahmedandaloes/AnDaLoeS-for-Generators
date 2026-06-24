import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/owner_providers.dart';

String _monthAbbr(int m) => const [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][m];

class OwnerHistoryTab extends StatefulWidget {
  const OwnerHistoryTab(
      {super.key,
      required this.companyId,
      required this.cs,
      required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  State<OwnerHistoryTab> createState() => _OwnerHistoryTabState();
}

class _OwnerHistoryTabState extends State<OwnerHistoryTab> {
  String? _selectedMonth;

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

        final allMonths = <String>[];
        for (final r in items) {
          final raw =
              r['updated_at']?.toString() ?? r['created_at']?.toString();
          if (raw == null) continue;
          try {
            final dt = DateTime.parse(raw).toLocal();
            final k = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (!allMonths.contains(k)) allMonths.add(k);
          } catch (_) {}
        }
        allMonths.sort((a, b) => b.compareTo(a));

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

        final completed = filteredItems
            .where((r) => r['status'] == 'completed')
            .toList();
        final totalEarned = completed.fold<double>(
          0,
          (s, r) =>
              s +
              (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0),
        );
        final hasEarnings = completed.isNotEmpty && totalEarned > 0;

        final genEarnings = <String, double>{};
        final genTitles = <String, String>{};
        for (final r in completed) {
          final gen = r['generators'] as Map<String, dynamic>?;
          final gid = r['generator_id']?.toString() ?? '';
          genEarnings[gid] = (genEarnings[gid] ?? 0) +
              (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0);
          if (gen != null && !genTitles.containsKey(gid)) {
            genTitles[gid] = gen['title']?.toString() ?? 'Generator';
          }
        }
        final sortedGens = genEarnings.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topGens = sortedGens.take(4).toList();

        final monthlyEarnings = <String, double>{};
        for (final r in completed) {
          final raw =
              r['updated_at']?.toString() ?? r['created_at']?.toString();
          if (raw == null) continue;
          try {
            final dt = DateTime.parse(raw).toLocal();
            final key =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            final amount =
                double.tryParse(r['price_total']?.toString() ?? '0') ?? 0;
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
                padding: EdgeInsets.fromLTRB(
                    16, showMonthChips ? 56 : 16, 16, 80),
                itemCount: filteredItems.length + extraCards,
                separatorBuilder: (_, i) =>
                    SizedBox(height: i < extraCards ? 16 : 10),
                itemBuilder: (_, i) {
                  if (hasEarnings && i == 0) {
                    return _EarningsSummaryCard(
                      totalEarned: totalEarned,
                      completed: completed,
                      topGens: topGens,
                      genTitles: genTitles,
                    );
                  }
                  if (hasMonthly && i == (hasEarnings ? 1 : 0)) {
                    return _MonthlyChart(
                      recentMonths: recentMonths,
                      monthlyEarnings: monthlyEarnings,
                      maxMonthly: maxMonthly,
                      cs: cs,
                      l: l,
                    );
                  }
                  final r = filteredItems[i - extraCards];
                  return _HistoryCard(r: r, cs: cs, l: l, ref: ref);
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
                              style: const TextStyle(fontSize: 11)),
                          selected: _selectedMonth == null,
                          onSelected: (_) =>
                              setState(() => _selectedMonth = null),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      for (final m in allMonths)
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.only(end: 8),
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
    final completed =
        rows.where((r) => r['status'] == 'completed').toList();
    final totalEarnings = completed.fold<num>(
        0, (s, r) => s + ((r['price_total'] as num?) ?? 0));
    final csv =
        StringBuffer('Generator,Customer,Start,End,Days,Total EGP\n');
    for (final r in rows) {
      final gen = (r['generators'] as Map?)?['title'] ?? '';
      final cust = (r['profiles'] as Map?)?['full_name'] ?? '';
      csv.writeln(
          '"$gen","$cust","${r['start_date'] ?? ''}","${r['end_date'] ?? ''}","${r['total_days'] ?? ''}","${r['price_total'] ?? ''}"');
    }
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
      final total =
          (r['price_total'] as num?)?.toStringAsFixed(0) ?? '0';
      stmt.writeln('$gen  |  $cust  |  EGP $total');
    }
    stmt..writeln(sep)..writeln('AnDaLoeS Generator Rental Platform');
    final csvFile =
        File('${Directory.systemTemp.path}/andaloes_earnings.csv');
    final txtFile =
        File('${Directory.systemTemp.path}/andaloes_statement.txt');
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
      text:
          '${completed.length} completed rentals · EGP ${totalEarnings.toStringAsFixed(0)} total',
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _EarningsSummaryCard extends StatelessWidget {
  const _EarningsSummaryCard({
    required this.totalEarned,
    required this.completed,
    required this.topGens,
    required this.genTitles,
  });
  final double totalEarned;
  final List<Map<String, dynamic>> completed;
  final List<MapEntry<String, double>> topGens;
  final Map<String, String> genTitles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
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
                  const Text('Total earned',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
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
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  '${completed.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
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
                              color: Colors.white70, fontSize: 11),
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
                        valueColor: const AlwaysStoppedAnimation<Color>(
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
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({
    required this.recentMonths,
    required this.monthlyEarnings,
    required this.maxMonthly,
    required this.cs,
    required this.l,
  });
  final List<String> recentMonths;
  final Map<String, double> monthlyEarnings;
  final double maxMonthly;
  final ColorScheme cs;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: cs.secondary),
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
                final frac = maxMonthly > 0 ? val / maxMonthly : 0.0;
                final parts = month.split('-');
                final label = parts.length == 2
                    ? _monthAbbr(int.tryParse(parts[1]) ?? 1)
                    : month;
                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3),
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
                            color: cs.primary.withValues(alpha: 0.7),
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
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(
      {required this.r,
      required this.cs,
      required this.l,
      required this.ref});
  final Map<String, dynamic> r;
  final ColorScheme cs;
  final AppLocalizations l;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final gen = r['generators'] as Map<String, dynamic>?;
    final customer = r['profiles'] as Map<String, dynamic>?;
    final status = r['status']?.toString() ?? '';
    final statusColor = rentalStatusColor(status, cs);
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
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                final ratedIds =
                    ref.watch(ownerRatedRentalIdsProvider).valueOrNull;
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
                          size: 14, color: Colors.amber.shade600),
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
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => context.push(
                    '/rate/$rentalId?ratee=$customerId&name=$customerName&owner=true',
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 15),
                  label: Text(l.rateCustomer),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
