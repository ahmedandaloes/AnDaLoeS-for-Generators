import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase.dart';
import '../../../l10n/app_localizations.dart';

/// Fetches available generators visible to the current user (RLS only returns
/// units whose company is approved).
final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select('id, title, capacity_kva, price_per_day, city, governorate')
      .eq('status', 'available')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final generators = ref.watch(generatorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.browseGenerators),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: generators.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l.noGeneratorsYet));
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(generatorsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final g = items[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt, size: 32),
                    title: Text(g['title']?.toString() ?? '-'),
                    subtitle: Text(
                      '${g['capacity_kva']} KVA · ${g['governorate'] ?? g['city'] ?? ''}',
                    ),
                    trailing: Text(
                      '${g['price_per_day']} EGP/day',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
