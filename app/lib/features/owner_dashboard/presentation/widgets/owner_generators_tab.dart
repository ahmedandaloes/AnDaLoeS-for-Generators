import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/owner_providers.dart';

enum _GenSort { status, kva, price }

class OwnerGeneratorsTab extends StatefulWidget {
  const OwnerGeneratorsTab(
      {super.key,
      required this.companyId,
      required this.cs,
      required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  State<OwnerGeneratorsTab> createState() => _OwnerGeneratorsTabState();
}

class _OwnerGeneratorsTabState extends State<OwnerGeneratorsTab> {
  _GenSort _sort = _GenSort.status;

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> items) {
    final copy = List<Map<String, dynamic>>.from(items);
    switch (_sort) {
      case _GenSort.status:
        const order = ['available', 'pending', 'unavailable'];
        copy.sort((a, b) {
          final ai = order.indexOf(a['status']?.toString() ?? '');
          final bi = order.indexOf(b['status']?.toString() ?? '');
          return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
        });
      case _GenSort.kva:
        copy.sort((a, b) => ((b['capacity_kva'] as num?) ?? 0)
            .compareTo((a['capacity_kva'] as num?) ?? 0));
      case _GenSort.price:
        copy.sort((a, b) => ((a['price_per_day'] as num?) ?? 0)
            .compareTo((b['price_per_day'] as num?) ?? 0));
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = widget.cs;
    final ref = widget.ref;
    final companyId = widget.companyId;
    final generatorsAsync = ref.watch(ownerGeneratorsProvider(companyId));

    return generatorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (items) {
        final sorted = _sorted(items);
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(ownerGeneratorsProvider(companyId).future),
          child: Column(
            children: [
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(l.sort,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      Wrap(spacing: 6, children: [
                        for (final s in _GenSort.values)
                          ChoiceChip(
                            label: Text(switch (s) {
                              _GenSort.status => l.sortStatus,
                              _GenSort.kva => l.sortKvaDesc,
                              _GenSort.price => l.sortPriceAsc,
                            }),
                            selected: _sort == s,
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 12),
                            onSelected: (_) => setState(() => _sort = s),
                          ),
                      ]),
                    ],
                  ),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt,
                                  size: 48, color: cs.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(l.emptyGeneratorsTitle,
                                  style:
                                      TextStyle(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _OwnerGeneratorTile(
                          gen: sorted[i],
                          cs: cs,
                          ref: ref,
                          companyId: companyId,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: () =>
                      context.push(AppRoutes.addGenerator(companyId)),
                  icon: const Icon(Icons.add),
                  label: Text(l.addGenerator),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerGeneratorTile extends StatelessWidget {
  const _OwnerGeneratorTile(
      {required this.gen,
      required this.cs,
      required this.ref,
      required this.companyId});
  final Map<String, dynamic> gen;
  final ColorScheme cs;
  final WidgetRef ref;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAvailable = gen['status']?.toString() == 'available';
    final countsAsync = ref.watch(activeRentalCountsProvider(companyId));
    final activeCount =
        countsAsync.valueOrNull?[gen['id']?.toString()] ?? 0;
    final photos = (gen['photos'] as List?)?.cast<String>() ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first : null;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: firstPhoto != null
                  ? Image.network(
                      firstPhoto,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _GenIcon(isAvailable: isAvailable, cs: cs),
                    )
                  : _GenIcon(isAvailable: isAvailable, cs: cs),
            ),
            if (activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        title: Text(gen['title']?.toString() ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${gen['capacity_kva']} KVA  •  EGP ${gen['price_per_day']}/day'
          '${activeCount > 0 ? '  •  $activeCount active' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_all_outlined, size: 20),
              tooltip: l.cloneListing,
              onPressed: () => context.push(
                AppRoutes.addGenerator(companyId),
                extra: Map<String, dynamic>.from(gen),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: l.edit,
              onPressed: () => context
                  .push(AppRoutes.editGenerator(gen['id'].toString())),
            ),
            Switch(
              value: isAvailable,
              onChanged: (v) => _toggleStatus(context, v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(BuildContext context, bool available) async {
    try {
      await supabase.from('generators').update(
          {'status': available ? 'available' : 'unavailable'}).eq(
          'id', gen['id'].toString());
      ref.invalidate(ownerGeneratorsProvider(companyId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _GenIcon extends StatelessWidget {
  const _GenIcon({required this.isAvailable, required this.cs});
  final bool isAvailable;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: isAvailable ? cs.primaryContainer : cs.surfaceContainerHighest,
      child: Icon(Icons.bolt,
          color: isAvailable ? cs.primary : cs.onSurfaceVariant, size: 22),
    );
  }
}
