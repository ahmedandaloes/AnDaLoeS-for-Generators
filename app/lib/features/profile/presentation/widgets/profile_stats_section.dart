import 'package:flutter/material.dart';

/// Compact stat cell used in the rental-count row.
class ProfileStatItem extends StatelessWidget {
  const ProfileStatItem({
    super.key,
    required this.value,
    required this.label,
    required this.cs,
    this.highlight = false,
  });

  final String value;
  final String label;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: highlight ? cs.primary : cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Thin vertical divider used between stats cells.
class ProfileStatDivider extends StatelessWidget {
  const ProfileStatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 1,
      ),
    );
  }
}

/// Small row used inside the sign-out confirmation dialog to show
/// a labelled value with a leading icon.
class ProfileSessionRow extends StatelessWidget {
  const ProfileSessionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: cs.onSurfaceVariant),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ]);
  }
}
