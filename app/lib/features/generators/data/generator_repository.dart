import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final generatorRepositoryProvider =
    Provider<GeneratorRepository>((_) => GeneratorRepository());

class GeneratorRepository {
  static const _listSelect =
      'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count, fuel_type, created_at, companies(name)';

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final data = await supabase
        .from('generators')
        .select(_listSelect)
        .eq('status', 'available')
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchFeatured() async {
    final data = await supabase
        .from('generators')
        .select(_listSelect)
        .eq('status', 'available')
        .gte('avg_score', 4.0)
        .order('avg_score', ascending: false)
        .limit(8);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchNewArrivals() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final data = await supabase
        .from('generators')
        .select(
            'id, title, capacity_kva, price_per_day, city, photos, avg_score, fuel_type, created_at')
        .eq('status', 'available')
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchById(String id) async {
    return await supabase
        .from('generators')
        .select('*, companies(name, city, verification_status, contact_phone)')
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> fetchBooked(String generatorId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await supabase
        .from('rental_requests')
        .select('start_date, end_date, status')
        .eq('generator_id', generatorId)
        .inFilter('status', ['accepted', 'active'])
        .gte('end_date', today)
        .order('start_date');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchReviews(String generatorId) async {
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
  }

  Future<List<Map<String, dynamic>>> fetchSimilar(
      Map<String, dynamic> gen) async {
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
  }

  Future<Set<String>> fetchFavorites(String uid) async {
    final data = await supabase
        .from('user_favorites')
        .select('generator_id')
        .eq('user_id', uid);
    return {for (final r in (data as List)) r['generator_id'].toString()};
  }

  Future<bool> fetchIsFav(String uid, String generatorId) async {
    final data = await supabase
        .from('user_favorites')
        .select('generator_id')
        .eq('user_id', uid)
        .eq('generator_id', generatorId)
        .maybeSingle();
    return data != null;
  }

  Future<void> toggleFavorite(
      String uid, String generatorId, bool isFav) async {
    if (isFav) {
      await supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', uid)
          .eq('generator_id', generatorId);
    } else {
      await supabase.from('user_favorites').upsert({
        'user_id': uid,
        'generator_id': generatorId,
      });
    }
  }

  Future<List<String>> searchAutocomplete(String query) async {
    if (query.length < 2) return [];
    final data = await supabase
        .from('generators')
        .select('title, city, governorate')
        .or('title.ilike.%$query%,city.ilike.%$query%')
        .eq('status', 'available')
        .limit(8);
    final suggestions = <String>{};
    for (final g in (data as List)) {
      final title = g['title']?.toString() ?? '';
      final city = g['city']?.toString() ?? '';
      if (title.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(title);
      }
      if (city.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(city);
      }
    }
    return suggestions.take(6).toList();
  }

  Future<int?> fetchAvgResponseTime(String companyId) async {
    if (companyId.isEmpty) return null;
    final data = await supabase
        .from('rental_requests')
        .select('created_at, updated_at, status')
        .eq('company_id', companyId)
        .inFilter('status', ['accepted', 'rejected'])
        .limit(50);
    final list = (data as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    int totalMinutes = 0;
    for (final r in list) {
      try {
        final created = DateTime.parse(r['created_at'].toString());
        final updated = DateTime.parse(r['updated_at'].toString());
        totalMinutes += updated.difference(created).inMinutes;
      } catch (_) {}
    }
    return (totalMinutes / list.length).round();
  }
}
