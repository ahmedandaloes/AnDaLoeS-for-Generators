import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_error_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../../../core/theme/status_colors.dart';

final adminGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, status, created_at, companies(name)')
      .inFilter('status', ['pending', 'available', 'unavailable', 'rejected'])
      .order('created_at', ascending: false)
      .limit(80);
  return (data as List).cast<Map<String, dynamic>>();
});

class AdminGeneratorsTab extends StatefulWidget {
  const AdminGeneratorsTab({super.key, required this.ref});
  final WidgetRef ref;

  @override
  State<AdminGeneratorsTab> createState() => _AdminGeneratorsTabState();
}

class _AdminGeneratorsTabState extends State<AdminGeneratorsTab> {
  final _loading = <String, bool>{};

  Future<void> _setStatus(String genId, String status) async {
    setState(() => _loading[genId] = true);
    try {
      await supabase
          .from('generators')
          .update({'status': status}).eq('id', genId);
      widget.ref.invalidate(adminGeneratorsProvider);
    } finally {
      if (mounted) setState(() => _loading.remove(genId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final async = widget.ref.watch(adminGeneratorsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (generators) {
        if (generators.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_outlined,
                    size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(l.emptyGeneratorsTitle,
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }

        // Pending first
        final sorted = [
          ...generators.where((g) => g['status'] == 'pending'),
          ...generators.where((g) => g['status'] != 'pending'),
        ];

        return RefreshIndicator(
          onRefresh: () =>
              widget.ref.refresh(adminGeneratorsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _GenCard(g: sorted[i], loading: _loading, onStatus: _setStatus),
          ),
        );
      },
    );
  }
}

class _GenCard extends StatelessWidget {
  const _GenCard(
      {required this.g,
      required this.loading,
      required this.onStatus});
  final Map<String, dynamic> g;
  final Map<String, bool> loading;
  final Future<void> Function(String genId, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final genId = g['id']?.toString() ?? '';
    final status = g['status']?.toString() ?? '';
    final isPending = status == 'pending';
    final photo = (g['photos'] as List?)?.isNotEmpty == true
        ? g['photos'][0].toString()
        : null;
    final companyName =
        (g['companies'] as Map?)?['name']?.toString() ?? '—';
    final isLoading = loading[genId] == true;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.3),
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
              child: photo != null
                  ? Image.network(photo,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(cs))
                  : _placeholder(cs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          g['title']?.toString() ?? '—',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusBadge(status: status, cs: cs),
                    ]),
                    const SizedBox(height: 3),
                    Text(companyName,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (g['capacity_kva'] != null) ...[
                        Text('${g['capacity_kva']} KVA',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.primary)),
                        const SizedBox(width: 8),
                      ],
                      if (g['city'] != null)
                        Text(g['city'].toString(),
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant)),
                      if (g['price_per_day'] != null) ...[
                        const Spacer(),
                        Text('EGP ${g['price_per_day']}/day',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: cs.secondary)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ]),

          const Divider(height: 1, indent: 12, endIndent: 12),

          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => onStatus(genId, 'available'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(l.approve),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => onStatus(genId, 'rejected'),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(l.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side:
                          BorderSide(color: cs.error.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'available')
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => onStatus(genId, 'unavailable'),
                      icon: const Icon(Icons.pause_circle_outline, size: 14),
                      label: Text(l.setUnavailable),
                      style: TextButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                          textStyle: const TextStyle(fontSize: 12)),
                    )
                  else
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => onStatus(genId, 'available'),
                      icon: const Icon(Icons.play_circle_outline, size: 14),
                      label: Text(l.reactivate),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          textStyle: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 80,
        height: 80,
        color: cs.primaryContainer,
        child: Icon(Icons.bolt, color: cs.primary, size: 32),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.cs});
  final String status;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final color = generatorStatusColor(status, cs);
    final label = switch (status) {
      'available' => 'Live',
      'pending' => 'Pending',
      'unavailable' => 'Off',
      'rejected' => 'Rejected',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
