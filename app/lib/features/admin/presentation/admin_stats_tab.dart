import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final platformStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final users = await supabase.from('profiles').select('id');
  final generators = await supabase.from('generators').select('id');
  final rentals = await supabase.from('rental_requests').select('id, status');
  final commissions =
      await supabase.from('commissions').select('commission_amount, status');

  final rentalList = (rentals as List).cast<Map<String, dynamic>>();
  final commissionList = (commissions as List).cast<Map<String, dynamic>>();

  final completed = rentalList.where((r) => r['status'] == 'completed').length;
  final pending = rentalList.where((r) => r['status'] == 'pending').length;
  final accepted = rentalList.where((r) => r['status'] == 'accepted').length;
  final active = rentalList.where((r) => r['status'] == 'active').length;
  final totalCommissions = commissionList.fold<double>(
      0,
      (s, c) =>
          s +
          (double.tryParse(c['commission_amount']?.toString() ?? '0') ?? 0));

  return {
    'users': (users as List).length,
    'generators': (generators as List).length,
    'total_rentals': rentalList.length,
    'pending_rentals': pending,
    'accepted_rentals': accepted,
    'active_rentals': active,
    'completed_rentals': completed,
    'total_commission_earned': totalCommissions,
  };
});

class AdminStatsTab extends StatelessWidget {
  const AdminStatsTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(platformStatsProvider);
    final cs = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (stats) => RefreshIndicator(
        onRefresh: () => ref.refresh(platformStatsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text('PLATFORM OVERVIEW',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            _StatGrid(stats: stats, cs: cs),
            const SizedBox(height: 24),
            _RentalStatusChart(stats: stats, cs: cs),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commission earned',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'EGP ${(stats['total_commission_earned'] as double).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'from ${stats['completed_rentals']} completed rentals',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.cs});
  final Map<String, dynamic> stats;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Users', '${stats['users']}', Icons.people_outline, cs.primary),
      ('Generators', '${stats['generators']}', Icons.bolt, cs.secondary),
      ('Total rentals', '${stats['total_rentals']}',
          Icons.receipt_long_outlined, cs.tertiary),
      ('Completed', '${stats['completed_rentals']}',
          Icons.check_circle_outline, Colors.green.shade700),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: items
          .map((item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(item.$3,
                          size: 20,
                          color: item.$4.withValues(alpha: 0.7)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: item.$4,
                                  letterSpacing: -1)),
                          Text(item.$1,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _RentalStatusChart extends StatefulWidget {
  const _RentalStatusChart({required this.stats, required this.cs});
  final Map<String, dynamic> stats;
  final ColorScheme cs;

  @override
  State<_RentalStatusChart> createState() => _RentalStatusChartState();
}

class _RentalStatusChartState extends State<_RentalStatusChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final total = (widget.stats['total_rentals'] as int?) ?? 1;

    final bars = [
      ('Pending', (widget.stats['pending_rentals'] as int?) ?? 0,
          Colors.orange),
      ('Accepted', (widget.stats['accepted_rentals'] as int?) ?? 0,
          Colors.green),
      ('Active', (widget.stats['active_rentals'] as int?) ?? 0, cs.primary),
      ('Completed', (widget.stats['completed_rentals'] as int?) ?? 0,
          Colors.green.shade700),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rental Status Distribution',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5)),
            const SizedBox(height: 16),
            ...bars.map((bar) {
              final frac = total > 0 ? bar.$2 / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(bar.$1,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${bar.$2}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: bar.$3)),
                    ]),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (_, __) {
                        final animated = frac *
                            CurvedAnimation(
                                    parent: _anim,
                                    curve: Curves.easeOutCubic)
                                .value;
                        return Stack(children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: animated.clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: bar.$3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Text('Total: $total rentals',
                style:
                    TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
