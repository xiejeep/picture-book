import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/constants/app_prompts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/toast_util.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../data/services/ai_service.dart';
import '../../../../data/services/tts_service.dart';
import '../../../../data/services/ocr_service.dart';
import '../../../pages/ocr/ocr_results_page.dart';
import '../models/text_block_data.dart';
import '../models/canvas_mode.dart';
import '../models/text_detection_state.dart';
import '../view_models/text_detection_viewmodel.dart';
import 'text_block_painter.dart';
import '../widgets/bottom_toolbar.dart';

part 'text_detection_dialogs.dart';

class TextDetectionView extends ConsumerStatefulWidget {
  final Function(List<TextBlockData>, File)? onSave;
  final File? initialImageFile;
  final List<dynamic>? initialTextBlocks;

  const TextDetectionView({
    super.key,
    this.onSave,
    this.initialImageFile,
    this.initialTextBlocks,
  });

  @override
  ConsumerState<TextDetectionView> createState() => _TextDetectionViewState();
}

class _TextDetectionViewState extends ConsumerState<TextDetectionView>
    with _TextDetectionDialogs {
  final GlobalKey _viewerKey = GlobalKey();
  bool _imageFitted = false;
  String? _lastSelectedBlockId;
  bool _editDialogShown = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initialize();
    _loadInitialData();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (widget.initialImageFile != null) {
      final notifier = ref.read(textDetectionProvider.notifier);
      await notifier.loadInitialData(
        widget.initialImageFile!,
        widget.initialTextBlocks,
      );
    }
  }

  void _fitImageToViewport() {
    final renderBox =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || renderBox.size.isEmpty) return;

    final notifier = ref.read(textDetectionProvider.notifier);
    notifier.fitToScreen(renderBox.size);
    _imageFitted = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(textDetectionProvider);
    final notifier = ref.read(textDetectionProvider.notifier);
    final visibleBlocks = state.getVisibleBlocks();

    if (state.backgroundImage != null && !_imageFitted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _fitImageToViewport());
    }
    if (state.backgroundImage == null) {
      _imageFitted = false;
    }

    _checkForNewEmptyBlock(state);

    return PopScope(
      canPop: !state.hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final result = await showUnsavedDialog(state, notifier);
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(state, notifier, visibleBlocks),
        body: _buildBody(state, notifier, visibleBlocks),
      ),
    );
  }

  void _checkForNewEmptyBlock(TextDetectionState state) {
    if (state.selectedBlockId != _lastSelectedBlockId) {
      _lastSelectedBlockId = state.selectedBlockId;
      _editDialogShown = false;

      final block = state.selectedBlock;
      if (block != null && block.text.isEmpty && !_editDialogShown) {
        _editDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          editSelectedBlock(state);
        });
      }
    }
  }

  PreferredSizeWidget _buildAppBar(
    TextDetectionState state,
    TextDetectionNotifier notifier,
    List<TextBlockData> visibleBlocks,
  ) {
    return AppBar(
      title: const Text('识别'),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppTheme.appBarGradientOf(context)),
      ),
      actions: [
        if (state.backgroundImage != null)
          IconButton(
            icon: Icon(Icons.help_outline,
                color: Theme.of(context).colorScheme.onPrimary),
            onPressed: () => showHelpDialog(),
            tooltip: '操作指南',
          ),
        if (state.isAiEnhancing)
          const SizedBox.shrink()
        else ...[
          if (state.backgroundImage != null && visibleBlocks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.table_chart,
                  color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => _navigateToResultsTable(state, visibleBlocks),
              tooltip: '查看结果表格',
            ),
          if (widget.onSave != null &&
              state.imageFile != null &&
              visibleBlocks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.save,
                  color: Theme.of(context).colorScheme.onPrimary),
              onPressed: () => _saveToBook(state, notifier),
              tooltip: '保存到读本',
            ),
          _buildPopupMenu(state, notifier, visibleBlocks),
        ],
      ],
    );
  }

  Widget _buildPopupMenu(
    TextDetectionState state,
    TextDetectionNotifier notifier,
    List<TextBlockData> visibleBlocks,
  ) {
    final hasSelectedBlock = state.selectedBlockId != null;
    return PopupMenuButton<String>(
      icon:
          Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onPrimary),
      tooltip: '更多操作',
      onSelected: (value) => _handleMenuAction(value, state, notifier),
      itemBuilder: (context) => [
        if (state.backgroundImage != null && !state.isAiEnhancing)
          PopupMenuItem(
            value: 'select_model',
            child: Row(
              children: [
                Icon(Icons.psychology,
                    size: 20, color: AppTheme.primaryOf(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('选择AI模型'),
                      Text(
                        '当前: ${AppConstants.availableModels.firstWhere(
                          (m) => m['name'] == state.currentAiModel,
                          orElse: () => AppConstants.availableModels.first,
                        )['label']}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (state.backgroundImage != null)
          PopupMenuItem(
            value: 'voice_settings',
            child: Row(
              children: [
                Icon(Icons.record_voice_over_rounded,
                    size: 20, color: AppTheme.primaryOf(context)),
                const SizedBox(width: 8),
                const Text('语音设置'),
              ],
            ),
          ),
        if (hasSelectedBlock) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 're_recognize',
            child: Row(
              children: [
                Icon(Icons.refresh,
                    size: 20, color: AppTheme.primaryOf(context)),
                const SizedBox(width: 8),
                const Text('重新识别此区域'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'ai_enhance_selected',
            child: Row(
              children: [
                Icon(Icons.auto_fix_high,
                    size: 20, color: AppTheme.accentOf(context)),
                const SizedBox(width: 8),
                const Text('AI强化此区域'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(
    TextDetectionState state,
    TextDetectionNotifier notifier,
    List<TextBlockData> visibleBlocks,
  ) {
    if (state.backgroundImage == null) {
      return _buildEmptyState(notifier);
    }

    return SafeArea(
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: state.isAiEnhancing,
            child: Opacity(
              opacity: state.isAiEnhancing ? 0.6 : 1.0,
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return InteractiveViewer(
                        key: _viewerKey,
                        transformationController: notifier.transformController,
                        panEnabled: false,
                        scaleEnabled: false,
                        constrained: false,
                        minScale: 0.1,
                        maxScale: 10.0,
                        child: SizedBox(
                          width: state.canvasSize.width,
                          height: state.canvasSize.height,
                          child: Listener(
                            onPointerDown: (event) {
                              if (_tryDeleteButtonTap(
                                  state, notifier, event.localPosition)) {
                                return;
                              }
                              notifier.onPointerDown(event.localPosition);
                            },
                            child: GestureDetector(
                              onScaleStart: (_) => notifier.onScaleStart(),
                              onScaleUpdate: (details) =>
                                  notifier.onScaleUpdate(details),
                              onScaleEnd: (_) => notifier.onScaleEnd(),
                              child: CustomPaint(
                                size: state.canvasSize,
                                painter: TextBlockPainter(
                                  state: state,
                                  transformController:
                                      notifier.transformController,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  BottomToolbar(
                    notifier: notifier,
                    onPlay: () => _playSelectedBlock(state),
                    onEdit: () => editSelectedBlock(state),
                    onDelete: () => confirmDeleteBlock(state, notifier),
                    onAiEnhanceAll: () => showAiEnhanceAllDialog(notifier),
                    onReRecognizeAll: () => showReRecognizeAllDialog(notifier),
                  ),
                ],
              ),
            ),
          ),
          if (state.isProcessing) _buildProcessingBanner('正在识别文字...'),
          if (state.showAiBanner)
            _buildProcessingBanner(state.aiBannerText, Colors.purple),
          if (state.mode == CanvasMode.draw) _buildModeBanner('绘制模式：拖动绘制矩形'),
          if (state.errorMessage != null)
            _buildErrorBanner(state.errorMessage!),
          if (visibleBlocks.isEmpty && state.textBlocks.isNotEmpty)
            _buildInfoBanner('未找到英文文字'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextDetectionNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('请选择或拍摄图片'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => notifier.pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('从相册选择'),
          ),
          if (!PlatformUtils.isMacOS) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => notifier.pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingBanner(String text, [Color color = Colors.orange]) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeBanner(String text) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOf(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.draw, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(
    String action,
    TextDetectionState state,
    TextDetectionNotifier notifier,
  ) {
    switch (action) {
      case 'select_model':
        showModelSelectionDialog(state, notifier);
        break;
      case 'voice_settings':
        _showVoiceSettingsDialog();
        break;
      case 're_recognize':
        showReRecognizeSelectedBlock(state, notifier);
        break;
      case 'ai_enhance_selected':
        showAiEnhanceSelectedDialog(state, notifier);
        break;
    }
  }

  bool _tryDeleteButtonTap(
    TextDetectionState state,
    TextDetectionNotifier notifier,
    Offset canvasPoint,
  ) {
    if (state.mode != CanvasMode.edit) return false;
    final block = state.selectedBlock;
    if (block == null) return false;

    final scale = notifier.transformController.value
        .getMaxScaleOnAxis()
        .clamp(0.01, 100.0);
    final buttonSize = (24.0 / scale).clamp(16.0, 40.0);
    final deletePos = Offset(
      block.boundingBox.right + buttonSize / 2,
      block.boundingBox.top - buttonSize / 2,
    );
    final hitRect = Rect.fromCenter(
      center: deletePos,
      width: buttonSize * 1.5,
      height: buttonSize * 1.5,
    );

    if (hitRect.contains(canvasPoint)) {
      confirmDeleteBlock(state, notifier);
      return true;
    }
    return false;
  }

  Future<void> _navigateToResultsTable(
    TextDetectionState state,
    List<TextBlockData> visibleBlocks,
  ) async {
    final result = await Navigator.push<List<TextBlockData>>(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultsTablePage(
          textBlocks: List.from(visibleBlocks),
          imageFile: state.imageFile,
        ),
      ),
    );

    if (result != null) {
      final notifier = ref.read(textDetectionProvider.notifier);
      for (final updated in result) {
        notifier.updateBlockText(
          updated.id,
          updated.text,
          originalText: updated.originalText,
          aiEnhancedText: updated.aiEnhancedText,
          translatedText: updated.translatedText,
          aiTranslatedText: updated.aiTranslatedText,
          isDeleted: updated.isDeleted,
        );
      }
    }
  }

  void _saveToBook(TextDetectionState state, TextDetectionNotifier notifier) {
    if (widget.onSave == null || state.imageFile == null) return;

    final visibleBlocks = notifier.getBlocksForSave();
    if (visibleBlocks.isEmpty) {
      ToastUtil.warning('没有可保存的文字块');
      return;
    }

    notifier.clearChanges();
    widget.onSave!(visibleBlocks, state.imageFile!);
  }

  void _playSelectedBlock(TextDetectionState state) {
    final block = state.selectedBlock;
    if (block == null) return;
    TtsService.instance.speak(block.text);
  }

  void _showVoiceSettingsDialog() {
    context.push('/settings/voice');
  }
}
