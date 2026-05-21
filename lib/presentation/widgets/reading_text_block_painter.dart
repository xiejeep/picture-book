import 'package:flutter/material.dart';
import '../../../data/models/text_block_model.dart';

class ReadingTextBlockPainter extends CustomPainter {
  final List<TextBlockModel> textBlocks;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;
  final int? playingBlockIndex;
  final Color textBlockMaskColor;

  ReadingTextBlockPainter({
    required this.textBlocks,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
    this.playingBlockIndex,
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

      final isPlaying = i == playingBlockIndex;
      if (isPlaying) continue;

      final displayRect = _convertRect(block.boundingBox);

      final borderRadius = (displayRect.height * 0.08).clamp(4.0, 12.0);

      final borderPaint = Paint()
        ..color = textBlockMaskColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(displayRect, Radius.circular(borderRadius)),
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
        oldDelegate.playingBlockIndex != playingBlockIndex ||
        oldDelegate.textBlockMaskColor != textBlockMaskColor;
  }
}
