import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/text_block_data.dart';
import '../models/canvas_mode.dart';
import '../models/handle_position.dart';
import '../models/text_detection_state.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/ocr_service.dart';
import '../../../../data/services/ai_service.dart';
import '../../../../data/services/storage_service.dart';


class TextDetectionNotifier extends AutoDisposeNotifier<TextDetectionState> {
  final TransformationController transformController = TransformationController();
  final ImagePicker _picker = ImagePicker();
  
  Matrix4? _scaleStartMatrix;
  Matrix4? _panStartMatrix;
  Offset? _panStartFocalPoint;

  @override
  TextDetectionState build() {
    ref.onDispose(() {
      transformController.dispose();
    });
    
    final settings = StorageService.instance.getAiSettings();
    final savedModel = settings?.selectedModel ?? AppConstants.defaultModel;
    final modelExists = AppConstants.availableModels.any((m) => m['name'] == savedModel);
    return TextDetectionState(
      currentAiModel: modelExists ? savedModel : AppConstants.defaultModel,
      speechRate: settings?.speechRate ?? AppConstants.systemTtsDefaultSpeed,
      useGlmTts: settings?.useGlmTts ?? false,
    );
  }

  void setMode(CanvasMode newMode) {
    if (state.mode == newMode) return;
    state = state.copyWith(
      mode: newMode,
      editSubMode: EditSubMode.move,
      clearSelectedBlockId: true,
      clearCurrentDrawRect: true,
      clearDrawStartPoint: true,
      clearActiveHandle: true,
      clearMovePointerStart: true,
      clearMoveRectOriginal: true,
      clearResizeOriginalRect: true,
    );
  }

