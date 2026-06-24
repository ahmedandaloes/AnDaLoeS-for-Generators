import 'package:flutter/material.dart';

/// Animated loading skeleton shown while generator detail data loads.
// ── Detail skeleton shown while data loads ────────────────────────────────────
class GeneratorDetailSkeleton extends StatefulWidget {
  const GeneratorDetailSkeleton({required this.cs});
  final ColorScheme cs;

  @override
  State<GeneratorDetailSkeleton> createState() => GeneratorDetailSkeletonState();
}

class GeneratorDetailSkeletonState extends State<GeneratorDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.65).animate(
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
        final base = cs.onSurface.withValues(alpha: _anim.value * 0.18);
        return CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: base),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  _Bone(height: 26, width: 220, color: base),
                  const SizedBox(height: 10),
                  // KVA chip + city
                  Row(children: [
                    _Bone(height: 18, width: 70, color: base),
                    const SizedBox(width: 8),
                    _Bone(height: 18, width: 100, color: base),
                  ]),
                  const SizedBox(height: 20),
                  // Price row
                  _Bone(height: 36, width: 160, color: base),
                  const SizedBox(height: 24),
                  // Company row
                  Row(children: [
                    _Bone(height: 42, width: 42, color: base, circle: true),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Bone(height: 14, width: 130, color: base),
                      const SizedBox(height: 6),
                      _Bone(height: 11, width: 90, color: base),
                    ]),
                  ]),
                  const SizedBox(height: 24),
                  // Spec chips row
                  Row(children: [
                    for (int i = 0; i < 3; i++) ...[
                      _Bone(height: 36, width: 90, color: base, radius: 18),
                      const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: 24),
                  // Description lines
                  _Bone(height: 13, width: double.infinity, color: base),
                  const SizedBox(height: 7),
                  _Bone(height: 13, width: double.infinity, color: base),
                  const SizedBox(height: 7),
                  _Bone(height: 13, width: 200, color: base),
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    required this.height,
    required this.width,
    required this.color,
    this.circle = false,
    this.radius,
  });
  final double height;
  final double width;
  final Color color;
  final bool circle;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width == double.infinity ? null : width,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius ?? 6),
      ),
    );
  }
}
