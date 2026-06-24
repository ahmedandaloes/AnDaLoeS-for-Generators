import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

final myRentalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final data = await supabase
      .from('rental_requests')
      .select('*, generators(title, capacity_kva, city, photos), companies(name)')
      .eq('customer_id', uid)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});
