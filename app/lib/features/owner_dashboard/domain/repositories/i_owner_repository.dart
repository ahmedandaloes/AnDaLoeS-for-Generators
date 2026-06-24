import '../entities/company.dart';

abstract interface class IOwnerRepository {
  Future<CompanyEntity?> fetchMyCompany(String uid);
  Future<List<Map<String, dynamic>>> fetchRequests(String companyId,
      {List<String>? statuses});
  Future<List<Map<String, dynamic>>> fetchGenerators(String companyId);
  Future<int> pendingRequestCount(String companyId);
  Future<Map<String, int>> activeRentalCounts(String companyId);
}
