import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'text_block_data.dart';
import 'canvas_mode.dart';
import 'handle_position.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/text_utils.dart';

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
  final bool showAiBanner;
  final String aiBannerText;

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
    this.showAiBanner = false,
    this.aiBannerText = 'AI正在优化识别结果...',
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
      if (!TextUtils.isEnglishText(block.text)) return false;
      return true;
    }).toList();
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
    bool? showAiBanner,
    String? aiBannerText,
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
      selectedBlockId: clearSelectedBlockId
          ? null
          : (selectedBlockId ?? this.selectedBlockId),
      mode: mode ?? this.mode,
      editSubMode: editSubMode ?? this.editSubMode,
      isProcessing: isProcessing ?? this.isProcessing,
      isAiEnhancing: isAiEnhancing ?? this.isAiEnhancing,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
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
      hasChanges: hasChanges ?? this.hasChanges,
      currentAiModel: currentAiModel ?? this.currentAiModel,
      speechRate: speechRate ?? this.speechRate,
      showAiBanner: showAiBanner ?? this.showAiBanner,
      aiBannerText: aiBannerText ?? this.aiBannerText,
    );
  }
}
