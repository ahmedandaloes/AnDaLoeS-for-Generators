import 'package:flutter/material.dart';

class DocPartyBox extends StatelessWidget {
  const DocPartyBox({
    super.key,
    required this.label,
    required this.name,
    this.detail,
    required this.cs,
    required this.color,
  });
  final String label;
  final String name;
  final String? detail;
  final ColorScheme cs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 2),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(detail!,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class DocSectionLabel extends StatelessWidget {
  const DocSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class DocRow extends StatelessWidget {
  const DocRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