  void toggleEditSubMode() {
    final newSubMode = state.editSubMode == EditSubMode.move
        ? EditSubMode.resize
        : EditSubMode.move;
    state = state.copyWith(
      editSubMode: newSubMode,
      clearActiveHandle: true,
      clearMovePointerStart: true,
      clearMoveRectOriginal: true,
      clearResizeOriginalRect: true,
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    final File imageFile = File(pickedFile.path);
    
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '编辑图片',
          toolbarColor: AppTheme.calmBlue,
          toolbarWidgetColor: Colors.white,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: '编辑图片',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          rotateButtonsHidden: false,
          resetButtonHidden: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    final croppedImageFile = File(croppedFile.path);
    await loadImageFile(croppedImageFile);
  }

  Future<void> loadImageFile(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    state = state.copyWith(
      imageFile: imageFile,
      backgroundImage: image,
      canvasSize: Size(image.width.toDouble(), image.height.toDouble()),
      textBlocks: [],
      clearSelectedBlockId: true,
      clearErrorMessage: true,
    );

    transformController.value = Matrix4.identity();
    await recognizeText();
  }

  Future<void> loadInitialData(File imageFile, List<dynamic>? initialBlocks) async {
    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    state = state.copyWith(
      imageFile: imageFile,
      backgroundImage: image,
      canvasSize: Size(image.width.toDouble(), image.height.toDouble()),
    );

    transformController.value = Matrix4.identity();

    if (initialBlocks != null && initialBlocks.isNotEmpty) {
      final blocks = initialBlocks.map((block) {
        final blockMap = block as Map<String, dynamic>;
        return TextBlockData.fromMap(blockMap);
      }).toList();
      state = state.copyWith(textBlocks: blocks);
    } else {
      await recognizeText();
    }
  }

  Future<void> recognizeText() async {
    if (state.imageFile == null) return;

    state = state.copyWith(isProcessing: true, clearErrorMessage: true);

    try {
      final result = await OcrService.instance.recognizeText(state.imageFile!);
      
      if (result == null) {
        state = state.copyWith(
          errorMessage: '文字识别失败: 无法识别',
          isProcessing: false,
        );
        return;
      }
      
      final blocks = result.blocks.map((block) {
        return TextBlockData(
          id: DateTime.now().microsecondsSinceEpoch.toString() + block.text.hashCode.toString(),
          boundingBox: block.boundingBox,
          text: block.text,
        );
      }).toList();
      
      state = state.copyWith(
        textBlocks: blocks,
        clearSelectedBlockId: true,
        isProcessing: false,
        hasChanges: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: '文字识别失败: $e',
        isProcessing: false,
      );
    }
  }

  void fitToScreen(Size viewportSize) {
    if (state.backgroundImage == null) return;

    final imageSize = state.canvasSize;
    final scaleX = viewportSize.width / imageSize.width;
    final scaleY = viewportSize.height / imageSize.height;
    final scale = min(scaleX, scaleY) * 0.9;

    final offsetX = (viewportSize.width - imageSize.width * scale) / 2;
    final offsetY = (viewportSize.height - imageSize.height * scale) / 2;

    transformController.value = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(scale, scale);
  }

  void onPointerDown(Offset canvasPoint) {
    switch (state.mode) {
      case CanvasMode.view:
        _panStartMatrix = transformController.value.clone();
        _panStartFocalPoint = canvasPoint;
        break;
      case CanvasMode.draw:
        state = state.copyWith(
          drawStartPoint: canvasPoint,
          currentDrawRect: Rect.fromPoints(canvasPoint, canvasPoint),
        );
        break;
      case CanvasMode.edit:
        _onEditStart(canvasPoint);
        break;
    }
  }

  void onScaleStart() {
    if (state.mode == CanvasMode.view) {
      _scaleStartMatrix = transformController.value.clone();
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (state.mode == CanvasMode.view && details.pointerCount >= 2) {
      if (_scaleStartMatrix == null) return;
      final focalPoint = details.localFocalPoint;
      final scale = details.scale.clamp(0.1, 10.0);

      final zoomMatrix = Matrix4.identity()
        ..translate(focalPoint.dx, focalPoint.dy)
        ..scale(scale, scale)
        ..translate(-focalPoint.dx, -focalPoint.dy);

      transformController.value = zoomMatrix.multiplied(_scaleStartMatrix!);
      return;
    }

    switch (state.mode) {
      case CanvasMode.view:
        if (_panStartMatrix == null || _panStartFocalPoint == null) return;
        final delta = details.localFocalPoint - _panStartFocalPoint!;
        final newMatrix = _panStartMatrix!.clone();
        newMatrix.translate(delta.dx, delta.dy);
        transformController.value = newMatrix;
        break;
      case CanvasMode.draw:
        if (state.drawStartPoint == null) return;
        final rect = Rect.fromPoints(state.drawStartPoint!, details.localFocalPoint);
        state = state.copyWith(currentDrawRect: rect);
        break;
      case CanvasMode.edit:
        if (state.movePointerStart != null || state.activeHandle != null) {
          _onEditUpdate(details.localFocalPoint);
        }
        break;
    }
  }

  void onScaleEnd() {
    _scaleStartMatrix = null;
    _panStartMatrix = null;
    _panStartFocalPoint = null;

    switch (state.mode) {
      case CanvasMode.draw:
        _onDrawEnd();
        break;
      case CanvasMode.edit:
        _onEditEnd();
        break;
      default:
        break;
    }
  }

  void _onEditStart(Offset canvasPoint) {
    if (state.editSubMode == EditSubMode.resize && state.selectedBlock != null) {
      final handle = _hitTestHandle(canvasPoint);
      if (handle != null) {
        state = state.copyWith(
          activeHandle: handle,
          resizeOriginalRect: state.selectedBlock!.boundingBox,
        );
        return;
      }
    }

    final hitId = _hitTestBlock(canvasPoint);
    if (hitId != null) {
      final hitBlock = state.textBlocks.firstWhere((b) => b.id == hitId);
      state = state.copyWith(
        selectedBlockId: hitId,
        movePointerStart: canvasPoint,
        moveRectOriginal: hitBlock.boundingBox,
        editSubMode: EditSubMode.move,
      );
    } else {
      state = state.copyWith(clearSelectedBlockId: true);
    }
  }

  void _onEditUpdate(Offset canvasPoint) {
    if (state.activeHandle != null && state.resizeOriginalRect != null) {
      final newRect = _calculateResize(
        state.activeHandle!,
        state.resizeOriginalRect!,
        canvasPoint,
      );
      final newBlocks = List<TextBlockData>.from(state.textBlocks);
      final index = newBlocks.indexWhere((b) => b.id == state.selectedBlockId);
      if (index != -1) {
        newBlocks[index].boundingBox = newRect;
      }
      state = state.copyWith(textBlocks: newBlocks);
      return;
    }

    if (state.movePointerStart != null && state.moveRectOriginal != null) {
      final delta = canvasPoint - state.movePointerStart!;
      final newRect = state.moveRectOriginal!.translate(delta.dx, delta.dy);
      final newBlocks = List<TextBlockData>.from(state.textBlocks);
      final index = newBlocks.indexWhere((b) => b.id == state.selectedBlockId);
      if (index != -1) {
        newBlocks[index].boundingBox = newRect;
      }
      state = state.copyWith(textBlocks: newBlocks);
    }
  }

  void _onEditEnd() {
    if (state.moveRectOriginal != null && state.selectedBlock != null) {
      final current = state.selectedBlock!.boundingBox;
      final dx = (current.left - state.moveRectOriginal!.left).abs();
      final dy = (current.top - state.moveRectOriginal!.top).abs();
      if (dx < 3 && dy < 3) {
        final newBlocks = List<TextBlockData>.from(state.textBlocks);
        final index = newBlocks.indexWhere((b) => b.id == state.selectedBlockId);
        if (index != -1) {
          newBlocks[index].boundingBox = state.moveRectOriginal!;
        }
        state = state.copyWith(textBlocks: newBlocks);
      }
    }
    state = state.copyWith(
      clearActiveHandle: true,
      clearResizeOriginalRect: true,
      clearMovePointerStart: true,
      clearMoveRectOriginal: true,
      hasChanges: true,
    );
  }

  void _onDrawEnd() {
    if (state.currentDrawRect == null) return;

    final normalized = _normalizeRect(state.currentDrawRect!);
    if (normalized.width < 10 || normalized.height < 10) {
      state = state.copyWith(
        clearCurrentDrawRect: true,
        clearDrawStartPoint: true,
      );
      return;
    }

    final newBlock = TextBlockData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      boundingBox: normalized,
      text: '',
    );
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    newBlocks.add(newBlock);
    
    state = state.copyWith(
      textBlocks: newBlocks,
      selectedBlockId: newBlock.id,
      clearCurrentDrawRect: true,
      clearDrawStartPoint: true,
      mode: CanvasMode.edit,
      editSubMode: EditSubMode.move,
    );
  }

  String? _hitTestBlock(Offset point) {
    for (int i = state.textBlocks.length - 1; i >= 0; i--) {
      final block = state.textBlocks[i];
      if (block.isDeleted) continue;
      if (block.text.isNotEmpty && !_isEnglishText(block.text)) continue;
      if (block.boundingBox.contains(point)) {
        return block.id;
      }
    }
    return null;
  }

  HandlePosition? _hitTestHandle(Offset point) {
    final rect = state.selectedBlock?.boundingBox;
    if (rect == null) return null;

    final scale = transformController.value.getMaxScaleOnAxis().clamp(0.01, 100.0);
    final handleSize = (40.0 / scale).clamp(12.0, 80.0);
    final halfSize = handleSize / 2;

    final handles = {
      HandlePosition.topLeft: rect.topLeft,
      HandlePosition.topRight: rect.topRight,
      HandlePosition.bottomLeft: rect.bottomLeft,
      HandlePosition.bottomRight: rect.bottomRight,
      HandlePosition.top: Offset(rect.center.dx, rect.top),
      HandlePosition.bottom: Offset(rect.center.dx, rect.bottom),
      HandlePosition.left: Offset(rect.left, rect.center.dy),
      HandlePosition.right: Offset(rect.right, rect.center.dy),
    };

    for (final entry in handles.entries) {
      final handleRect = Rect.fromCenter(
        center: entry.value,
        width: handleSize,
        height: handleSize,
      );
      if (handleRect.contains(point)) {
        return entry.key;
      }
    }
    return null;
  }

  Rect _calculateResize(HandlePosition handle, Rect original, Offset point) {
    double left = original.left;
    double top = original.top;
    double right = original.right;
    double bottom = original.bottom;

    const minSize = 10.0;

    switch (handle) {
      case HandlePosition.topLeft:
        left = point.dx.clamp(0.0, right - minSize);
        top = point.dy.clamp(0.0, bottom - minSize);
        break;
      case HandlePosition.topRight:
        right = point.dx.clamp(left + minSize, state.canvasSize.width);
        top = point.dy.clamp(0.0, bottom - minSize);
        break;
      case HandlePosition.bottomLeft:
        left = point.dx.clamp(0.0, right - minSize);
        bottom = point.dy.clamp(top + minSize, state.canvasSize.height);
        break;
      case HandlePosition.bottomRight:
        right = point.dx.clamp(left + minSize, state.canvasSize.width);
        bottom = point.dy.clamp(top + minSize, state.canvasSize.height);
        break;
      case HandlePosition.top:
        top = point.dy.clamp(0.0, bottom - minSize);
        break;
      case HandlePosition.bottom:
        bottom = point.dy.clamp(top + minSize, state.canvasSize.height);
        break;
      case HandlePosition.left:
        left = point.dx.clamp(0.0, right - minSize);
        break;
      case HandlePosition.right:
        right = point.dx.clamp(left + minSize, state.canvasSize.width);
        break;
    }

    return Rect.fromLTRB(
      left.clamp(0.0, state.canvasSize.width),
      top.clamp(0.0, state.canvasSize.height),
      right.clamp(0.0, state.canvasSize.width),
      bottom.clamp(0.0, state.canvasSize.height),
    );
  }

  Rect _normalizeRect(Rect rect) {
    return Rect.fromLTRB(
      min(rect.left, rect.right).clamp(0.0, state.canvasSize.width),
      min(rect.top, rect.bottom).clamp(0.0, state.canvasSize.height),
      max(rect.left, rect.right).clamp(0.0, state.canvasSize.width),
      max(rect.top, rect.bottom).clamp(0.0, state.canvasSize.height),
    );
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

  void deleteSelectedBlock() {
    if (state.selectedBlockId == null) return;
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    final index = newBlocks.indexWhere((b) => b.id == state.selectedBlockId);
    if (index != -1) {
      newBlocks[index].isDeleted = true;
    }
    
    state = state.copyWith(
      textBlocks: newBlocks,
      clearSelectedBlockId: true,
      hasChanges: true,
    );
  }

  void updateBlockText(String blockId, String newText, {String? originalText, String? aiEnhancedText}) {
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    final index = newBlocks.indexWhere((b) => b.id == blockId);
    if (index != -1) {
      newBlocks[index].text = newText;
      if (originalText != null) newBlocks[index].originalText = originalText;
      if (aiEnhancedText != null) newBlocks[index].aiEnhancedText = aiEnhancedText;
    }
    state = state.copyWith(textBlocks: newBlocks, hasChanges: true);
  }

  Future<void> reRecognizeBlock(String blockId) async {
    if (state.imageFile == null) return;
    
    state = state.copyWith(isProcessing: true);

    try {
      final result = await OcrService.instance.recognizeText(state.imageFile!);
      
      if (result == null) {
        state = state.copyWith(isProcessing: false);
        return;
      }

      final block = state.textBlocks.firstWhere((b) => b.id == blockId);
      String bestMatch = '';
      double bestOverlap = 0;
      
      for (final r in result.blocks) {
        final intersect = block.boundingBox.intersect(r.boundingBox);
        if (!intersect.isEmpty) {
          final overlap = (intersect.width * intersect.height) / 
              ((block.boundingBox.width * block.boundingBox.height + r.boundingBox.width * r.boundingBox.height) / 2);
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            bestMatch = r.text;
          }
        }
      }
      
      if (bestMatch.isNotEmpty && bestOverlap > 0.3) {
        updateBlockText(blockId, bestMatch);
      }
      
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<int> aiEnhanceAll() async {
    final visibleBlocks = state.textBlocks.where((b) => !b.isDeleted).toList();
    if (visibleBlocks.isEmpty || state.imageFile == null) return 0;

    state = state.copyWith(isAiEnhancing: true, showAiBanner: true);

    try {
      final blocksData = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        visibleBlocks[i].originalText ??= visibleBlocks[i].text;
        blocksData.add({i: visibleBlocks[i].text});
      }

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        state.imageFile!,
        blocksData,
        state.currentAiModel,
        onProgress: (msg) {
          state = state.copyWith(aiBannerText: msg);
        },
      );

      int updatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final correctedText = correctedBlocks[i];
        if (correctedText != null) {
          visibleBlocks[i].aiEnhancedText = correctedText;
          visibleBlocks[i].text = correctedText;
          updatedCount++;
        }
      }

      state = state.copyWith(
        textBlocks: List<TextBlockData>.from(state.textBlocks),
        isAiEnhancing: false,
        showAiBanner: false,
        hasChanges: true,
      );

      return updatedCount;
    } catch (e) {
      state = state.copyWith(isAiEnhancing: false, showAiBanner: false);
      throw Exception('AI强化失败: ${e.toString().split('\n').first}');
    }
  }

