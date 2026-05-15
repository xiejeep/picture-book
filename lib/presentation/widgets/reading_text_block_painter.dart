import 'package:flutter/material.dart';
import '../../../data/models/text_block_model.dart';
import '../../../core/theme/app_theme.dart';

class ReadingTextBlockPainter extends CustomPainter {
  final List<TextBlockModel> textBlocks;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;
  final int? playingBlockIndex;

  ReadingTextBlockPainter({
    required this.textBlocks,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
    this.playingBlockIndex,
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

      final displayRect = _convertRect(block.boundingBox);
      final isPlaying = i == playingBlockIndex;

      final borderPaint = Paint()
        ..color = isPlaying
            ? AppTheme.honeyYellow.withValues(alpha: 0.9)
            : AppTheme.gentleGreen.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPlaying ? 3.5 : 2.5;

      canvas.drawRRect(
        RRect.fromRectAndRadius(displayRect, const Radius.circular(4)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ReadingTextBlockPainter oldDelegate) {
    return oldDelegate.textBlocks != textBlocks ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.displayWidth != displayWidth ||
        oldDelegate.displayHeight != displayHeight ||
        oldDelegate.playingBlockIndex != playingBlockIndex;
  }
}
