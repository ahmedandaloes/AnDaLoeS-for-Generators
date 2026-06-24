import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/status_colors.dart';
import '../../../core/utils/db_error.dart';
import '../../../l10n/app_localizations.dart';
import '../data/repositories/admin_repository.dart';

final adminRentalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchAllRentalsAdmin();
});

final _adminRentalQueryProvider = StateProvider<String>((ref) => '');

class AdminRentalsTab extends ConsumerWidget {
  const AdminRentalsTab({super.key, required this.ref});
  // ignore: overridden_fields
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final query = wRef.watch(_adminRentalQueryProvider).toLowerCase();
    final rentalsAsync = wRef.watch(adminRentalsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            decoration: InputDecoration(
              hintText: l.adminSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => wRef
                .read(_adminRentalQueryProvider.notifier)
                .state = v,
          ),
        ),
        Expanded(
          child: rentalsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(friendlyDbError(e))),
            data: (items) {
              final filtered = query.isEmpty
                  ? items
                  : items.where((r) {
                      final profile =
                          r['profiles'] as Map<String, dynamic>?;
                      final name = (profile?['full_name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final phone = (profile?['phone'] ?? '')
                          .toString()
                          .toLowerCase();
                      final gen =
                          r['generators'] as Map<String, dynamic>?;
                      final title = (gen?['title'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(query) ||
                          phone.contains(query) ||
                          title.contains(query);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(child: Text(l.noRentalsFound));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final r = filtered[i];
                  final status = r['status']?.toString() ?? '';
                  final profile =
                      r['profiles'] as Map<String, dynamic>?;
                  final gen =
                      r['generators'] as Map<String, dynamic>?;
                  final company =
                      r['companies'] as Map<String, dynamic>?;
                  final color = rentalStatusColor(status, cs);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                gen?['title']?.toString() ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            '${profile?['full_name'] ?? '—'}  ·  ${profile?['phone'] ?? '—'}',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant),
                          ),
                          Text(
                            company?['name']?.toString() ?? '—',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['start_date']} → ${r['end_date']}  ·  EGP ${r['price_total']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
