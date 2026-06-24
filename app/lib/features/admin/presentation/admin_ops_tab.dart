import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../rental_request/data/rental_repository.dart';

final _overdueActiveProvider = FutureProvider.autoDispose(
    (ref) => ref.read(rentalRepositoryProvider).overdueActive());
final _stalePendingProvider = FutureProvider.autoDispose(
    (ref) => ref.read(rentalRepositoryProvider).stalePending());
final _overdueAcceptedProvider = FutureProvider.autoDispose(
    (ref) => ref.read(rentalRepositoryProvider).overdueAccepted());

/// Admin operations / support dashboard: surfaces rentals that need attention
/// so problems can be handled fast.
class AdminOpsTab extends ConsumerWidget {
  const AdminOpsTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        wRef.invalidate(_overdueActiveProvider);
        wRef.invalidate(_stalePendingProvider);
        wRef.invalidate(_overdueAcceptedProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          _Section(
            title: l.opsOverdueTitle,
            subtitle: l.opsOverdueSubtitle,
            icon: Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            async: wRef.watch(_overdueActiveProvider),
            cs: cs,
          ),
          _Section(
            title: l.opsStaleTitle,
            subtitle: l.opsStaleSubtitle,
            icon: Icons.hourglass_bottom_rounded,
            color: Colors.orange.shade800,
            async: wRef.watch(_stalePendingProvider),
            cs: cs,
          ),
          _Section(
            title: l.opsNotStartedTitle,
            subtitle: l.opsNotStartedSubtitle,
            icon: Icons.event_busy_outlined,
            color: Colors.deepPurple.shade400,
            async: wRef.watch(_overdueAcceptedProvider),
            cs: cs,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.timer_off_outlined),
            label: Text(l.runExpiry),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
            onPressed: () async {
              final result = await supabase
                  .rpc('expire_stale_pending_requests');
              final count = (result as int?) ?? 0;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l.expiryResult(count)),
                  behavior: SnackBarBehavior.floating,
                ));
                wRef.invalidate(_stalePendingProvider);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.async,
    required this.cs,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final AsyncValue<List<Map<String, dynamic>>> async;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final rows = async.valueOrNull ?? const [];
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (rows.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${rows.length}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e',
                style: TextStyle(fontSize: 12, color: cs.error)),
            data: (rows) {
              if (rows.isEmpty) {
                return Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Text(l.allClearShort,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                ]);
              }
              return Column(
                  children: [for (final r in rows) _OpsRow(row: r, cs: cs)]);
            },
          ),
        ],
      ),
    );
  }
}

class _OpsRow extends StatelessWidget {
  const _OpsRow({required this.row, required this.cs});
  final Map<String, dynamic> row;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final gen = (row['generators'] as Map?)?['title']?.toString() ?? 'Generator';
    final company = (row['companies'] as Map?)?['name']?.toString() ?? '';
    final customer =
        (row['profiles'] as Map?)?['full_name']?.toString() ?? 'Customer';
    return Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gen,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('$company · $customer',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  Text(
                    '${_fmt(row['start_date'])} → ${_fmt(row['end_date'])}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text('EGP ${row['price_total'] ?? '-'}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cs.primary)),
          ]),
      ),
    );
  }

  static String _fmt(dynamic d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d.toString());
    return dt == null ? d.toString() : '${dt.day}/${dt.month}/${dt.year}';
  }
}
