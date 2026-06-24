import '../entities/report.dart';

abstract interface class IReportRepository {
  Future<void> submitReport({
    required String reporterId,
    required String entityType,
    required String entityId,
    required String reason,
    String? details,
    String? rentalRequestId,
  });
  Future<List<Report>> fetchByReporter(String reporterId);
}
