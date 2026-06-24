import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/utils/commission.dart';
import '../../data/repositories/owner_repository.dart';

export '../../data/repositories/owner_repository.dart'
    show ownerRepositoryProvider;

final commissionConfigProvider =
    FutureProvider.autoDispose.family<CommissionRule?, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('commission_config')
      .select('type, value, company_id')
      .eq('active', true);
  final list = (data as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return null;
  Map<String, dynamic>? pick;
  for (final r in list) {
    if (r['company_id']?.toString() == companyId) {
      pick = r;
      break;
    }
  }
  pick ??= list.firstWhere((r) => r['company_id'] == null,
      orElse: () => list.first);
  return (
    type: pick['type']?.toString() ?? 'percentage',
    value: (pick['value'] as num?)?.toDouble() ?? 0,
  );
});

final myCompanyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('companies')
      .select()
      .eq('owner_user_id', uid)
      .maybeSingle();
  return data;
});

final ownerRequestsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchRequests(
    companyId,
    statuses: ['pending', 'accepted', 'active'],
  );
});

final ownerHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
      .eq('company_id', companyId)
      .inFilter('status', ['completed', 'rejected', 'cancelled'])
      .order('updated_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

final ownerRatedRentalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('ratings')
      .select('rental_request_id')
      .eq('rater_id', uid);
  return {for (final r in (data as List)) r['rental_request_id'].toString()};
});

final ownerGeneratorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchGenerators(companyId);
});

final ownerPendingCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;
  final company = await ref.watch(myCompanyProvider.future);
  if (company == null) return 0;
  return ref
      .read(ownerRepositoryProvider)
      .pendingRequestCount(company['id'].toString());
});

final activeRentalCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).activeRentalCounts(companyId);
});
