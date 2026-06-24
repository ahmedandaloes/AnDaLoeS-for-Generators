import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/commission.dart';
import '../../data/repositories/owner_repository.dart';

export '../../data/repositories/owner_repository.dart'
    show ownerRepositoryProvider;

final commissionConfigProvider =
    FutureProvider.autoDispose.family<CommissionRule?, String>(
        (ref, companyId) async {
  final list =
      await ref.read(ownerRepositoryProvider).fetchCommissionConfig();
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
  final repo = ref.read(ownerRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return null;
  return repo.fetchMyCompanyByUid(uid);
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
  return ref.read(ownerRepositoryProvider).fetchHistory(companyId);
});

final ownerRatedRentalIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final repo = ref.read(ownerRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return {};
  return repo.fetchRatedRentalIds(uid);
});

final ownerGeneratorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).fetchGenerators(companyId);
});

final ownerPendingCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(ownerRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return 0;
  final company = await ref.watch(myCompanyProvider.future);
  if (company == null) return 0;
  return repo.pendingRequestCount(company['id'].toString());
});

final activeRentalCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
        (ref, companyId) async {
  return ref.read(ownerRepositoryProvider).activeRentalCounts(companyId);
});
