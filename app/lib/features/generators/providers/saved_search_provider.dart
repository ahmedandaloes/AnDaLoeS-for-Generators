import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../presentation/widgets/generator_filter.dart';

final savedSearchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null || supabase.auth.currentUser?.isAnonymous == true) return [];
  final data = await supabase
      .from('saved_searches')
      .select('id, name, filter, created_at')
      .eq('user_id', uid)
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

Future<void> saveSearch({
  required String name,
  required GeneratorFilter filter,
}) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return;
  await supabase.from('saved_searches').insert({
    'user_id': uid,
    'name': name,
    'filter': filter.toJson(),
  });
}

Future<void> deleteSavedSearch(String id) async {
  await supabase.from('saved_searches').delete().eq('id', id);
}
