import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

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
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva), profiles(full_name, phone)')
      .eq('company_id', companyId)
      .inFilter('status', ['pending', 'accepted', 'active'])
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
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

// Rental IDs the owner has already submitted a rating for.
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
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, city, status')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

// Maps generator_id → count of active/accepted rentals
final activeRentalCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>(
        (ref, companyId) async {
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
});
