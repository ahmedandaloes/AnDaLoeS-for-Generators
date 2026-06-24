import '../entities/admin_stats.dart';

abstract interface class IAdminRepository {
  Future<AdminStats> fetchStats();
  Future<List<Map<String, dynamic>>> fetchPendingCompanies();
  Future<void> updateCompanyStatus(String companyId, String status);
  Future<List<Map<String, dynamic>>> fetchAllGenerators();
  Future<void> updateGeneratorStatus(String generatorId, String status);
  Future<List<Map<String, dynamic>>> fetchOpenReports();
  Future<void> resolveReport(String reportId, String note, String resolvedBy);
  Future<List<Map<String, dynamic>>> fetchAllRentals({String? search});
  Future<List<Map<String, dynamic>>> fetchAllUsers();
}
