import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../chat/presentation/providers/chat_providers.dart';

// ── Chat button with unread badge ─────────────────────────────────────────────
class RentalChatButton extends StatelessWidget {
  const RentalChatButton({
    super.key,
    required this.rentalId,
    required this.label,
    required this.otherPartyName,
    required this.wRef,
    required this.context,
  });
  final String rentalId;
  final String label;
  final String otherPartyName;
  final WidgetRef wRef;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    final unread =
        wRef.watch(unreadMessagesProvider(rentalId)).valueOrNull ?? 0;
    return Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: () => context.push(
            '/chat/$rentalId?name=${Uri.encodeComponent(otherPartyName)}'),
        icon: const Icon(Icons.chat_outlined, size: 16),
        label: Text(label),
      ),
    );
  }
}

// ── Mini stat chip (used in rentals header) ───────────────────────────────────
class MiniRentalStat extends StatelessWidget {
  const MiniRentalStat(
      {super.key, required this.label, required this.value, required this.cs});
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
