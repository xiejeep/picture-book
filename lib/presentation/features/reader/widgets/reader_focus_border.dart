import 'package:book_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReaderFocusBorder extends StatelessWidget {
  final Animation<Rect?>? focusAnimation;
  final Rect? currentFocusRect;
  final Animation<double>? bounceAnimation;
  final Listenable animation;

  const ReaderFocusBorder({
    super.key,
    required this.focusAnimation,
    required this.currentFocusRect,
    required this.bounceAnimation,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (focusAnimation == null || currentFocusRect == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final flyRect = focusAnimation!.value ?? currentFocusRect!;
        final bounceScale = bounceAnimation?.value ?? 1.0;
        final scaledRect = Rect.fromCenter(
          center: flyRect.center,
          width: flyRect.width * bounceScale,
          height: flyRect.height * bounceScale,
        );

        return Positioned(
          left: scaledRect.left,
          top: scaledRect.top,
          width: scaledRect.width,
          height: scaledRect.height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.focusHighlightColor,
                  width: (scaledRect.height * 0.04).clamp(3.0, 8.0),
                ),
                borderRadius: BorderRadius.circular(
                  (scaledRect.height * 0.08).clamp(4.0, 12.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
