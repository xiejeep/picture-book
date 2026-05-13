import 'package:flutter/material.dart';
import '../models/canvas_mode.dart';
import '../models/handle_position.dart';
import '../models/text_detection_state.dart';

class TextBlockPainter extends CustomPainter {
  final TextDetectionState state;
  final TransformationController transformController;

  TextBlockPainter({
    required this.state,
    required this.transformController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    _drawBackground(canvas, size);
    _drawImage(canvas);
    _drawBlocks(canvas);
    _drawCurrentRect(canvas);
    _drawSelectionHandles(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = state.backgroundImage != null
          ? Colors.white
          : const Color(0xFFF5F5F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawImage(Canvas canvas) {
    final image = state.backgroundImage;
    if (image == null) return;
    canvas.drawImage(image, Offset.zero, Paint());
  }

  void _drawBlocks(Canvas canvas) {
    for (final block in state.textBlocks) {
      if (block.isDeleted) continue;
      if (block.text.isNotEmpty && !_isEnglishText(block.text)) continue;

      final isSelected = block.id == state.selectedBlockId;
      final isEditMode = state.mode == CanvasMode.edit;
      final isResizeMode = state.editSubMode == EditSubMode.resize;

      final fillColor = isSelected
          ? (isResizeMode ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3))
          : Colors.blue.withOpacity(0.2);

      final borderColor = isSelected
          ? (isResizeMode ? Colors.green : Colors.orange)
          : Colors.blue;

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 2.0;

      canvas.drawRect(block.boundingBox, fillPaint);
      canvas.drawRect(block.boundingBox, borderPaint);

      if (isSelected && isEditMode) {
        _drawDeleteButton(canvas, block.boundingBox);
      }

      final displayText = block.text.length > 20 
          ? '${block.text.substring(0, 20)}...' 
          : block.text;
      _drawTextLabel(canvas, block.boundingBox, displayText, borderColor);
    }
  }

  void _drawCurrentRect(Canvas canvas) {
    final rect = state.currentDrawRect;
    if (rect == null) return;

    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(rect, fillPaint);
    canvas.drawRect(rect, strokePaint);
  }

  void _drawSelectionHandles(Canvas canvas) {
    if (state.mode != CanvasMode.edit) return;
    if (state.editSubMode != EditSubMode.resize) return;
    
    final selected = state.selectedBlock;
    if (selected == null) return;

    final scale = transformController.value.getMaxScaleOnAxis().clamp(0.01, 100.0);
    final handleSize = (20.0 / scale).clamp(10.0, 60.0);

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.5 / scale).clamp(1.5, 4.0);

    final positions = [
      HandlePosition.topLeft,
      HandlePosition.topRight,
      HandlePosition.bottomLeft,
      HandlePosition.bottomRight,
      HandlePosition.top,
      HandlePosition.bottom,
      HandlePosition.left,
      HandlePosition.right,
    ];

    for (final pos in positions) {
      final offset = _getHandleOffset(pos, selected.boundingBox);
      final handleRect = Rect.fromCenter(
        center: offset,
        width: handleSize,
        height: handleSize,
      );

      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleBorderPaint);
    }
  }

  Offset _getHandleOffset(HandlePosition pos, Rect rect) {
    switch (pos) {
      case HandlePosition.topLeft:
        return rect.topLeft;
      case HandlePosition.topRight:
        return rect.topRight;
      case HandlePosition.bottomLeft:
        return rect.bottomLeft;
      case HandlePosition.bottomRight:
        return rect.bottomRight;
      case HandlePosition.top:
        return Offset(rect.center.dx, rect.top);
      case HandlePosition.bottom:
        return Offset(rect.center.dx, rect.bottom);
      case HandlePosition.left:
        return Offset(rect.left, rect.center.dy);
      case HandlePosition.right:
        return Offset(rect.right, rect.center.dy);
    }
  }

  void _drawDeleteButton(Canvas canvas, Rect rect) {
    final scale = transformController.value.getMaxScaleOnAxis().clamp(0.01, 100.0);
    final buttonSize = (24.0 / scale).clamp(16.0, 40.0);

    final deletePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final deleteBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.0 / scale).clamp(1.0, 3.0);

    final deleteIconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (3.0 / scale).clamp(1.5, 4.0)
      ..strokeCap = StrokeCap.round;

    final Offset deletePos = Offset(rect.right + buttonSize / 2, rect.top - buttonSize / 2);

    canvas.drawCircle(deletePos, buttonSize / 2, deletePaint);
    canvas.drawCircle(deletePos, buttonSize / 2, deleteBorderPaint);

    final iconSize = buttonSize * 0.3;
    canvas.drawLine(
      Offset(deletePos.dx - iconSize, deletePos.dy - iconSize),
      Offset(deletePos.dx + iconSize, deletePos.dy + iconSize),
      deleteIconPaint,
    );
    canvas.drawLine(
      Offset(deletePos.dx + iconSize, deletePos.dy - iconSize),
      Offset(deletePos.dx - iconSize, deletePos.dy + iconSize),
      deleteIconPaint,
    );
  }

  void _drawTextLabel(Canvas canvas, Rect rect, String text, Color color) {
    final scale = transformController.value.getMaxScaleOnAxis().clamp(0.01, 100.0);
    final fontSize = (12.0 / scale).clamp(8.0, 24.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final yOffset = rect.top - (fontSize + 4);
    textPainter.paint(canvas, Offset(rect.left, yOffset.clamp(0, rect.top)));
  }

  bool _isEnglishText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    for (final char in trimmed.split('')) {
      final codeUnit = char.codeUnitAt(0);
      if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant TextBlockPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.transformController.value != transformController.value;
  }
}