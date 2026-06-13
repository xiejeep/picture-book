import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../features/text_detection/models/text_block_data.dart';
import '../../features/text_detection/models/handle_position.dart';

class BookEditorState {
  final File? imageFile;
  final ui.Image? backgroundImage;
  final Size canvasSize;
  final List<TextBlockData> textBlocks;
  final String? selectedBlockId;
  final bool isProcessing;
  final bool hasChanges;
  final bool isDrawing;
  final Rect? currentDrawRect;
  final Offset? drawStartPoint;
  final Offset? movePointerStart;
  final Rect? moveRectOriginal;
  final HandlePosition? activeHandle;
  final Rect? resizeOriginalRect;

  const BookEditorState({
    this.imageFile,
    this.backgroundImage,
    this.canvasSize = Size.zero,
    this.textBlocks = const [],
    this.selectedBlockId,
    this.isProcessing = false,
    this.hasChanges = false,
    this.isDrawing = false,
    this.currentDrawRect,
    this.drawStartPoint,
    this.movePointerStart,
    this.moveRectOriginal,
    this.activeHandle,
    this.resizeOriginalRect,
  });

  TextBlockData? get selectedBlock {
    if (selectedBlockId == null) return null;
    try {
      return textBlocks.firstWhere((b) => b.id == selectedBlockId);
    } catch (_) {
      return null;
    }
  }

  BookEditorState copyWith({
    File? imageFile,
    ui.Image? backgroundImage,
    Size? canvasSize,
    List<TextBlockData>? textBlocks,
    String? selectedBlockId,
    bool? isProcessing,
    bool? hasChanges,
    bool? isDrawing,
    Rect? currentDrawRect,
    Offset? drawStartPoint,
    Offset? movePointerStart,
    Rect? moveRectOriginal,
    HandlePosition? activeHandle,
    Rect? resizeOriginalRect,
    bool clearSelectedBlockId = false,
    bool clearCurrentDrawRect = false,
    bool clearDrawStartPoint = false,
    bool clearMovePointerStart = false,
    bool clearMoveRectOriginal = false,
    bool clearActiveHandle = false,
    bool clearResizeOriginalRect = false,
  }) {
    return BookEditorState(
      imageFile: imageFile ?? this.imageFile,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      canvasSize: canvasSize ?? this.canvasSize,
      textBlocks: textBlocks ?? this.textBlocks,
      selectedBlockId: clearSelectedBlockId
          ? null
          : (selectedBlockId ?? this.selectedBlockId),
      isProcessing: isProcessing ?? this.isProcessing,
      hasChanges: hasChanges ?? this.hasChanges,
      isDrawing: isDrawing ?? this.isDrawing,
      currentDrawRect: clearCurrentDrawRect
          ? null
          : (currentDrawRect ?? this.currentDrawRect),
      drawStartPoint:
          clearDrawStartPoint ? null : (drawStartPoint ?? this.drawStartPoint),
      movePointerStart: clearMovePointerStart
          ? null
          : (movePointerStart ?? this.movePointerStart),
      moveRectOriginal: clearMoveRectOriginal
          ? null
          : (moveRectOriginal ?? this.moveRectOriginal),
      activeHandle:
          clearActiveHandle ? null : (activeHandle ?? this.activeHandle),
      resizeOriginalRect: clearResizeOriginalRect
          ? null
          : (resizeOriginalRect ?? this.resizeOriginalRect),
    );
  }
}
