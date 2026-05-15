import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrev = currentPage > 0;
    final hasNext = currentPage < totalPages - 1;
    final primaryColor = AppTheme.primaryOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppTheme.appBarGradientOf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            context: context,
            onTap: hasPrev ? onPrevious : null,
            icon: Icons.arrow_back_ios_new_rounded,
            semanticsLabel: '上一页',
            semanticsHint: '查看上一页内容',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentPage + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '/',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildButton(
            context: context,
            onTap: hasNext ? onNext : null,
            icon: Icons.arrow_forward_ios_rounded,
            semanticsLabel: '下一页',
            semanticsHint: '查看下一页内容',
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required VoidCallback? onTap,
    required IconData icon,
    required String semanticsLabel,
    String? semanticsHint,
  }) {
    final enabled = onTap != null;
    return Semantics(
      label: semanticsLabel,
      hint: semanticsHint,
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
