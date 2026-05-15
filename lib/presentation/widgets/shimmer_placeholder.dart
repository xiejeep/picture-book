import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.darkMuted : Colors.grey.shade300,
      highlightColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class BookCardSkeleton extends StatelessWidget {
  const BookCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: ShimmerPlaceholder(
              width: double.infinity,
              height: double.infinity,
              radius: AppRadius.md,
            ),
          ),
          Padding(
            padding: AppSpacing.paddingMd,
            child: ShimmerPlaceholder(
              width: double.infinity,
              height: 16,
              radius: AppRadius.sm,
            ),
          ),
        ],
      ),
    );
  }
}

class BooksGridSkeleton extends StatelessWidget {
  final int itemCount;

  const BooksGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const BookCardSkeleton(),
    );
  }
}
