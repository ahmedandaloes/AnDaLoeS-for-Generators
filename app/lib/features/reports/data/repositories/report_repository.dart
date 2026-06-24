import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/i_report_repository.dart';

final reportRepositoryProvider =
    Provider<ReportRepository>((_) => ReportRepository());

class ReportRepository implements IReportRepository {
  @override
  Future<void> submitReport({
    required String reporterId,
    required String entityType,
    required String entityId,
    required String reason,
    String? details,
    String? rentalRequestId,
  }) async {
    await supabase.from('reports').insert({
      'reporter_id': reporterId,
      'entity_type': entityType,
      'entity_id': entityId,
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
      if (rentalRequestId != null) 'rental_request_id': rentalRequestId,
    });
  }

  @override
  Future<List<Report>> fetchByReporter(String reporterId) async {
    final data = await supabase
        .from('reports')
        .select()
        .eq('reporter_id', reporterId)
        .order('created_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Report.fromMap)
        .toList();
  }
}
