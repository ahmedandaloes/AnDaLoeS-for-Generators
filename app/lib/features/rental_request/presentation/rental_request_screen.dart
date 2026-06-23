import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import 'payment_confirmation_screen.dart';

final _generatorForRequestProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, price_per_week, price_per_month, city, governorate, company_id')
      .eq('id', id)
      .single();
  return data;
});

final _requestBookedRangesProvider =
    FutureProvider.autoDispose.family<List<DateTimeRange>, String>(
        (ref, generatorId) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final data = await supabase
      .from('rental_requests')
      .select('start_date, end_date')
      .eq('generator_id', generatorId)
      .inFilter('status', ['accepted', 'active'])
      .gte('end_date', today)
      .order('start_date');
  return (data as List).map((r) {
    final start = DateTime.parse(r['start_date'].toString());
    final end = DateTime.parse(r['end_date'].toString());
    return DateTimeRange(start: start, end: end);
  }).toList();
});

/// Greedy best-price calculation.
/// 1 "day" in the rental = 8 operating hours (as per business rule).
double _bestPrice({
  required int days,
  required double perDay,
  double? perWeek,
  double? perMonth,
}) {
  double best = days * perDay;
  for (int m = (perMonth != null ? days ~/ 30 : 0); m >= 0; m--) {
    final afterMonths = days - m * 30;
    double baseCost = m * (perMonth ?? 0);
    for (int w = (perWeek != null ? afterMonths ~/ 7 : 0); w >= 0; w--) {
      final rem = afterMonths - w * 7;
      final c = baseCost + w * (perWeek ?? 0) + rem * perDay;
      if (c < best) best = c;
    }
    if (perMonth == null) break;
  }
  return best;
}


class RentalRequestScreen extends ConsumerStatefulWidget {
  const RentalRequestScreen({super.key, required this.generatorId});
  final String generatorId;

  @override
  ConsumerState<RentalRequestScreen> createState() =>
      _RentalRequestScreenState();
}

