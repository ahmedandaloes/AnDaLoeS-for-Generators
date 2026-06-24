import '../entities/company.dart';

abstract class ICompanyRepository {
  Future<Company?> fetchByOwner(String ownerId);
  Future<void> create(Map<String, dynamic> data);
  Future<void> update(String companyId, Map<String, dynamic> data);
}
