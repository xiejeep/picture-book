import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'text_block_data.dart';
import 'canvas_mode.dart';
import 'handle_position.dart';
import '../../../../core/constants/constants.dart';

class TextDetectionState {
  final File? imageFile;
  final ui.Image? backgroundImage;
  final Size canvasSize;
  final List<TextBlockData> textBlocks;
  final String? selectedBlockId;
  final CanvasMode mode;
  final EditSubMode editSubMode;
  final bool isProcessing;
  final bool isAiEnhancing;
  final String? errorMessage;
  final Rect? currentDrawRect;
  final Offset? drawStartPoint;
  final Offset? movePointerStart;
  final Rect? moveRectOriginal;
  final HandlePosition? activeHandle;
  final Rect? resizeOriginalRect;
  final bool hasChanges;
  final String currentAiModel;
  final double speechRate;
  final bool useGlmTts;
  final bool showAiBanner;

  const TextDetectionState({
    this.imageFile,
    this.backgroundImage,
    this.canvasSize = Size.zero,
    this.textBlocks = const [],
    this.selectedBlockId,
    this.mode = CanvasMode.view,
    this.editSubMode = EditSubMode.move,
    this.isProcessing = false,
    this.isAiEnhancing = false,
    this.errorMessage,
    this.currentDrawRect,
    this.drawStartPoint,
    this.movePointerStart,
    this.moveRectOriginal,
    this.activeHandle,
    this.resizeOriginalRect,
    this.hasChanges = false,
    this.currentAiModel = AppConstants.defaultModel,
    this.speechRate = AppConstants.systemTtsDefaultSpeed,
    this.useGlmTts = false,
    this.showAiBanner = false,
  });

  TextBlockData? get selectedBlock {
    if (selectedBlockId == null) return null;
    try {
      return textBlocks.firstWhere((b) => b.id == selectedBlockId);
    } catch (_) {
      return null;
    }
  }

  List<TextBlockData> getVisibleBlocks() {
    return textBlocks.where((block) {
      if (block.isDeleted) return false;
      if (!_isEnglishText(block.text)) return false;
      return true;
    }).toList();
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

  TextDetectionState copyWith({
    File? imageFile,
    ui.Image? backgroundImage,
    Size? canvasSize,
    List<TextBlockData>? textBlocks,
    String? selectedBlockId,
    CanvasMode? mode,
    EditSubMode? editSubMode,
    bool? isProcessing,
    bool? isAiEnhancing,
    String? errorMessage,
    Rect? currentDrawRect,
    Offset? drawStartPoint,
    Offset? movePointerStart,
    Rect? moveRectOriginal,
    HandlePosition? activeHandle,
    Rect? resizeOriginalRect,
    bool? hasChanges,
    String? currentAiModel,
    double? speechRate,
    bool? useGlmTts,
    bool? showAiBanner,
    bool clearSelectedBlockId = false,
    bool clearErrorMessage = false,
    bool clearCurrentDrawRect = false,
    bool clearDrawStartPoint = false,
    bool clearMovePointerStart = false,
    bool clearMoveRectOriginal = false,
    bool clearActiveHandle = false,
    bool clearResizeOriginalRect = false,
  }) {
    return TextDetectionState(
      imageFile: imageFile ?? this.imageFile,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      canvasSize: canvasSize ?? this.canvasSize,
      textBlocks: textBlocks ?? this.textBlocks,
      selectedBlockId: clearSelectedBlockId ? null : (selectedBlockId ?? this.selectedBlockId),
      mode: mode ?? this.mode,
      editSubMode: editSubMode ?? this.editSubMode,
      isProcessing: isProcessing ?? this.isProcessing,
      isAiEnhancing: isAiEnhancing ?? this.isAiEnhancing,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentDrawRect: clearCurrentDrawRect ? null : (currentDrawRect ?? this.currentDrawRect),
      drawStartPoint: clearDrawStartPoint ? null : (drawStartPoint ?? this.drawStartPoint),
      movePointerStart: clearMovePointerStart ? null : (movePointerStart ?? this.movePointerStart),
      moveRectOriginal: clearMoveRectOriginal ? null : (moveRectOriginal ?? this.moveRectOriginal),
      activeHandle: clearActiveHandle ? null : (activeHandle ?? this.activeHandle),
      resizeOriginalRect: clearResizeOriginalRect ? null : (resizeOriginalRect ?? this.resizeOriginalRect),
      hasChanges: hasChanges ?? this.hasChanges,
      currentAiModel: currentAiModel ?? this.currentAiModel,
      speechRate: speechRate ?? this.speechRate,
      useGlmTts: useGlmTts ?? this.useGlmTts,
      showAiBanner: showAiBanner ?? this.showAiBanner,
    );
  }
}