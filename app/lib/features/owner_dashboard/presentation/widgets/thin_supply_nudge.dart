import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/owner_providers.dart' show ownerRepositoryProvider;

/// Governorates with fewer than 3 available generators.
final thinSupplyProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final data = await ref
      .read(ownerRepositoryProvider)
      .fetchAvailableGeneratorsGovernorates();
  final counts = <String, int>{};
  for (final g in data) {
    final gov = g['governorate']?.toString();
    if (gov == null || gov.isEmpty) continue;
    counts[gov] = (counts[gov] ?? 0) + 1;
  }
  return counts.entries
      .where((e) => e.value < 3)
      .map((e) => e.key)
      .take(3)
      .toList();
});

/// Orange banner shown when certain governorates have < 3 available generators.
/// Tapping pushes the Add Generator screen so the owner can help fill the gap.
class ThinSupplyNudge extends ConsumerWidget {
  const ThinSupplyNudge({super.key, required this.companyId, required this.cs});
  final String companyId;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thin = ref.watch(thinSupplyProvider).valueOrNull;
    if (thin == null || thin.isEmpty) return const SizedBox.shrink();

    final l = AppLocalizations.of(context)!;
    final govList = thin.join(' · ');

    return GestureDetector(
      onTap: () => context.push(AppRoutes.addGenerator(companyId)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.bolt, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.thinSupplyNudge(govList),
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.add_circle_outline,
              size: 16, color: Colors.orange.shade700),
        ]),
      ),
    );
  }
}
