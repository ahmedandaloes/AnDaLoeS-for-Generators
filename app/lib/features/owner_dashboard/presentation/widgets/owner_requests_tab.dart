import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/utils/db_error.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/owner_providers.dart'
    show ownerRequestsProvider, ownerRepositoryProvider;
import 'request_card.dart';

class OwnerRequestsTab extends StatelessWidget {
  const OwnerRequestsTab(
      {super.key, required this.companyId, required this.cs, required this.ref});
  final String companyId;
  final ColorScheme cs;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final requestsAsync = ref.watch(ownerRequestsProvider(companyId));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const AppErrorState(),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(ownerRequestsProvider(companyId).future),
            child: ListView(children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.3),
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.5),
                            ),
                          ),
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer,
                            ),
                            child: Icon(Icons.inbox_outlined,
                                size: 26, color: cs.primary),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        Text(l.noRequestsYet,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Customers will appear here once they request a generator you own.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.bolt_outlined, size: 16),
                          label: Text(l.addAGenerator),
                          onPressed: () =>
                              context.push(AppRoutes.addGenerator(companyId)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          );
        }
        final pendingItems =
            items.where((r) => r['status']?.toString() == 'pending').toList();
        final hasMultiplePending = pendingItems.length >= 2;

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(ownerRequestsProvider(companyId).future),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    16, hasMultiplePending ? 68 : 16, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final req = items[i];
                  final reqId = req['id']?.toString() ?? '';
                  final isPending = req['status']?.toString() == 'pending';

                  if (!isPending) {
                    return OwnerRequestCard(
                        request: req, ref: ref, companyId: companyId);
                  }

                  return Dismissible(
                    key: ValueKey('owner_req_$reqId'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (dir) async {
                      if (dir == DismissDirection.startToEnd) {
                        try {
                          await ref
                              .read(ownerRepositoryProvider)
                              .updateRequestStatus(reqId, 'accepted');
                          ref.invalidate(ownerRequestsProvider(companyId));
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(friendlyDbError(e,
                                      fallback:
                                          'Could not accept the request.'))),
                            );
                          }
                        }
                        return false;
                      } else {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            title: Text(l.rejectRequestQ),
                            content: const Text(
                                'The customer will be notified that their request was rejected.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l.cancel)),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: cs.error),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l.reject),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(ownerRepositoryProvider)
                              .updateRequestStatus(reqId, 'rejected');
                          ref.invalidate(ownerRequestsProvider(companyId));
                        }
                        return false;
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding:
                          const EdgeInsetsDirectional.only(start: 20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Icon(Icons.check_rounded,
                            color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text(l.accept,
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsetsDirectional.only(end: 20),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.close_rounded, color: cs.error),
                            const SizedBox(width: 6),
                            Text(l.reject,
                                style: TextStyle(
                                    color: cs.error,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                    child: OwnerRequestCard(
                        request: req, ref: ref, companyId: companyId),
                  );
                },
              ),
            ),
            if (hasMultiplePending)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: cs.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () =>
                        _acceptAll(context, pendingItems, companyId),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                        'Accept all ${pendingItems.length} pending requests'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _acceptAll(BuildContext context,
      List<Map<String, dynamic>> pending, String companyId) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.acceptAllQ),
        content: Text('Accept all ${pending.length} pending requests at once?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.acceptAll)),
        ],
      ),
    );
    if (confirmed != true) return;
    var accepted = 0;
    var skipped = 0;
    final repo = ref.read(ownerRepositoryProvider);
    for (final r in pending) {
      try {
        await repo.updateRequestStatus(r['id'].toString(), 'accepted');
        accepted++;
      } catch (_) {
        skipped++;
      }
    }
    ref.invalidate(ownerRequestsProvider(companyId));
    if (context.mounted) {
      final msg = skipped == 0
          ? 'Accepted $accepted request${accepted == 1 ? '' : 's'}.'
          : 'Accepted $accepted; skipped $skipped with date conflicts.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
