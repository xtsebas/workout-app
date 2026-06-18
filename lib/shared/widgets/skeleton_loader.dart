import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: AppColors.surface.withValues(alpha: 0.5),
        );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, borderRadius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  height: 14,
                ),
                const SizedBox(height: 8),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.2,
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TodaySkeleton extends StatelessWidget {
  const TodaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 180, height: 32, borderRadius: 6),
          const SizedBox(height: 8),
          const SkeletonBox(width: 100, height: 16, borderRadius: 4),
          const SizedBox(height: 20),
          Row(
            children: [
              const SkeletonBox(width: 100, height: 44, borderRadius: 10),
              const SizedBox(width: 12),
              const SkeletonBox(width: 140, height: 44, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 32),
          ...List.generate(
            4,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SkeletonCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressSkeleton extends StatelessWidget {
  const ProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: List.generate(
              3,
              (_) => const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: SkeletonBox(width: double.infinity, height: 80, borderRadius: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: double.infinity, height: 260, borderRadius: 12),
        ],
      ),
    );
  }
}
