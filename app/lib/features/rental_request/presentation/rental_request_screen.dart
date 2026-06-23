import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';

final _generatorForRequestProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, price_per_week, price_per_month, city, governorate, company_id')
      .eq('id', id)
      .single();
  return data;
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

String _rateBasis(int days) {
  if (days >= 30) return 'month';
  if (days >= 7) return 'week';
  return 'day';
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
  bool _submitting = false;

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
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit(Map<String, dynamic> gen) async {
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

    setState(() => _submitting = true);
    try {
      await supabase.from('rental_requests').insert({
        'customer_id': supabase.auth.currentUser!.id,
        'generator_id': gen['id'],
        'company_id': gen['company_id'],
        'start_date': _range!.start.toIso8601String().substring(0, 10),
        'end_date': _range!.end.toIso8601String().substring(0, 10),
        'total_days': days,
        'price_total': total,
        'rate_basis': _rateBasis(days),
        'payment_method': 'cash',
        'status': 'pending',
        if (_noteController.text.trim().isNotEmpty)
          'note': _noteController.text.trim(),
      });
      if (mounted) {
        _snack('Request sent!');
        context.go('/my-rentals');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                const SizedBox(height: 16),

                // Price breakdown
                if (_range != null && days > 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('Price estimate',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurfaceVariant,
                                    letterSpacing: 0.5)),
                            const Spacer(),
                            Text('Best rate applied',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Text('$days day${days == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 15)),
                            const Spacer(),
                            Text(
                              'EGP ${total.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            'Cash on delivery — you pay the owner directly.',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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

                // Submit
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(gen),
                  child: _submitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: cs.onPrimary),
                        )
                      : const Text('Send rental request'),
                ),
                const SizedBox(height: 8),
                Text(
                  'The owner will accept or reject your request.',
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
