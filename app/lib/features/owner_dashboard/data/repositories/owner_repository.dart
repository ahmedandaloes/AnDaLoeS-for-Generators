import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/company.dart';
import '../../domain/repositories/i_owner_repository.dart';

final ownerRepositoryProvider =
    Provider<OwnerRepository>((_) => OwnerRepository());

class OwnerRepository implements IOwnerRepository {
  @override
  Future<CompanyEntity?> fetchMyCompany(String uid) async {
    final data = await supabase
        .from('companies')
        .select()
        .eq('owner_user_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return CompanyEntity.fromMap(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRequests(String companyId,
      {List<String>? statuses}) async {
    var query = supabase
        .from('rental_requests')
        .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
        .eq('company_id', companyId);
    if (statuses != null && statuses.isNotEmpty) {
      query = query.inFilter('status', statuses);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGenerators(String companyId) async {
    final data = await supabase
        .from('generators')
        .select(
            'id, title, capacity_kva, description, price_per_day, price_per_week, '
            'price_per_month, deposit_amount, city, governorate, status, photos, '
            'fuel_type, hire_type, fuel_policy, accessories, use_cases')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<int> pendingRequestCount(String companyId) async {
    final data = await supabase
        .from('rental_requests')
        .select('id')
        .eq('company_id', companyId)
        .eq('status', 'pending');
    return (data as List).length;
  }

  @override
  Future<Map<String, int>> activeRentalCounts(String companyId) async {
    final data = await supabase
        .from('rental_requests')
        .select('generator_id')
        .eq('company_id', companyId)
        .inFilter('status', ['accepted', 'active']);
    final counts = <String, int>{};
    for (final row in (data as List)) {
      final gid = row['generator_id']?.toString() ?? '';
      counts[gid] = (counts[gid] ?? 0) + 1;
    }
    return counts;
  }
}
