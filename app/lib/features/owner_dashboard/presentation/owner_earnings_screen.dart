import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/owner_providers.dart' show ownerRepositoryProvider;

final _earningsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchEarnings(companyId);
});

class OwnerEarningsScreen extends ConsumerStatefulWidget {
  const OwnerEarningsScreen({super.key, required this.companyId});
  final String companyId;

  @override
  ConsumerState<OwnerEarningsScreen> createState() =>
      _OwnerEarningsScreenState();
}

class _OwnerEarningsScreenState extends ConsumerState<OwnerEarningsScreen> {
  String? _selectedMonth; // null = all time

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final earningsAsync = ref.watch(_earningsProvider(widget.companyId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.earnings)),
      body: earningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (data) {
          final allRentals =
              (data['rentals'] as List).cast<Map<String, dynamic>>();
          final commissionMap =
              data['commission_map'] as Map<String, dynamic>;
          final commissionOwed =
              (data['commission_owed'] as num?)?.toDouble() ?? 0;
          final monthlyNet = data['monthly_net'] as Map<String, double>;
          final months = monthlyNet.keys.toList();

          // Filter rentals by selected month
          final rentals = _selectedMonth == null
              ? allRentals
              : allRentals.where((r) {
                  final raw = r['start_date']?.toString() ?? '';
                  return raw.length >= 7 &&
                      raw.substring(0, 7) == _selectedMonth;
                }).toList();

          // Recompute totals for selected period
          final totalRevenue = rentals.fold<double>(
              0,
              (s, r) =>
                  s +
                  (double.tryParse(r['price_total']?.toString() ?? '0') ??
                      0));
          final totalCommissions = rentals.fold<double>(0, (s, r) {
            final c = commissionMap[r['id'].toString()];
            return s +
                (double.tryParse(
                        c?['commission_amount']?.toString() ?? '0') ??
                    0);
          });
          final netPayout = totalRevenue - totalCommissions;

          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(_earningsProvider(widget.companyId).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Month selector chips
                if (months.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _MonthChip(
                          label: l.allTime,
                          selected: _selectedMonth == null,
                          onTap: () =>
                              setState(() => _selectedMonth = null),
                          cs: cs,
                        ),
                        const SizedBox(width: 6),
                        ...months.reversed.map((m) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: _MonthChip(
                                label: _fmtMonth(m),
                                selected: _selectedMonth == m,
                                onTap: () =>
                                    setState(() => _selectedMonth = m),
                                cs: cs,
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: l.grossRevenue,
                        value: 'EGP ${totalRevenue.toStringAsFixed(0)}',
                        icon: Icons.attach_money,
                        cs: cs,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: l.platformFee,
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
                  label: l.netPayoutYours,
                  value: 'EGP ${netPayout.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_outlined,
                  cs: cs,
                  color: Colors.green.shade700,
                  large: true,
                ),
                if (commissionOwed > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.platformFeesOwed,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text('EGP ${commissionOwed.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.orange.shade900)),
                          ],
                        ),
                      ),
                      Text(l.toSettle,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ],
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
                      Text(l.completedRentalsCount(rentals.length),
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
                          Text(l.noCompletedRentals,
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

class _MonthlyChart extends StatefulWidget {
  const _MonthlyChart({required this.monthlyNet, required this.cs});
  final Map<String, double> monthlyNet;
  final ColorScheme cs;

  @override
  State<_MonthlyChart> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<_MonthlyChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static const _monthLabels = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _label(String ym) {
    try {
      final parts = ym.split('-');
      final m = int.parse(parts[1]);
      return '${_monthLabels[m]}\n\'${parts[0].substring(2)}';
    } catch (_) {
      return ym;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = widget.monthlyNet;
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.values.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox.shrink();

    final values = data.values.toList();
    final keys = data.keys.toList();

    // Trend: last month vs prev
    String trendText = '';
    Color trendColor = widget.cs.onSurfaceVariant;
    if (values.length >= 2) {
      final last = values.last;
      final prev = values[values.length - 2];
      if (prev > 0) {
        final pct = ((last - prev) / prev * 100).toStringAsFixed(0);
        final up = last >= prev;
        trendText = '${up ? '▲' : '▼'} $pct% vs last month';
        trendColor = up ? Colors.green.shade600 : widget.cs.error;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: widget.cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(l.monthlyRevenue,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.cs.onSurfaceVariant)),
            const Spacer(),
            if (trendText.isNotEmpty)
              Text(trendText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trendColor)),
          ]),
          const SizedBox(height: 12),
          // Sparkline
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final progress = CurvedAnimation(
                      parent: _anim, curve: Curves.easeInOut)
                  .value;
              return GestureDetector(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final localX = details.localPosition.dx;
                  final w = box.size.width - 32;
                  final idx = (localX / w * (values.length - 1))
                      .round()
                      .clamp(0, values.length - 1);
                  setState(() => _hoverIndex = idx);
                },
                onTapUp: (_) =>
                    Future.delayed(const Duration(seconds: 2),
                        () { if (mounted) setState(() => _hoverIndex = null); }),
                child: SizedBox(
                  height: 90,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values: values,
                      progress: progress,
                      color: widget.cs.primary,
                      fillColor: widget.cs.primary.withValues(alpha: 0.12),
                      hoverIndex: _hoverIndex,
                      hoverColor: widget.cs.primary,
                    ),
                    size: const Size(double.infinity, 90),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // X-axis labels
          Row(
            children: List.generate(keys.length, (i) {
              return Expanded(
                child: Text(
                  _label(keys[i]),
                  style: TextStyle(
                      fontSize: 8,
                      color: widget.cs.onSurfaceVariant,
                      height: 1.2),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.fillColor,
    required this.hoverIndex,
    required this.hoverColor,
  });

  final List<double> values;
  final double progress;
  final Color color;
  final Color fillColor;
  final int? hoverIndex;
  final Color hoverColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<double>(0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return;

    final n = values.length;
    final xStep = size.width / (n - 1 < 1 ? 1 : n - 1);

    Offset pt(int i) {
      final x = i * xStep;
      final y = size.height - (values[i] / maxVal) * size.height * 0.85 - 4;
      return Offset(x, y);
    }

    // Build path up to progress
    final totalPoints = (progress * (n - 1)).floor() + 1;
    final partialFrac = (progress * (n - 1)) - totalPoints + 1;

    final linePath = Path();
    linePath.moveTo(pt(0).dx, pt(0).dy);
    for (int i = 1; i < totalPoints && i < n; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final cx = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    // Partial last segment
    if (totalPoints < n) {
      final p0 = pt(totalPoints - 1);
      final p1 = pt(totalPoints);
      final cx = (p0.dx + p1.dx) / 2;
      final endX = p0.dx + (p1.dx - p0.dx) * partialFrac;
      final endY = p0.dy + (p1.dy - p0.dy) * partialFrac;
      linePath.cubicTo(cx, p0.dy, cx, p1.dy, endX, endY);
    }

    // Fill
    final fillPath = Path.from(linePath)
      ..lineTo(linePath.getBounds().right, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    // Line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots on each point
    for (int i = 0; i < n; i++) {
      final visibleUpTo = progress * (n - 1);
      if (i > visibleUpTo) break;
      final p = pt(i);
      final isHover = hoverIndex == i;
      canvas.drawCircle(
        p,
        isHover ? 6 : 3.5,
        Paint()..color = color,
      );
      canvas.drawCircle(
        p,
        isHover ? 4 : 2,
        Paint()..color = Colors.white,
      );
    }

    // Hover value label
    if (hoverIndex != null && hoverIndex! < n) {
      final p = pt(hoverIndex!);
      final val = values[hoverIndex!];
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'EGP $label',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: hoverColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = (p.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(tx, p.dy - 20));
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.hoverIndex != hoverIndex;
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
    final l = AppLocalizations.of(context)!;
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
                _AmountCol(l.gross, 'EGP ${gross.toStringAsFixed(0)}',
                    cs.onSurface),
                _AmountCol(l.platformFee,
                    '− EGP ${fee.toStringAsFixed(0)}', cs.error),
                _AmountCol(l.yourShare,
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

// ── Month chip selector ───────────────────────────────────────────────────────
class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

String _fmtMonth(String ym) {
  const labels = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  try {
    final parts = ym.split('-');
    final m = int.parse(parts[1]);
    return '${labels[m]} \'${parts[0].substring(2)}';
  } catch (_) {
    return ym;
  }
}
