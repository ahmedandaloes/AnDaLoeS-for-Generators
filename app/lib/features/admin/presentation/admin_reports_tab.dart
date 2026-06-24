import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final openReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('reports')
      .select('*')
      .inFilter('status', ['open', 'under_review']).order('created_at');
  return (data as List).cast<Map<String, dynamic>>();
});

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key, required this.ref});
  final WidgetRef ref;

  static const _reasonLabels = {
    'misrepresentation': 'Misrepresentation',
    'no_show': 'No-show',
    'damage': 'Property damage',
    'fraud': 'Fraud / scam',
    'harassment': 'Harassment',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(openReportsProvider);
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.green),
                const SizedBox(height: 12),
                Text(l.noOpenReports,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(l.allClear,
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(openReportsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final r = reports[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _reasonLabels[r['reason']] ?? r['reason'],
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onErrorContainer),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['reported_entity_type']
                                      ?.toString()
                                      .toUpperCase() ??
                                  '',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onTertiaryContainer),
                            ),
                          ),
                        ],
                      ),
                      if (r['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(r['description'],
                            style: const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_fmtDate(r['created_at']),
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _dismiss(r['id'].toString()),
                          child: Text(l.dismiss,
                              style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _resolve(r['id'].toString()),
                          child: Text(l.resolve,
                              style: TextStyle(fontSize: 11)),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _dismiss(String id) async {
    await supabase
        .from('reports')
        .update({'status': 'dismissed'}).eq('id', id);
    ref.invalidate(openReportsProvider);
  }

  Future<void> _resolve(String id) async {
    await supabase
        .from('reports')
        .update({'status': 'resolved'}).eq('id', id);
    ref.invalidate(openReportsProvider);
  }

  String _fmtDate(String? d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d;
    }
  }
}