  Future<bool> aiEnhanceSelectedBlock() async {
    if (state.selectedBlockId == null || state.imageFile == null) return false;

    state = state.copyWith(isAiEnhancing: true, showAiBanner: true);

    try {
      final block = state.selectedBlock!;
      block.originalText ??= block.text;

      final blocksData = [{0: block.text}];

      final correctedBlocks = await AiService.instance.enhanceTextBlocks(
        state.imageFile!,
        blocksData,
        state.currentAiModel,
        onProgress: (msg) {
          state = state.copyWith(aiBannerText: msg);
        },
      );

      final correctedText = correctedBlocks[0];
      final newBlocks = List<TextBlockData>.from(state.textBlocks);
      final index = newBlocks.indexWhere((b) => b.id == state.selectedBlockId);

      if (correctedText != null) {
        if (index != -1) {
          newBlocks[index].originalText ??= newBlocks[index].text;
          newBlocks[index].aiEnhancedText = correctedText;
          newBlocks[index].text = correctedText;
        }
        state = state.copyWith(
          textBlocks: newBlocks,
          isAiEnhancing: false,
          showAiBanner: false,
          hasChanges: true,
        );
        return true;
      } else {
        state = state.copyWith(
          isAiEnhancing: false,
          showAiBanner: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isAiEnhancing: false, showAiBanner: false);
      throw Exception('AI强化失败: $e');
    }
  }

  void setAiModel(String model) {
    state = state.copyWith(currentAiModel: model);
  }

  void setSpeechRate(double rate) {
    state = state.copyWith(speechRate: rate);
  }

  void setUseGlmTts(bool use) {
    state = state.copyWith(useGlmTts: use);
  }

  void clearChanges() {
    state = state.copyWith(hasChanges: false);
  }

  List<TextBlockData> getBlocksForSave() {
    return state.getVisibleBlocks();
  }

  void zoomIn() {
    final currentScale = transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.3).clamp(0.5, 4.0);
    final scaleRatio = newScale / currentScale;
    final newMatrix = transformController.value.clone();
    newMatrix.scale(scaleRatio, scaleRatio);
    transformController.value = newMatrix;
  }

  void zoomOut() {
    final currentScale = transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.3).clamp(0.5, 4.0);
    final scaleRatio = newScale / currentScale;
    final newMatrix = transformController.value.clone();
    newMatrix.scale(scaleRatio, scaleRatio);
    transformController.value = newMatrix;
  }

  void resetZoom() {
    transformController.value = Matrix4.identity();
  }
}

final textDetectionProvider = NotifierProvider.autoDispose<TextDetectionNotifier, TextDetectionState>(() {
  return TextDetectionNotifier();
});