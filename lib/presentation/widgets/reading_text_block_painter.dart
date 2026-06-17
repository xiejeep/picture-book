import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/models/text_block_model.dart';

class ReadingTextBlockPainter extends CustomPainter {
  final List<TextBlockModel> textBlocks;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;
  final int? playingBlockIndex;
  final int? loadingBlockIndex;
  final double loadingAnimationValue;
  final Color textBlockMaskColor;

  ReadingTextBlockPainter({
    required this.textBlocks,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
    this.playingBlockIndex,
    this.loadingBlockIndex,
    this.loadingAnimationValue = 0.0,
    required this.textBlockMaskColor,
  });

  double get scaleX => displayWidth / imageWidth;
  double get scaleY => displayHeight / imageHeight;

  Rect _convertRect(Rect originalRect) {
    return Rect.fromLTRB(
      originalRect.left * scaleX,
      originalRect.top * scaleY,
      originalRect.right * scaleX,
      originalRect.bottom * scaleY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < textBlocks.length; i++) {
      final block = textBlocks[i];
      if (block.isDeleted) continue;

      final isBlockLoading = i == loadingBlockIndex;
      final isPlaying = i == playingBlockIndex;

      if (!isBlockLoading && isPlaying) continue;

      final displayRect = _convertRect(block.boundingBox);
      final borderRadius = (displayRect.height * 0.08).clamp(4.0, 12.0);
      final rrect = RRect.fromRectAndRadius(displayRect, Radius.circular(borderRadius));

      if (isBlockLoading) {
        final overlayPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, overlayPaint);

        final center = displayRect.center;
        final radius = (min(displayRect.width, displayRect.height) * 0.25).clamp(12.0, 32.0);
        final arcRect = Rect.fromCircle(center: center, radius: radius);

        final bgPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(center, radius, bgPaint);

        final arcPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;

        final sweepAngle = pi * 1.5;
        final startAngle = loadingAnimationValue * 2 * pi;
        canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);
      } else {
        final borderPaint = Paint()
          ..color = textBlockMaskColor
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ReadingTextBlockPainter oldDelegate) {
    return oldDelegate.textBlocks != textBlocks ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.displayWidth != displayWidth ||
        oldDelegate.displayHeight != displayHeight ||
        oldDelegate.playingBlockIndex != playingBlockIndex ||
        oldDelegate.loadingBlockIndex != loadingBlockIndex ||
        oldDelegate.loadingAnimationValue != loadingAnimationValue ||
        oldDelegate.textBlockMaskColor != textBlockMaskColor;
  }
}
