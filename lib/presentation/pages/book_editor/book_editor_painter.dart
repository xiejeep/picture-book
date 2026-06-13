import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../features/text_detection/models/text_block_data.dart';

class BookEditorPainter extends CustomPainter {
  final ui.Image? backgroundImage;
  final List<TextBlockData> textBlocks;
  final String? selectedBlockId;
  final Rect? drawRect;
  final bool isDrawing;
  final double scale;

  BookEditorPainter({
    required this.backgroundImage,
    required this.textBlocks,
    this.selectedBlockId,
    this.drawRect,
    this.isDrawing = false,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImage != null) {
      canvas.drawImage(backgroundImage!, Offset.zero, Paint());
    }

    for (final block in textBlocks) {
      if (block.isDeleted) continue;
      _drawBlock(canvas, block);
    }

    if (isDrawing && drawRect != null) {
      final fill = Paint()
        ..color = Colors.blue.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(drawRect!, fill);
      final border = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale;
      canvas.drawRect(drawRect!, border);
    }
  }

  void _drawBlock(Canvas canvas, TextBlockData block) {
    final isSelected = block.id == selectedBlockId;
    final rect = block.boundingBox;

    final fill = Paint()
      ..color = isSelected
          ? Colors.blue.withValues(alpha: 0.2)
          : Colors.orange.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final border = Paint()
      ..color = isSelected ? Colors.blue : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? (2.5 / scale) : (1.5 / scale);
    canvas.drawRect(rect, border);

    if (block.text.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: block.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: (12 / scale).clamp(8.0, 24.0),
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 2 / scale,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      tp.layout(maxWidth: rect.width - 8 / scale);
      tp.paint(canvas, Offset(rect.left + 4 / scale, rect.top + 4 / scale));
    }

    if (isSelected) {
      _drawHandles(canvas, rect);
    }
  }

  void _drawHandles(Canvas canvas, Rect rect) {
    final handleSize = (12.0 / scale).clamp(8.0, 24.0);

    final positions = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale;

    for (final pos in positions) {
      final r =
          Rect.fromCenter(center: pos, width: handleSize, height: handleSize);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, border);
    }
  }

  @override
  bool shouldRepaint(BookEditorPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.textBlocks != textBlocks ||
        oldDelegate.selectedBlockId != selectedBlockId ||
        oldDelegate.drawRect != drawRect ||
        oldDelegate.isDrawing != isDrawing ||
        oldDelegate.scale != scale;
  }
}
