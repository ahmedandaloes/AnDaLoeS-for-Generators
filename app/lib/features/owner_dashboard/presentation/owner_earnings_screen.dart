import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final _earningsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, companyId) async {
  // Completed rentals for this company
  final rentals = await supabase
      .from('rental_requests')
      .select('id, price_total, start_date, end_date, generators(title)')
      .eq('company_id', companyId)
      .eq('status', 'completed')
      .order('created_at', ascending: false);

  final rentalList = (rentals as List).cast<Map<String, dynamic>>();

  // Commissions taken
  final commissions = await supabase
      .from('commissions')
      .select('rental_request_id, commission_amount, type, value, status')
      .inFilter('rental_request_id', rentalList.map((r) => r['id']).toList());

  final commissionList = (commissions as List).cast<Map<String, dynamic>>();
  final commissionMap = {
    for (final c in commissionList) c['rental_request_id'].toString(): c
  };

  final totalRevenue = rentalList.fold<double>(
      0, (s, r) => s + (double.tryParse(r['price_total']?.toString() ?? '0') ?? 0));
  final totalCommissions = commissionList.fold<double>(
      0, (s, c) => s + (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));

  // Group net revenue by month (YYYY-MM)
  final monthlyMap = <String, double>{};
  for (final r in rentalList) {
    final raw = r['start_date']?.toString() ?? '';
    if (raw.length >= 7) {
      final month = raw.substring(0, 7);
      final gross = double.tryParse(r['price_total']?.toString() ?? '0') ?? 0;
      final fee = commissionMap[r['id'].toString()] != null
          ? double.tryParse(commissionMap[r['id'].toString()]?['commission_amount']?.toString() ?? '0') ?? 0
          : 0.0;
      monthlyMap[month] = (monthlyMap[month] ?? 0) + (gross - fee);
    }
  }
  final sortedMonths = monthlyMap.keys.toList()..sort();

  return {
    'rentals': rentalList,
    'commission_map': commissionMap,
    'total_revenue': totalRevenue,
    'total_commissions': totalCommissions,
    'net_payout': totalRevenue - totalCommissions,
    'monthly_net': {for (final m in sortedMonths) m: monthlyMap[m]!},
  };
});

class OwnerEarningsScreen extends ConsumerWidget {
  const OwnerEarningsScreen({super.key, required this.companyId});
  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(_earningsProvider(companyId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: earningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final rentals =
              (data['rentals'] as List).cast<Map<String, dynamic>>();
          final commissionMap =
              data['commission_map'] as Map<String, dynamic>;
          final totalRevenue = data['total_revenue'] as double;
          final totalCommissions = data['total_commissions'] as double;
          final netPayout = data['net_payout'] as double;

          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(_earningsProvider(companyId).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Gross revenue',
                        value: 'EGP ${totalRevenue.toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                        cs: cs,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Platform fee',
                        value: 'EGP ${totalCommissions.toStringAsFixed(0)}',
                        icon: Icons.percent,
                        cs: cs,
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  label: 'Net payout (yours)',
                  value: 'EGP ${netPayout.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  cs: cs,
                  color: Colors.green.shade700,
                  large: true,
                ),
                const SizedBox(height: 12),
                // Rental count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text('${rentals.length} completed rental${rentals.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                // Monthly breakdown chart
                if ((data['monthly_net'] as Map<String, double>).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'MONTHLY NET EARNINGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MonthlyChart(
                    monthlyNet: data['monthly_net'] as Map<String, double>,
                    cs: cs,
                  ),
                ],
                const SizedBox(height: 24),
                if (rentals.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48, color: cs.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text('No completed rentals yet',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'COMPLETED RENTALS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...rentals.map((r) {
                    final commission = commissionMap[r['id'].toString()];
                    final gross =
                        double.tryParse(r['price_total']?.toString() ?? '0') ??
                            0;
                    final fee = commission != null
                        ? double.tryParse(
                                commission['commission_amount']?.toString() ??
                                    '0') ??
                            0
                        : 0.0;
                    final gen = r['generators'] as Map<String, dynamic>?;
                    return _RentalEarningsRow(
                      title: gen?['title']?.toString() ?? 'Generator',
                      startDate: r['start_date']?.toString() ?? '',
                      endDate: r['end_date']?.toString() ?? '',
                      gross: gross,
                      fee: fee,
                      net: gross - fee,
                      cs: cs,
                    );
                  }),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.monthlyNet, required this.cs});
  final Map<String, double> monthlyNet;
  final ColorScheme cs;

  String _label(String ym) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    try {
      final parts = ym.split('-');
      final m = int.parse(parts[1]);
      return '${months[m]}\n${parts[0].substring(2)}';
    } catch (_) {
      return ym;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = monthlyNet.values.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in monthlyNet.entries)
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Text(
                          '${(entry.value / 1000).toStringAsFixed(1)}k',
                          style: TextStyle(
                              fontSize: 9, color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 80 * (entry.value / maxVal),
                          decoration: BoxDecoration(
                            color: cs.primary
                                .withValues(alpha: 0.7 + 0.3 * (entry.value / maxVal)),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _label(entry.key),
                          style: TextStyle(
                              fontSize: 9, color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
    required this.color,
    this.large = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: large ? 24 : 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: large ? 20 : 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalEarningsRow extends StatelessWidget {
  const _RentalEarningsRow({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.gross,
    required this.fee,
    required this.net,
    required this.cs,
  });
  final String title;
  final String startDate;
  final String endDate;
  final double gross;
  final double fee;
  final double net;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_fmt(startDate)}  →  ${_fmt(endDate)}',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                _AmountCol('Gross', 'EGP ${gross.toStringAsFixed(0)}',
                    cs.onSurface),
                _AmountCol('Platform fee',
                    '− EGP ${fee.toStringAsFixed(0)}', cs.error),
                _AmountCol('Your share',
                    'EGP ${net.toStringAsFixed(0)}', Colors.green.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String d) {
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}

class _AmountCol extends StatelessWidget {
  const _AmountCol(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}
