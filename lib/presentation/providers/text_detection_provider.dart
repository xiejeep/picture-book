import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/text_block_model.dart';
import '../../data/repositories/service_repositories.dart';
import '../providers/repository_providers.dart';
import '../providers/settings_provider.dart';
import '../../core/constants/constants.dart';

class TextBlockData {
  Rect boundingBox;
  String text;
  bool isDeleted;

  TextBlockData({
    required this.boundingBox,
    required this.text,
    this.isDeleted = false,
  });
}

class TextDetectionState {
  final File? imageFile;
  final Size imageSize;
  final List<TextBlockData> textBlocks;
  final int? selectedIndex;
  final bool isProcessing;
  final bool isAiEnhancing;
  final String? errorMessage;
  final bool showOnlyEnglish;
  final bool drawMode;
  final Rect? tempRect;
  final bool hasChanges;
  final String currentAiModel;
  final bool isDragging;
  final bool isResizing;
  final HandlePosition? resizeHandle;
  final Offset? dragStartPoint;
  final Rect? dragStartRect;

  const TextDetectionState({
    this.imageFile,
    this.imageSize = Size.zero,
    this.textBlocks = const [],
    this.selectedIndex,
    this.isProcessing = false,
    this.isAiEnhancing = false,
    this.errorMessage,
    this.showOnlyEnglish = true,
    this.drawMode = false,
    this.tempRect,
    this.hasChanges = false,
    this.currentAiModel = AppConstants.defaultModel,
    this.isDragging = false,
    this.isResizing = false,
    this.resizeHandle,
    this.dragStartPoint,
    this.dragStartRect,
  });

  TextDetectionState copyWith({
    File? imageFile,
    Size? imageSize,
    List<TextBlockData>? textBlocks,
    int? selectedIndex,
    bool? isProcessing,
    bool? isAiEnhancing,
    String? errorMessage,
    bool? showOnlyEnglish,
    bool? drawMode,
    Rect? tempRect,
    bool? hasChanges,
    String? currentAiModel,
    bool? isDragging,
    bool? isResizing,
    HandlePosition? resizeHandle,
    Offset? dragStartPoint,
    Rect? dragStartRect,
    bool clearSelectedIndex = false,
    bool clearErrorMessage = false,
    bool clearTempRect = false,
    bool clearDragStartPoint = false,
    bool clearDragStartRect = false,
    bool clearResizeHandle = false,
  }) {
    return TextDetectionState(
      imageFile: imageFile ?? this.imageFile,
      imageSize: imageSize ?? this.imageSize,
      textBlocks: textBlocks ?? this.textBlocks,
      selectedIndex: clearSelectedIndex ? null : (selectedIndex ?? this.selectedIndex),
      isProcessing: isProcessing ?? this.isProcessing,
      isAiEnhancing: isAiEnhancing ?? this.isAiEnhancing,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      showOnlyEnglish: showOnlyEnglish ?? this.showOnlyEnglish,
      drawMode: drawMode ?? this.drawMode,
      tempRect: clearTempRect ? null : (tempRect ?? this.tempRect),
      hasChanges: hasChanges ?? this.hasChanges,
      currentAiModel: currentAiModel ?? this.currentAiModel,
      isDragging: isDragging ?? this.isDragging,
      isResizing: isResizing ?? this.isResizing,
      resizeHandle: clearResizeHandle ? null : (resizeHandle ?? this.resizeHandle),
      dragStartPoint: clearDragStartPoint ? null : (dragStartPoint ?? this.dragStartPoint),
      dragStartRect: clearDragStartRect ? null : (dragStartRect ?? this.dragStartRect),
    );
  }