class _RentalRequestScreenState extends ConsumerState<RentalRequestScreen> {
  DateTimeRange? _range;
  final _noteController = TextEditingController();
  int _conflictCount = 0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _range = picked);
      _checkConflicts(picked);
    }
  }

  Future<void> _checkConflicts(DateTimeRange range) async {
    final start = range.start.toIso8601String().substring(0, 10);
    final end = range.end.toIso8601String().substring(0, 10);
    try {
      final data = await supabase
          .from('rental_requests')
          .select('id')
          .eq('generator_id', widget.generatorId)
          .inFilter('status', ['accepted', 'active'])
          .lte('start_date', end)
          .gte('end_date', start);
      if (mounted) setState(() => _conflictCount = (data as List).length);
    } catch (_) {
      // Non-blocking — don't surface to user
    }
  }

  void _reviewAndConfirm(Map<String, dynamic> gen) {
    if (_range == null) {
      _snack('Please select rental dates');
      return;
    }
    final days = _range!.end.difference(_range!.start).inDays;
    if (days < 1) {
      _snack('Rental must be at least 1 day');
      return;
    }

    final perDay = (_toDouble(gen['price_per_day']) ?? 0.0);
    final perWeek = _toDouble(gen['price_per_week']);
    final perMonth = _toDouble(gen['price_per_month']);
    final total = _bestPrice(
        days: days, perDay: perDay, perWeek: perWeek, perMonth: perMonth);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentConfirmationScreen(
        generator: gen,
        startDate: _range!.start,
        endDate: _range!.end,
        days: days,
        totalPrice: total,
        note: _noteController.text.trim(),
      ),
    ));
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  @override
  Widget build(BuildContext context) {
    final genAsync = ref.watch(_generatorForRequestProvider(widget.generatorId));
    final bookedAsync =
        ref.watch(_requestBookedRangesProvider(widget.generatorId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rent Generator')),
      body: genAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (gen) {
          final days = _range == null
              ? 0
              : _range!.end.difference(_range!.start).inDays;
          final perDay = _toDouble(gen['price_per_day']) ?? 0.0;
          final perWeek = _toDouble(gen['price_per_week']);
          final perMonth = _toDouble(gen['price_per_month']);
          final total = days > 0
              ? _bestPrice(
                  days: days,
                  perDay: perDay,
                  perWeek: perWeek,
                  perMonth: perMonth)
              : 0.0;
          final bookedRanges = bookedAsync.valueOrNull ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Generator summary
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(Icons.bolt, color: cs.primary, size: 24),
                    ),
                    title: Text(gen['title']?.toString() ?? 'Generator',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${gen['capacity_kva']} KVA • ${[gen['city'], gen['governorate']].where((v) => v != null).join(', ')}'),
                  ),
                ),
                const SizedBox(height: 16),

                // Booked dates warning
                if (bookedRanges.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cs.error.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.event_busy_outlined,
                              size: 15, color: cs.error),
                          const SizedBox(width: 6),
                          Text(
                            'Already booked — avoid these dates',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.error),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ...bookedRanges.map((r) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Icon(Icons.remove,
                                    size: 12,
                                    color:
                                        cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text(
                                  '${_fmt(r.start)}  →  ${_fmt(r.end)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface),
                                ),
                              ]),
                            )),
                      ],
                    ),
                  ),
                ],

                // Date picker
                _SectionLabel('Rental dates'),
                GestureDetector(
                  onTap: _pickDates,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _range == null
                          ? cs.surfaceContainerLowest
                          : cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _range == null
                            ? cs.outlineVariant.withValues(alpha: 0.4)
                            : cs.primary,
                        width: _range == null ? 1 : 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            color: _range == null
                                ? cs.onSurfaceVariant
                                : cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _range == null
                              ? Text('Select start & end date',
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 15))
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_fmt(_range!.start)}  →  ${_fmt(_range!.end)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '$days day${days == 1 ? '' : 's'}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                        ),
                        Icon(Icons.chevron_right,
                            color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Conflict warning
                if (_conflictCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: cs.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'These dates overlap with $_conflictCount already-accepted booking${_conflictCount > 1 ? 's' : ''}. The owner may reject your request.',
                          style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),

                // Animated date summary + price card
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.25),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: (_range != null && days > 0)
                      ? _DateSummaryCard(
                          key: ValueKey(_range),
                          start: _range!.start,
                          end: _range!.end,
                          days: days,
                          total: total,
                          cs: cs,
                        )
                      : const SizedBox.shrink(),
                ),
                if (_range != null && days > 0) const SizedBox(height: 16),

                // Notes
                _SectionLabel('Note to owner (optional)'),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Delivery address, special requirements…',
                  ),
                ),
                const SizedBox(height: 24),

                // Review & confirm
                FilledButton.icon(
                  onPressed: _range == null
                      ? null
                      : () => _reviewAndConfirm(gen),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Review & confirm'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll choose payment method on the next screen.',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DateSummaryCard extends StatefulWidget {
  const _DateSummaryCard({
    super.key,
    required this.start,
    required this.end,
    required this.days,
    required this.total,
    required this.cs,
  });
  final DateTime start;
  final DateTime end;
  final int days;
  final double total;
  final ColorScheme cs;

  @override
  State<_DateSummaryCard> createState() => _DateSummaryCardState();
}

class _DateSummaryCardState extends State<_DateSummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.elasticOut),
    );
    _pulse.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.7),
              cs.secondaryContainer.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.check_circle_rounded,
                  size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('Dates confirmed',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.days} day${widget.days == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _DateChip(
                  label: 'From', date: _fmt(widget.start), cs: cs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(
                      color: cs.primary.withValues(alpha: 0.3)),
                ),
              ),
              _DateChip(
                  label: 'To', date: _fmt(widget.end), cs: cs),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estimated total',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                Text(
                  'EGP ${widget.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Best rate applied automatically',
                style: TextStyle(
                    fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip(
      {required this.label, required this.date, required this.cs});
  final String label;
  final String date;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(date,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
      ],
    );
  }
}
