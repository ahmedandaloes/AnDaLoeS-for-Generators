import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../generators/presentation/providers/detail_providers.dart'
    show avgResponseTimeProvider;
import '../../providers/owner_providers.dart';

class OwnerDashboardStats extends StatelessWidget {
  const OwnerDashboardStats(
      {super.key,
      required this.companyId,
      required this.cs,
      required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(ownerRequestsProvider(companyId));
    final historyAsync = ref.watch(ownerHistoryProvider(companyId));
    final pending =
        requestsAsync.valueOrNull?.where((r) => r['status'] == 'pending').length ?? 0;
    final accepted =
        requestsAsync.valueOrNull?.where((r) => r['status'] == 'accepted').length ?? 0;
    final active =
        requestsAsync.valueOrNull?.where((r) => r['status'] == 'active').length ?? 0;
    final completed =
        historyAsync.valueOrNull?.where((r) => r['status'] == 'completed').length ?? 0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    num todayEarnings = 0;
    for (final r in historyAsync.valueOrNull ?? []) {
      if (r['status'] == 'completed') {
        final updated = r['updated_at']?.toString() ?? '';
        if (updated.startsWith(todayStr)) {
          todayEarnings += (r['price_total'] as num?) ?? 0;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.today_rounded, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's earnings",
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    todayEarnings > 0
                        ? 'EGP ${todayEarnings.toStringAsFixed(0)}'
                        : 'No completions yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: todayEarnings > 0
                            ? cs.primary
                            : cs.onSurfaceVariant),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l.activeCount(accepted + active),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                  Text(l.totalDoneCount(completed),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OwnerStatChip(
                label: 'Pending',
                value: '$pending',
                color: Colors.orange,
                icon: Icons.hourglass_empty_rounded,
                cs: cs),
            const SizedBox(width: 8),
            OwnerStatChip(
                label: 'Accepted',
                value: '$accepted',
                color: cs.secondary,
                icon: Icons.check_rounded,
                cs: cs),
            const SizedBox(width: 8),
            OwnerStatChip(
                label: 'Active',
                value: '$active',
                color: cs.primary,
                icon: Icons.bolt,
                cs: cs),
          ]),
          const SizedBox(height: 8),
          OwnerResponseTimeChip(companyId: companyId, cs: cs, ref: ref),
        ],
      ),
    );
  }
}

class OwnerResponseTimeChip extends StatelessWidget {
  const OwnerResponseTimeChip(
      {super.key,
      required this.companyId,
      required this.cs,
      required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  static const _targetMinutes = 120;

  @override
  Widget build(BuildContext context) {
    final avgAsync = ref.watch(avgResponseTimeProvider(companyId));
    return avgAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (avgMin) {
        if (avgMin == null) return const SizedBox.shrink();
        final hrs = avgMin ~/ 60;
        final mins = avgMin % 60;
        final label = hrs > 0 ? '~${hrs}h ${mins}m avg response' : '~${mins}m avg response';
        final onTarget = avgMin <= _targetMinutes;
        final color = onTarget ? Colors.green : cs.error;
        final icon = onTarget ? Icons.timer_outlined : Icons.timer_off_outlined;
        final goal = onTarget ? '✓ Under 2hr goal' : '⚠ Over 2hr goal';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 6),
            Text('· $goal',
                style: TextStyle(
                    fontSize: 11, color: color.withValues(alpha: 0.8))),
          ]),
        );
      },
    );
  }
}

class OwnerStatChip extends StatelessWidget {
  const OwnerStatChip(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.icon,
      required this.cs});
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
      ),
    );
  }
}
