import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final generatorDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final data = await supabase
      .from('generators')
      .select('*, companies(name, city, verification_status, contact_phone)')
      .eq('id', id)
      .single();
  return data;
});

final bookedDatesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final data = await supabase
      .from('rental_requests')
      .select('start_date, end_date, status')
      .eq('generator_id', generatorId)
      .inFilter('status', ['accepted', 'active'])
      .gte('end_date', today)
      .order('start_date');
  return (data as List).cast<Map<String, dynamic>>();
});

final generatorReviewsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  final rrData = await supabase
      .from('rental_requests')
      .select('id')
      .eq('generator_id', generatorId);
  final ids = (rrData as List).map((r) => r['id'].toString()).toList();
  if (ids.isEmpty) return [];
  final data = await supabase
      .from('ratings')
      .select('score, comment, created_at')
      .filter('rental_request_id', 'in', '(${ids.join(',')})')
      .not('comment', 'is', null)
      .order('created_at', ascending: false)
      .limit(10);
  return (data as List).cast<Map<String, dynamic>>();
});

final isFavProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return false;
  final data = await supabase
      .from('user_favorites')
      .select('generator_id')
      .eq('user_id', uid)
      .eq('generator_id', id)
      .maybeSingle();
  return data != null;
});

final similarGeneratorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, gen) async {
  final gov = gen['governorate']?.toString();
  final kva = (gen['capacity_kva'] as num?)?.toDouble() ?? 0;
  final id = gen['id']?.toString();
  if (gov == null || id == null) return [];
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, photos, avg_score')
      .eq('governorate', gov)
      .eq('is_available', true)
      .neq('id', id)
      .gte('capacity_kva', (kva * 0.5).floor())
      .lte('capacity_kva', kva * 2)
      .order('avg_score', ascending: false)
      .limit(6);
  return (data as List).cast<Map<String, dynamic>>();
});
