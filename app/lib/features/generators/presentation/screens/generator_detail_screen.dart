import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/detail_providers.dart';
import 'generator_detail_body.dart';
import 'generator_detail_skeleton.dart';

class GeneratorDetailScreen extends ConsumerWidget {
  const GeneratorDetailScreen(
      {super.key, required this.id, this.scrollController});
  final String id;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(generatorDetailProvider(id));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: detail.when(
        loading: () => GeneratorDetailSkeleton(cs: cs),
        error: (e, _) => AppErrorState(
          message: "Couldn't load this generator.",
          onRetry: () => ref.invalidate(generatorDetailProvider(id)),
        ),
        data: (gen) =>
            GeneratorDetailBody(gen: gen, cs: cs, scrollController: scrollController),
      ),
    );
  }
}


// ── Rent Now sticky wrapper ───────────────────────────────────────────────────
class GeneratorDetailWrapper extends ConsumerWidget {
  const GeneratorDetailWrapper({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: GeneratorDetailScreen(id: id),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'rent',
        onPressed: () {
          HapticFeedback.mediumImpact();
          // Guests (anonymous) can browse the booking form and pick dates.
          // Auth is enforced at the final "Send request" step.
          context.push(AppRoutes.generatorRequest(id));
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(l.rentNow),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
