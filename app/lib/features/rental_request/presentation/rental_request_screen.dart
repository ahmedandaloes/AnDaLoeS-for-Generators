import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pricing.dart';
import '../../../core/widgets/press_scale.dart';
import '../../generators/data/generator_repository.dart';
import '../data/rental_repository.dart';
import 'payment_confirmation_screen.dart';

final _generatorForRequestProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, id) => ref.read(generatorRepositoryProvider).fetchById(id));

final _requestBookedRangesProvider =
    FutureProvider.autoDispose.family<List<DateTimeRange>, String>(
        (ref, generatorId) async {
  // Reuse GeneratorRepository.fetchBooked — single source for booked ranges.
  final rows =
      await ref.read(generatorRepositoryProvider).fetchBooked(generatorId);
  return rows
      .map((r) => DateTimeRange(
            start: DateTime.parse(r['start_date'].toString()),
            end: DateTime.parse(r['end_date'].toString()),
          ))
      .toList();
});

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
  final _addressController = TextEditingController();
  String _deliveryTime = 'Flexible';
  int _conflictCount = 0;

  @override
  void dispose() {
    _noteController.dispose();
    _addressController.dispose();
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
      final count = await ref
          .read(rentalRepositoryProvider)
          .overlapCount(widget.generatorId, start, end);
      if (mounted) setState(() => _conflictCount = count);
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
    final total = bestRentalPrice(
        days: days, perDay: perDay, perWeek: perWeek, perMonth: perMonth);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentConfirmationScreen(
        generator: gen,
        startDate: _range!.start,
        endDate: _range!.end,
        days: days,
        totalPrice: total,
        deliveryAddress: _addressController.text.trim(),
        deliveryTime: _deliveryTime,
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
              ? bestRentalPrice(
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
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: cs.error.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.event_busy_outlined,
                                size: 14, color: cs.error),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Unavailable periods',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cs.error),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${bookedRanges.length} booking${bookedRanges.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.error),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: bookedRanges.map((r) {
                            final overlaps = _range != null &&
                                r.start.isBefore(_range!.end
                                    .add(const Duration(days: 1))) &&
                                r.end.isAfter(_range!.start
                                    .subtract(const Duration(days: 1)));
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: overlaps
                                    ? cs.error
                                    : cs.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: cs.error
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (overlaps) ...[
                                    Icon(Icons.warning_rounded,
                                        size: 11,
                                        color: cs.onError),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '${_fmt(r.start)} → ${_fmt(r.end)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: overlaps
                                            ? cs.onError
                                            : cs.error),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                // Next available suggestion when conflict detected
                if (_conflictCount > 0 && _range != null) ...[
                  _NextAvailableBanner(
                    range: _range!,
                    bookedRanges: bookedRanges,
                    cs: cs,
                    onTap: (suggested) => setState(() => _range = suggested),
                  ),
                  const SizedBox(height: 12),
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

                // Delivery address
                _SectionLabel('Delivery address'),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Street, building, city…',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Preferred delivery time
                _SectionLabel('Preferred delivery time'),
                Wrap(
                  spacing: 8,
                  children: ['Morning', 'Afternoon', 'Evening', 'Flexible']
                      .map((t) => ChoiceChip(
                            label: Text(t, style: const TextStyle(fontSize: 13)),
                            selected: _deliveryTime == t,
                            onSelected: (_) =>
                                setState(() => _deliveryTime = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Notes
                _SectionLabel('Note to owner (optional)'),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Special requirements, access instructions…',
                  ),
                ),
                const SizedBox(height: 24),

                // Review & confirm
                PressScale(
                  onTap: _range == null ? null : () => _reviewAndConfirm(gen),
                  child: FilledButton.icon(
                    onPressed: _range == null
                        ? null
                        : () => _reviewAndConfirm(gen),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Review & confirm'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                  ),
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

// Shows the next available window after a conflict, with a one-tap fill button.
class _NextAvailableBanner extends StatelessWidget {
  const _NextAvailableBanner({
    required this.range,
    required this.bookedRanges,
    required this.cs,
    required this.onTap,
  });

  final DateTimeRange range;
  final List<DateTimeRange> bookedRanges;
  final ColorScheme cs;
  final ValueChanged<DateTimeRange> onTap;

  DateTimeRange? _computeNext() {
    final days = range.end.difference(range.start).inDays;
    // Start searching the day after the last overlapping booking ends
    DateTime cursor = range.start;
    for (int i = 0; i < 90; i++) {
      final candidate = DateTimeRange(
        start: cursor,
        end: cursor.add(Duration(days: days)),
      );
      final blocked = bookedRanges.any((b) =>
          b.start.isBefore(candidate.end.add(const Duration(days: 1))) &&
          b.end.isAfter(candidate.start.subtract(const Duration(days: 1))));
      if (!blocked) return candidate;
      // Advance past the blocking booking
      for (final b in bookedRanges) {
        if (b.start.isBefore(candidate.end.add(const Duration(days: 1))) &&
            b.end.isAfter(candidate.start.subtract(const Duration(days: 1)))) {
          if (b.end.isAfter(cursor)) {
            cursor = b.end.add(const Duration(days: 1));
          }
        }
      }
    }
    return null;
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final next = _computeNext();
    if (next == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(children: [
        Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next available window',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900)),
              const SizedBox(height: 2),
              Text(
                '${_fmt(next.start)} → ${_fmt(next.end)}',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.amber.shade800,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: () => onTap(next),
          child: const Text('Use this'),
        ),
      ]),
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
