import 'package:flutter/material.dart';

String fuelLabel(String fuel) => switch (fuel) {
      'diesel' => 'Diesel',
      'petrol' => 'Petrol',
      'gas' => 'Gas',
      'natural_gas' => 'Natural Gas',
      'solar' => 'Solar',
      _ => fuel,
    };

class FuelChip extends StatelessWidget {
  const FuelChip({super.key, required this.fuel});
  final String fuel;

  static const _fuelColors = {
    'diesel': Color(0xFF6B4F1E),
    'petrol': Color(0xFF1565C0),
    'gas': Color(0xFF2E7D32),
    'natural_gas': Color(0xFF00838F),
    'solar': Color(0xFFF57F17),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _fuelColors[fuel] ?? cs.onSurfaceVariant;
    final icon = fuel == 'solar'
        ? Icons.wb_sunny_outlined
        : fuel == 'gas' || fuel == 'natural_gas'
            ? Icons.local_fire_department_outlined
            : Icons.local_gas_station_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            fuelLabel(fuel),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
