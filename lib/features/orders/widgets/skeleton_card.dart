import 'package:flutter/material.dart';

/// Lightweight shimmer skeleton that mirrors the OrderCard layout.
/// Uses RepaintBoundary to isolate the animation from the list.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final shimmer = Color.lerp(
            Colors.grey.shade200,
            Colors.grey.shade100,
            _anim.value,
          )!;
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    _box(44, 44, shimmer, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _box(14, 140, shimmer, radius: 7),
                          const SizedBox(height: 8),
                          _box(12, 90, shimmer, radius: 6),
                        ],
                      ),
                    ),
                    _box(28, 70, shimmer, radius: 14),
                  ],
                ),
                const SizedBox(height: 16),
                // Info rows
                _box(12, double.infinity, shimmer, radius: 6),
                const SizedBox(height: 8),
                _box(12, double.infinity, shimmer, radius: 6),
                const SizedBox(height: 16),
                // Footer
                Row(
                  children: [
                    _box(12, 80, shimmer, radius: 6),
                    const Spacer(),
                    _box(24, 70, shimmer, radius: 10),
                  ],
                ),
                const SizedBox(height: 16),
                // Buttons
                Row(
                  children: [
                    Expanded(child: _box(40, double.infinity, shimmer, radius: 12)),
                    const SizedBox(width: 12),
                    Expanded(child: _box(40, double.infinity, shimmer, radius: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _box(double h, double w, Color c, {double radius = 8}) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}