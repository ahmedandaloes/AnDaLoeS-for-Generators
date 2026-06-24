import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/supabase.dart';
import '../../generators/data/generator_repository.dart';

/// Supply liquidity: available generators per governorate (cold-start tracker).
final supplyByGovernorateProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) =>
        ref.read(generatorRepositoryProvider).countAvailableByGovernorate());

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

  Future<void> _exportCsv(
      BuildContext context, Map<String, dynamic> stats) async {
    final now = DateTime.now();
    final label =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final rows = [
      ['Metric', 'Value'],
      ['Export date', label],
      ['Users', '${stats['users']}'],
      ['Generators', '${stats['generators']}'],
      ['Total rentals', '${stats['total_rentals']}'],
      ['Pending rentals', '${stats['pending_rentals']}'],
      ['Accepted rentals', '${stats['accepted_rentals']}'],
      ['Active rentals', '${stats['active_rentals']}'],
      ['Completed rentals', '${stats['completed_rentals']}'],
      [
        'Total commission (EGP)',
        (stats['total_commission_earned'] as double).toStringAsFixed(2)
      ],
    ];

    final csv = rows.map((r) => r.join(',')).join('\n');
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/andaloes_stats_$label.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'AnDaLoeS Platform Stats — $label',
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(platformStatsProvider);
    final cs = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (stats) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _exportCsv(context, stats),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export CSV'),
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(platformStatsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
              // Conversion funnel card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conversion Funnel',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 16),
                      Builder(builder: (_) {
                        final total = (stats['total_rentals'] as int?) ?? 0;
                        final accepted = (stats['accepted_rentals'] as int?) ?? 0;
                        final active = (stats['active_rentals'] as int?) ?? 0;
                        final completed = (stats['completed_rentals'] as int?) ?? 0;
                        final pct = (int n, int d) =>
                            d == 0 ? '—' : '${(n / d * 100).round()}%';
                        final steps = [
                          ('Submitted', total, cs.primary),
                          ('Accepted', accepted + active + completed,
                              Colors.blue.shade600),
                          ('Active', active + completed,
                              Colors.teal.shade600),
                          ('Completed', completed, Colors.green.shade700),
                        ];
                        return Column(children: [
                          for (int i = 0; i < steps.length; i++) ...[
                            Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: steps[i].$3,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(steps[i].$1,
                                      style: const TextStyle(fontSize: 13))),
                              Text('${steps[i].$2}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: steps[i].$3)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 44,
                                child: Text(
                                    i == 0 ? '100%' : pct(steps[i].$2, total),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ),
                            ]),
                            if (i < steps.length - 1) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 3, top: 2, bottom: 2),
                                child: Container(
                                    width: 2,
                                    height: 12,
                                    color: cs.outlineVariant),
                              ),
                            ],
                          ],
                        ]);
                      }),
                    ],
                  ),
                ),
              ),
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
              const SizedBox(height: 16),
              // Supply liquidity by governorate (cold-start tracker)
              ref.watch(supplyByGovernorateProvider).maybeWhen(
                data: (counts) {
                  if (counts.isEmpty) return const SizedBox.shrink();
                  final entries = counts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Supply by governorate',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurfaceVariant,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(
                              'Available generators per area — seed Cairo & Alexandria first.',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          for (final e in entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(e.key,
                                        style: const TextStyle(fontSize: 13))),
                                if (e.value < 3)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text('thin',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange.shade800)),
                                  ),
                                Text('${e.value}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
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
