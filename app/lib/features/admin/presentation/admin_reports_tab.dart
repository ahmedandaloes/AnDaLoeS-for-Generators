import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/utils/db_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/admin_repository.dart';

final openReportsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchOpenReportsAdmin();
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
                Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                const SizedBox(height: 12),
                Text(l.noOpenReports, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text(l.allClear, style: TextStyle(color: cs.onSurfaceVariant)),
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
              final status = r['status'] as String? ?? 'open';
              final isUnderReview = status == 'under_review';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
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
                        const SizedBox(width: 6),
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
                        if (isUnderReview) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('REVIEWING',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange.shade700)),
                          ),
                        ],
                      ]),
                      if (r['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(r['description'],
                            style: const TextStyle(fontSize: 13)),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_fmtDate(r['created_at']),
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        if (r['rental_request_id'] != null) ...[
                          Icon(Icons.receipt_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('Rental linked',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 8),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (!isUnderReview)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => _markUnderReview(r['id'].toString()),
                            child: const Text('Review'),
                          ),
                        const Spacer(),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () =>
                              _showResolutionDialog(ctx, r['id'].toString(),
                                  dismiss: true),
                          child: Text(l.dismiss,
                              style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () =>
                              _showResolutionDialog(ctx, r['id'].toString(),
                                  dismiss: false),
                          child: Text(l.resolve,
                              style: const TextStyle(fontSize: 11)),
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

  Future<void> _markUnderReview(String id) async {
    try {
      await ref.read(adminRepositoryProvider).setReportStatus(id, 'under_review');
      ref.invalidate(openReportsProvider);
    } catch (_) {}
  }

  Future<void> _showResolutionDialog(
      BuildContext context, String id, {required bool dismiss}) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dismiss ? 'Dismiss report' : 'Resolve report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dismiss
                  ? 'The reporter will be notified that the report was dismissed.'
                  : 'The reporter will be notified that the report was resolved.',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Resolution note (optional)',
                hintText: 'Describe the outcome or action taken…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: dismiss
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(dismiss ? 'Dismiss' : 'Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final update = <String, dynamic>{
        'status': dismiss ? 'dismissed' : 'resolved',
        if (noteCtrl.text.trim().isNotEmpty)
          'resolution_note': noteCtrl.text.trim(),
      };
      await ref.read(adminRepositoryProvider).resolveReportAdmin(id, update);
      ref.invalidate(openReportsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyDbError(e))));
      }
    }
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