  List<TextBlockData> getVisibleBlocks() {
    return textBlocks.where((block) {
      if (block.isDeleted) return false;
      if (showOnlyEnglish && !_isEnglishText(block.text)) return false;
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
}

enum HandlePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class TextDetectionNotifier extends Notifier<TextDetectionState> {
  final ImagePicker _picker = ImagePicker();

  @override
  TextDetectionState build() {
    return const TextDetectionState();
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    final File imageFile = File(pickedFile.path);
    final decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    
    state = state.copyWith(
      imageFile: imageFile,
      imageSize: Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      ),
      textBlocks: [],
      clearSelectedIndex: true,
      clearErrorMessage: true,
    );

    await recognizeText();
  }

  Future<void> recognizeText() async {
    if (state.imageFile == null) return;

    state = state.copyWith(isProcessing: true, clearErrorMessage: true);

    try {
      final result = await ref.read(ocrRepositoryProvider).recognizeText(state.imageFile!);
      
      if (result == null || result.isEmpty) {
        state = state.copyWith(
          errorMessage: '文字识别失败: 无法识别',
          isProcessing: false,
        );
        return;
      }
      
      final blocks = result.map((block) {
        return TextBlockData(
          boundingBox: block.boundingBox,
          text: block.text,
        );
      }).toList();
      
      state = state.copyWith(
        textBlocks: blocks,
        clearSelectedIndex: true,
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

  void selectBlock(int? index) {
    state = state.copyWith(selectedIndex: index);
  }

  void deleteSelectedBlock() {
    if (state.selectedIndex == null || state.selectedIndex! >= state.textBlocks.length) return;
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    newBlocks[state.selectedIndex!].isDeleted = true;
    
    state = state.copyWith(
      textBlocks: newBlocks,
      clearSelectedIndex: true,
      hasChanges: true,
    );
  }

  void restoreAllBlocks() {
    final newBlocks = state.textBlocks.map((block) {
      return TextBlockData(
        boundingBox: block.boundingBox,
        text: block.text,
        isDeleted: false,
      );
    }).toList();
    
    state = state.copyWith(
      textBlocks: newBlocks,
      clearSelectedIndex: true,
    );
  }

  void toggleEnglishFilter() {
    state = state.copyWith(
      showOnlyEnglish: !state.showOnlyEnglish,
      clearSelectedIndex: true,
    );
  }

  void toggleDrawMode() {
    state = state.copyWith(
      drawMode: !state.drawMode,
      clearSelectedIndex: true,
      clearTempRect: true,
    );
  }

  void updateBlockText(int index, String newText) {
    if (index < 0 || index >= state.textBlocks.length) return;
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    newBlocks[index].text = newText;
    
    state = state.copyWith(textBlocks: newBlocks, hasChanges: true);
  }

  void updateBlockRect(int index, Rect newRect) {
    if (index < 0 || index >= state.textBlocks.length) return;
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    newBlocks[index].boundingBox = newRect;
    
    state = state.copyWith(textBlocks: newBlocks);
  }

  void addNewBlock(Rect rect, String text) {
    final newBlock = TextBlockData(
      boundingBox: rect,
      text: text,
      isDeleted: false,
    );
    
    final newBlocks = List<TextBlockData>.from(state.textBlocks);
    newBlocks.add(newBlock);
    
    state = state.copyWith(
      textBlocks: newBlocks,
      selectedIndex: newBlocks.length - 1,
      clearTempRect: true,
      drawMode: false,
    );
  }

  void startDragging(Offset startPoint, Rect startRect) {
    state = state.copyWith(
      isDragging: true,
      dragStartPoint: startPoint,
      dragStartRect: startRect,
    );
  }

  void startResizing(HandlePosition handle, Offset startPoint, Rect startRect) {
    state = state.copyWith(
      isResizing: true,
      resizeHandle: handle,
      dragStartPoint: startPoint,
      dragStartRect: startRect,
    );
  }

  void endDragResize() {
    state = state.copyWith(
      isDragging: false,
      isResizing: false,
      clearResizeHandle: true,
      clearDragStartPoint: true,
      clearDragStartRect: true,
    );
  }

  void updateTempRect(Rect? rect) {
    state = state.copyWith(tempRect: rect);
  }

  Future<void> aiEnhanceBlocks() async {
    final visibleBlocks = state.getVisibleBlocks();
    if (visibleBlocks.isEmpty) return;

    state = state.copyWith(isAiEnhancing: true);

    try {
      final blocksData = <Map<int, String>>[];
      for (int i = 0; i < visibleBlocks.length; i++) {
        blocksData.add({i: visibleBlocks[i].text});
      }

      final correctedBlocks = await ref.read(aiRepositoryProvider).enhanceTextBlocks(
        state.imageFile!,
        blocksData,
        state.currentAiModel,
      );
      
      int updatedCount = 0;
      for (int i = 0; i < visibleBlocks.length; i++) {
        final correctedText = correctedBlocks[i];
        if (correctedText != null && correctedText != visibleBlocks[i].text) {
          visibleBlocks[i].text = correctedText;
          updatedCount++;
        }
      }

      state = state.copyWith(isAiEnhancing: false);
    } catch (e) {
      state = state.copyWith(isAiEnhancing: false);
      throw Exception('AI强化失败: $e');
    }
  }

  Future<void> aiEnhanceSelectedBlock() async {
    if (state.selectedIndex == null || state.selectedIndex! >= state.textBlocks.length) return;

    state = state.copyWith(isAiEnhancing: true);

    try {
      final block = state.textBlocks[state.selectedIndex!];
      final blocksData = [{0: block.text}];

      final correctedBlocks = await ref.read(aiRepositoryProvider).enhanceTextBlocks(
        state.imageFile!,
        blocksData,
        state.currentAiModel,
      );

      final correctedText = correctedBlocks[0];
      if (correctedText != null) {
        updateBlockText(state.selectedIndex!, correctedText);
      }

      state = state.copyWith(isAiEnhancing: false);
    } catch (e) {
      state = state.copyWith(isAiEnhancing: false);
      throw Exception('AI强化失败: $e');
    }
  }

  void setAiModel(String model) {
    state = state.copyWith(currentAiModel: model);
  }

  void clearChanges() {
    state = state.copyWith(hasChanges: false);
  }

  List<TextBlockData> getBlocksForSave() {
    return state.getVisibleBlocks();
  }
}

final textDetectionProvider = NotifierProvider<TextDetectionNotifier, TextDetectionState>(() {
  return TextDetectionNotifier();
});