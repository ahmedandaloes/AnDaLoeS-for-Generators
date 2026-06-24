import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

/// Trust/reliability signals for a company, derived from its rental history.
typedef CompanyReliability = ({
  double acceptanceRate, // 0–1: accepted+active+completed / all decided
  double avgResponseHours, // avg time to respond to a request
  double onTimeRate, // 0–1: completed by the agreed end date
  int completed, // # completed rentals (sample size)
});

/// Shared across the company profile + generator detail (one source of truth).
final companyReliabilityProvider =
    FutureProvider.autoDispose.family<CompanyReliability, String>(
        (ref, companyId) async {
  const empty =
      (acceptanceRate: 0.0, avgResponseHours: 0.0, onTimeRate: 0.0, completed: 0);
  if (companyId.isEmpty) return empty;
  final rows = await supabase
      .from('rental_requests')
      .select('status, created_at, updated_at, end_date')
      .eq('company_id', companyId)
      .inFilter('status', ['accepted', 'rejected', 'active', 'completed']);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return empty;

  final accepted = list
      .where((r) => ['accepted', 'active', 'completed'].contains(r['status']))
      .length;
  final acceptanceRate = accepted / list.length;

  final responded = list.where((r) {
    final c = DateTime.tryParse(r['created_at']?.toString() ?? '');
    final u = DateTime.tryParse(r['updated_at']?.toString() ?? '');
    return c != null && u != null && u.isAfter(c);
  }).toList();
  final avgHours = responded.isEmpty
      ? 0.0
      : responded.fold<double>(0, (s, r) {
            final c = DateTime.parse(r['created_at'].toString());
            final u = DateTime.parse(r['updated_at'].toString());
            return s + u.difference(c).inMinutes / 60.0;
          }) /
          responded.length;

  final completedList =
      list.where((r) => r['status'] == 'completed').toList();
  var onTime = 0;
  for (final r in completedList) {
    final end = DateTime.tryParse(r['end_date']?.toString() ?? '');
    final upd = DateTime.tryParse(r['updated_at']?.toString() ?? '');
    if (end != null &&
        upd != null &&
        !upd.isAfter(end.add(const Duration(days: 1)))) {
      onTime++;
    }
  }
  final onTimeRate =
      completedList.isEmpty ? 0.0 : onTime / completedList.length;

  return (
    acceptanceRate: acceptanceRate,
    avgResponseHours: avgHours,
    onTimeRate: onTimeRate,
    completed: completedList.length,
  );
});
