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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6BCB77),
            Color(0xFF89C4F4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6BCB77).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            onTap: hasPrev ? onPrevious : null,
            icon: Icons.arrow_back_ios_new_rounded,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
            onTap: hasNext ? onNext : null,
            icon: Icons.arrow_forward_ios_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback? onTap,
    required IconData icon,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.white : Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }
}
