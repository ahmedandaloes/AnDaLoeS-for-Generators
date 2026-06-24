import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/rental_repository.dart'
    show rentalTimelineProvider;

// ── Status progress timeline ──────────────────────────────────────────────────
class RentalStatusTimeline extends ConsumerWidget {
  const RentalStatusTimeline(
      {super.key, required this.rentalId, required this.status, required this.cs});
  final String rentalId;
  final String status;
  final ColorScheme cs;

  static const _steps = ['pending', 'accepted', 'active', 'completed'];
  static const _labels = ['Submitted', 'Accepted', 'Active', 'Done'];
  static const _icons = [
    Icons.send_rounded,
    Icons.check_circle_outline,
    Icons.bolt,
    Icons.verified_outlined,
  ];

  int get _currentIndex => _steps.indexOf(status);

  String _tsFor(String step, List<Map<String, dynamic>> events) {
    final match = events.lastWhere(
      (e) => e['event'] == step,
      orElse: () => {},
    );
    final raw = match['created_at']?.toString();
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} $h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events =
        ref.watch(rentalTimelineProvider(rentalId)).valueOrNull ?? const [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = (i - 1) ~/ 2;
          final done = _currentIndex > stepIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Container(
                height: 2,
                color: done ? cs.primary : cs.outlineVariant,
              ),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = _currentIndex > stepIndex;
        final active = _currentIndex == stepIndex;
        final color = done || active ? cs.primary : cs.outlineVariant;
        final ts = _tsFor(_steps[stepIndex], events);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 28 : 22,
              height: active ? 28 : 22,
              decoration: BoxDecoration(
                color: done || active
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(
                        color: cs.primary.withValues(alpha: 0.35), width: 3)
                    : null,
              ),
              child: Icon(
                _icons[stepIndex],
                size: active ? 14 : 11,
                color: done || active ? cs.onPrimary : cs.outlineVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _labels[stepIndex],
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? cs.primary : color,
              ),
            ),
            if (ts.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                ts,
                style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class RentalsEmptyState extends StatelessWidget {
  const RentalsEmptyState(
      {super.key, required this.cs, required this.onBrowse});
  final ColorScheme cs;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt, size: 44, color: cs.primary),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.1),
                              blurRadius: 8),
                        ],
                      ),
                      child: Icon(Icons.receipt_long,
                          size: 20, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(l.noRentalsYet,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 10),
            Text(
              'Browse available generators nearby\nand send your first rental request.',
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: Text(l.browseGenerators),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class RentalsSkeleton extends StatefulWidget {
  const RentalsSkeleton({super.key, required this.cs});
  final ColorScheme cs;

  @override
  State<RentalsSkeleton> createState() => _RentalsSkeletonState();
}

class _RentalsSkeletonState extends State<RentalsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = cs.onSurface.withValues(alpha: _anim.value * 0.18);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => Container(
            height: 130,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 160,
                            height: 14,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Container(
                            width: 100,
                            height: 11,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(4))),
                      ]),
                  const Spacer(),
                  Container(
                      width: 60,
                      height: 22,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(11))),
                ]),
                Row(children: [
                  Container(
                      width: 90,
                      height: 11,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4))),
                  const Spacer(),
                  Container(
                      width: 70,
                      height: 11,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(4))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
