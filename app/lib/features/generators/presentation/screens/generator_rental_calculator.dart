import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

// ── Rental Price Calculator ───────────────────────────────────────────────────
class GeneratorRentalCalculator extends StatefulWidget {
  const GeneratorRentalCalculator({required this.pricePerDay, required this.cs});
  final double pricePerDay;
  final ColorScheme cs;

  @override
  State<GeneratorRentalCalculator> createState() => GeneratorRentalCalculatorState();
}

class GeneratorRentalCalculatorState extends State<GeneratorRentalCalculator> {
  double _days = 3;

  @override
  Widget build(BuildContext context) {
    final total = (widget.pricePerDay * _days).round();
    final cs = widget.cs;
    final l = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calculate_outlined,
                size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(l.priceEstimate,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('${_days.toInt()} days',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              'EGP $total',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.primary,
                letterSpacing: -0.5,
              ),
            ),
          ]),
          Slider(
            value: _days,
            min: 1,
            max: 30,
            divisions: 29,
            label: '${_days.toInt()} days',
            onChanged: (v) => setState(() => _days = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 day',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              Text(
                  'EGP ${widget.pricePerDay.toStringAsFixed(0)}/day',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              Text('30 days',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
