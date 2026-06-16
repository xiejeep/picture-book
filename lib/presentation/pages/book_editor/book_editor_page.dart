import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/text_block_model.dart';
import '../../../data/services/ai_service.dart';
import '../../../data/services/ocr_service.dart';
import '../../../data/services/tts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/toast_util.dart';
import '../../features/text_detection/models/text_block_data.dart';
import '../../features/text_detection/models/handle_position.dart';
import '../../providers/settings_provider.dart';
import 'book_editor_state.dart';
import 'book_editor_painter.dart';
import 'book_editor_toolbar.dart';
import '../ocr/ocr_results_page.dart';

class BookEditorPage extends ConsumerStatefulWidget {
  final String bookId;
  final int pageIndex;
  final File imageFile;
  final List<TextBlockModel> initialBlocks;

  const BookEditorPage({
    super.key,
    required this.bookId,
    required this.pageIndex,
    required this.imageFile,
    required this.initialBlocks,
  });

  @override
  ConsumerState<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends ConsumerState<BookEditorPage> {
  late BookEditorState _state;
  Matrix4 _transform = Matrix4.identity();
  bool _imageFitted = false;
  bool _fitRequested = false;
  Size _layoutSize = Size.zero;

  bool _gestureMoved = false;
  Offset? _gestureStartPoint;

  Matrix4? _scaleStartMatrix;
  bool _isZooming = false;
  Offset? _dragStartScreen;
  Matrix4? _panStartMatrix;
  String _currentAiModel = AppConstants.defaultModel;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initialize();
    _state = const BookEditorState();
    _currentAiModel = ref.read(selectedModelProvider);
    _loadImage();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final hasInitialBlocks = widget.initialBlocks.isNotEmpty;
    final blocks = hasInitialBlocks
        ? widget.initialBlocks
            .map((b) => TextBlockData(
                  id: b.id,
                  boundingBox: b.boundingBox,
                  text: b.text,
                  isDeleted: b.isDeleted,
                  originalText: b.originalText,
                  aiEnhancedText: b.aiEnhancedText,
                  translatedText: b.translatedText,
                  aiTranslatedText: b.aiTranslatedText,
                ))
            .toList()
        : <TextBlockData>[];

    setState(() {
      _state = BookEditorState(
        imageFile: widget.imageFile,
        backgroundImage: image,
        canvasSize: Size(image.width.toDouble(), image.height.toDouble()),
        textBlocks: blocks,
        isProcessing: !hasInitialBlocks,
      );
    });

    if (!hasInitialBlocks) {
      await _runOcr();
    }
  }

  Future<void> _reOcr() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新OCR'),
        content: const Text('将清除所有现有文字块并重新识别，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _state = _state.copyWith(isProcessing: true));
    await _runOcr();
  }

  Future<void> _runOcr() async {
    try {
      final result = await OcrService.instance.recognizeText(widget.imageFile);
      if (result != null && result.blocks.isNotEmpty) {
        final blocks = result.blocks.map((block) {
          final inflatedRect = block.boundingBox.inflate(6.0);
          final clampedRect = Rect.fromLTRB(
            inflatedRect.left.clamp(0.0, _state.canvasSize.width),
            inflatedRect.top.clamp(0.0, _state.canvasSize.height),
            inflatedRect.right.clamp(0.0, _state.canvasSize.width),
            inflatedRect.bottom.clamp(0.0, _state.canvasSize.height),
          );
          return TextBlockData(
            id: const Uuid().v4(),
            boundingBox: clampedRect,
            text: block.text,
          );
        }).toList();
        if (mounted) {
          setState(() {
            _state = _state.copyWith(
              textBlocks: blocks,
              isProcessing: false,
              hasChanges: true,
            );
          });
        }
      } else {
        if (mounted) {
          setState(() => _state = _state.copyWith(isProcessing: false));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _state = _state.copyWith(isProcessing: false));
      }
    }
  }

  void _fitTransform(Size available) {
    final imageSize = _state.canvasSize;
    if (imageSize.isEmpty) return;
    final availableHeight = available.height - 160;
    final scaleX = available.width / imageSize.width;
    final scaleY = availableHeight / imageSize.height;
    final scale = min(scaleX, scaleY) * 0.9;
    final ox = (available.width - imageSize.width * scale) / 2;
    final oy = (availableHeight - imageSize.height * scale) / 2;

    _transform = Matrix4.identity()
      ..translate(ox, oy)
      ..scale(scale, scale);
    _imageFitted = true;
    _fitRequested = false;
    setState(() {});
  }

  Offset _screenToCanvas(Offset screen) {
    final m = _transform.clone()..invert();
    return MatrixUtils.transformPoint(m, screen);
  }

  // Gesture: tap

  void _onTapUp(TapUpDetails details) {
    final canvas = _screenToCanvas(details.localPosition);
    _handleTap(canvas);
  }

  void _handleTap(Offset canvasPoint) {
    if (_state.isDrawing) {
      setState(() => _state = _state.copyWith(isDrawing: false));
      ToastUtil.info('已取消绘制');
      return;
    }

    final hitId = _hitTestBlock(canvasPoint);
    if (hitId != null) {
      setState(() {
        _state = _state.copyWith(
          selectedBlockId: hitId == _state.selectedBlockId ? null : hitId,
        );
      });
    } else {
      setState(() => _state = _state.copyWith(clearSelectedBlockId: true));
    }
  }

  // Gesture: scale / drag

  void _onScaleStart(ScaleStartDetails details) {
    _gestureMoved = false;
    _isZooming = false;
    _gestureStartPoint = _screenToCanvas(details.localFocalPoint);

    if (details.pointerCount >= 2) {
      _isZooming = true;
      _scaleStartMatrix = _transform.clone();
      return;
    }

    if (_state.selectedBlock != null) {
      final handle = _hitTestHandle(_gestureStartPoint!);
      if (handle != null) {
        setState(() {
          _state = _state.copyWith(
            activeHandle: handle,
            resizeOriginalRect: _state.selectedBlock!.boundingBox,
          );
        });
        return;
      }
    }

    if (_state.isDrawing) {
      setState(() {
        _state = _state.copyWith(
          drawStartPoint: _gestureStartPoint,
          currentDrawRect:
              Rect.fromPoints(_gestureStartPoint!, _gestureStartPoint!),
        );
      });
      return;
    }

    final hitId = _hitTestBlock(_gestureStartPoint!);
    if (hitId != null) {
      final hitBlock = _state.textBlocks.firstWhere((b) => b.id == hitId);
      setState(() {
        _state = _state.copyWith(
          selectedBlockId: hitId,
          movePointerStart: _gestureStartPoint,
          moveRectOriginal: hitBlock.boundingBox,
        );
      });
      return;
    }

    // Single-finger pan
    _dragStartScreen = details.localFocalPoint;
    _panStartMatrix = _transform.clone();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final moving = details.pointerCount >= 2
        ? details.localFocalPoint
        : _screenToCanvas(details.localFocalPoint);
    if (!_gestureMoved &&
        _gestureStartPoint != null &&
        (moving - _gestureStartPoint!).distance > 5) {
      _gestureMoved = true;
    }

    if (_isZooming && _scaleStartMatrix != null && details.pointerCount >= 2) {
      final focal = details.localFocalPoint;
      final s = details.scale.clamp(0.1, 10.0);
      final zoom = Matrix4.identity()
        ..translate(focal.dx, focal.dy)
        ..scale(s, s)
        ..translate(-focal.dx, -focal.dy);
      _transform = _scaleStartMatrix!.multiplied(zoom);
      setState(() {});
      return;
    }

    if (_state.activeHandle != null && _state.resizeOriginalRect != null) {
      final cp = _screenToCanvas(details.localFocalPoint);
      final newRect = _calculateResize(
          _state.activeHandle!, _state.resizeOriginalRect!, cp);
      _state = _state.copyWith(
        textBlocks: _state.textBlocks
            .map((b) => b.id == _state.selectedBlockId
                ? b.copyWith(boundingBox: newRect)
                : b)
            .toList(),
      );
      setState(() {});
      return;
    }

    if (_state.movePointerStart != null && _state.moveRectOriginal != null) {
      final cp = _screenToCanvas(details.localFocalPoint);
      final delta = cp - _state.movePointerStart!;
      final newRect = _state.moveRectOriginal!.translate(delta.dx, delta.dy);
      _state = _state.copyWith(
        textBlocks: _state.textBlocks
            .map((b) => b.id == _state.selectedBlockId
                ? b.copyWith(boundingBox: newRect)
                : b)
            .toList(),
      );
      setState(() {});
      return;
    }

    if (_state.drawStartPoint != null) {
      final cp = _screenToCanvas(details.localFocalPoint);
      _state = _state.copyWith(
        currentDrawRect: Rect.fromPoints(_state.drawStartPoint!, cp),
      );
      setState(() {});
      return;
    }

    // Pan
    if (_panStartMatrix != null && _dragStartScreen != null) {
      final delta = details.localFocalPoint - _dragStartScreen!;
      final m = _panStartMatrix!.clone();
      m.translate(delta.dx, delta.dy);
      _transform = m;
      setState(() {});
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _scaleStartMatrix = null;
    _isZooming = false;
    _dragStartScreen = null;
    _panStartMatrix = null;

    if (!_gestureMoved) {
      // handled by _onTapUp
      _resetGestureState();
      return;
    }

    if (_state.moveRectOriginal != null && _state.selectedBlock != null) {
      final cur = _state.selectedBlock!.boundingBox;
      if ((cur.left - _state.moveRectOriginal!.left).abs() < 3 &&
          (cur.top - _state.moveRectOriginal!.top).abs() < 3) {
        _state = _state.copyWith(
          textBlocks: _state.textBlocks
              .map((b) => b.id == _state.selectedBlockId
                  ? b.copyWith(boundingBox: _state.moveRectOriginal!)
                  : b)
              .toList(),
        );
      }
      if (_state.moveRectOriginal != null) {
        _state = _state.copyWith(hasChanges: true);
      }
    }

    if (_state.drawStartPoint != null) {
      _finishDrawing();
    }

    _resetGestureState();
  }

  void _resetGestureState() {
    setState(() {
      _state = _state.copyWith(
        clearActiveHandle: true,
        clearResizeOriginalRect: true,
        clearMovePointerStart: true,
        clearMoveRectOriginal: true,
        clearDrawStartPoint: _state.isDrawing ? false : true,
        clearCurrentDrawRect: _state.isDrawing ? false : true,
      );
    });
  }

  void _finishDrawing() {
    final n = _normalizeRect(_state.currentDrawRect!);
    if (n.width < 10 || n.height < 10) {
      setState(() {
        _state = _state.copyWith(
          isDrawing: false,
          clearCurrentDrawRect: true,
          clearDrawStartPoint: true,
        );
      });
      return;
    }

    final newBlock = TextBlockData(
      id: const Uuid().v4(),
      boundingBox: n,
      text: '',
    );
    _state = _state.copyWith(
      textBlocks: [..._state.textBlocks, newBlock],
      selectedBlockId: newBlock.id,
      isDrawing: false,
      clearCurrentDrawRect: true,
      clearDrawStartPoint: true,
      hasChanges: true,
    );
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editSelectedBlockText();
    });
  }

  // Hit testing

  String? _hitTestBlock(Offset point) {
    for (int i = _state.textBlocks.length - 1; i >= 0; i--) {
      final b = _state.textBlocks[i];
      if (b.isDeleted) continue;
      if (b.boundingBox.contains(point)) return b.id;
    }
    return null;
  }

  HandlePosition? _hitTestHandle(Offset point) {
    final rect = _state.selectedBlock?.boundingBox;
    if (rect == null) return null;

    final s = _transform.getMaxScaleOnAxis().clamp(0.01, 100.0);
    final hs = (40.0 / s).clamp(12.0, 80.0);

    final handles = <HandlePosition, Offset>{
      HandlePosition.topLeft: rect.topLeft,
      HandlePosition.topRight: rect.topRight,
      HandlePosition.bottomLeft: rect.bottomLeft,
      HandlePosition.bottomRight: rect.bottomRight,
      HandlePosition.top: Offset(rect.center.dx, rect.top),
      HandlePosition.bottom: Offset(rect.center.dx, rect.bottom),
      HandlePosition.left: Offset(rect.left, rect.center.dy),
      HandlePosition.right: Offset(rect.right, rect.center.dy),
    };

    for (final e in handles.entries) {
      if (Rect.fromCenter(center: e.value, width: hs, height: hs)
          .contains(point)) return e.key;
    }
    return null;
  }

  Rect _calculateResize(HandlePosition handle, Rect original, Offset point) {
    double l = original.left, t = original.top;
    double r = original.right, b = original.bottom;
    const minSize = 10.0;
    final cw = _state.canvasSize.width;
    final ch = _state.canvasSize.height;

    switch (handle) {
      case HandlePosition.topLeft:
        l = point.dx.clamp(0.0, r - minSize);
        t = point.dy.clamp(0.0, b - minSize);
        continue topRight;
      topRight:
      case HandlePosition.topRight:
        r = point.dx.clamp(l + minSize, cw);
        t = point.dy.clamp(0.0, b - minSize);
        continue bottomLeft;
      bottomLeft:
      case HandlePosition.bottomLeft:
        l = point.dx.clamp(0.0, r - minSize);
        b = point.dy.clamp(t + minSize, ch);
        continue bottomRight;
      bottomRight:
      case HandlePosition.bottomRight:
        r = point.dx.clamp(l + minSize, cw);
        b = point.dy.clamp(t + minSize, ch);
        break;
      case HandlePosition.top:
        t = point.dy.clamp(0.0, b - minSize);
        break;
      case HandlePosition.bottom:
        b = point.dy.clamp(t + minSize, ch);
        break;
      case HandlePosition.left:
        l = point.dx.clamp(0.0, r - minSize);
        break;
      case HandlePosition.right:
        r = point.dx.clamp(l + minSize, cw);
        break;
    }

    return Rect.fromLTRB(
      l.clamp(0.0, cw),
      t.clamp(0.0, ch),
      r.clamp(0.0, cw),
      b.clamp(0.0, ch),
    );
  }

  Rect _normalizeRect(Rect rect) {
    final cw = _state.canvasSize.width;
    final ch = _state.canvasSize.height;
    return Rect.fromLTRB(
      min(rect.left, rect.right).clamp(0.0, cw),
      min(rect.top, rect.bottom).clamp(0.0, ch),
      max(rect.left, rect.right).clamp(0.0, cw),
      max(rect.top, rect.bottom).clamp(0.0, ch),
    );
  }

  // Actions

  void _editSelectedBlockText() {
    final block = _state.selectedBlock;
    if (block == null) return;

    final controller = TextEditingController(text: block.text);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isRecognizing = false;

          Future<void> reRecognize() async {
            setDialogState(() => isRecognizing = true);
            try {
              final text = await OcrService.instance
                  .recognizeTextInRegion(widget.imageFile, block.boundingBox);
              if (text != null && text.isNotEmpty) {
                controller.text = text;
                controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: text.length));
              }
            } catch (_) {
              if (ctx.mounted) {
                ToastUtil.error('识别失败');
              }
            }
            if (ctx.mounted) setDialogState(() => isRecognizing = false);
          }

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('编辑文字',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    maxLines: 3,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  if (isRecognizing)
                    const Row(
                      children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('正在识别...',
                            style: TextStyle(fontSize: 13)),
                      ],
                    )
                  else
                    TextButton.icon(
                      onPressed: reRecognize,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重新识别此区域'),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4)),
                    ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () {
                          _state = _state.copyWith(
                            textBlocks: _state.textBlocks
                                .map((b) => b.id == block.id
                                    ? b.copyWith(text: controller.text)
                                    : b)
                                .toList(),
                            hasChanges: true,
                          );
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('确定')),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteSelectedBlock() {
    final block = _state.selectedBlock;
    if (block == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('删除文字块',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context))),
            const SizedBox(height: 12),
            Text('确定删除该文字块吗？',
                style: TextStyle(
                    fontSize: 14,
                    color:
                        AppTheme.onSurfaceOf(context).withValues(alpha: 0.7))),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              const SizedBox(width: 8),
              ElevatedButton(
                  onPressed: () {
                    _state = _state.copyWith(
                      textBlocks: _state.textBlocks
                          .map((b) => b.id == block.id
                              ? b.copyWith(isDeleted: true)
                              : b)
                          .toList(),
                      clearSelectedBlockId: true,
                      hasChanges: true,
                    );
                    setState(() {});
                    ToastUtil.info('文字块已删除');
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  child: const Text('删除')),
            ]),
          ]),
        ),
      ),
    );
  }

  void _playSelectedBlock() {
    final block = _state.selectedBlock;
    if (block == null || block.text.isEmpty) return;
    TtsService.instance.speak(block.text);
  }

  void _toggleDrawing() {
    setState(() {
      _state = _state.copyWith(
        isDrawing: !_state.isDrawing,
        clearSelectedBlockId: true,
      );
    });
    if (_state.isDrawing) {
      ToastUtil.info('在画布上拖动绘制文字区域');
    }
  }

  Future<void> _aiEnhanceAll() async {
    final visible = _state.textBlocks.where((b) => !b.isDeleted).toList();
    if (visible.isEmpty) return;

    setState(() => _state = _state.copyWith(isProcessing: true));

    try {
      final blocksData = visible.map((b) => {0: b.text}).toList();
      final corrected = await AiService.instance.enhanceTextBlocks(
        widget.imageFile,
        blocksData,
        'glm-4v-flash',
      );

      int count = 0;
      var blocks = _state.textBlocks;
      for (int i = 0; i < visible.length; i++) {
        if (corrected[i] != null) {
          count++;
          blocks = blocks
              .map((b) => b.id == visible[i].id
                  ? b.copyWith(
                      aiEnhancedText: corrected[i],
                      text: corrected[i],
                      originalText: b.originalText ?? b.text,
                      clearTranslatedText: true,
                      clearAiTranslatedText: true,
                    )
                  : b)
              .toList();
        }
      }

      setState(() {
        _state = _state.copyWith(
          textBlocks: blocks,
          isProcessing: false,
          hasChanges: true,
        );
      });
      if (mounted) ToastUtil.success('已强化 $count 个文字块');
    } catch (_) {
      setState(() => _state = _state.copyWith(isProcessing: false));
      if (mounted) ToastUtil.error('AI强化失败');
    }
  }

  void _saveAndReturn() {
    final visible = _state.textBlocks.where((b) => !b.isDeleted).toList();
    final models = visible
        .map((b) => TextBlockModel.fromData(
              boundingBox: b.boundingBox,
              text: b.text,
              isDeleted: b.isDeleted,
              originalText: b.originalText,
              aiEnhancedText: b.aiEnhancedText,
              translatedText: b.translatedText,
              aiTranslatedText: b.aiTranslatedText,
              id: b.id,
            ))
        .toList();
    Navigator.pop(context, models);
  }

  Future<bool> _confirmExit() async {
    if (!_state.hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('有未保存的修改',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('退出将丢失所有更改'),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('留在当前页')),
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('放弃修改')),
            ]),
          ]),
        ),
      ),
    );
    return result ?? false;
  }

  void _zoomIn() {
    final s = _transform.getMaxScaleOnAxis();
    _applyZoom(s, (s * 1.3).clamp(0.5, 4.0));
  }

  void _zoomOut() {
    final s = _transform.getMaxScaleOnAxis();
    _applyZoom(s, (s / 1.3).clamp(0.5, 4.0));
  }

  void _applyZoom(double cur, double next) {
    final ratio = next / cur;
    final center = Offset(_layoutSize.width / 2, _layoutSize.height / 2);
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(ratio, ratio)
      ..translate(-center.dx, -center.dy);
    _transform = m.multiplied(_transform);
    setState(() {});
  }

  void _resetZoom() {
    _imageFitted = false;
    _fitTransform(_layoutSize);
  }

  Future<void> _navigateToResultsTable() async {
    final visible = _state.textBlocks.where((b) => !b.isDeleted).toList();
    if (visible.isEmpty) return;
    final result = await Navigator.push<List<TextBlockData>>(
      context,
      MaterialPageRoute(
        builder: (context) => OcrResultsTablePage(
          textBlocks: List.from(visible),
          imageFile: _state.imageFile,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _state = _state.copyWith(
          textBlocks: _state.textBlocks.map((b) {
            final updated = result.where((r) => r.id == b.id).firstOrNull;
            return updated ?? b;
          }).toList(),
          hasChanges: true,
        );
      });
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'select_model':
        _showModelSelectionDialog();
      case 'voice_settings':
        _showVoiceSettingsDialog();
      case 'ai_enhance_selected':
        _aiEnhanceSelectedBlock();
    }
  }

  Future<void> _showModelSelectionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择AI强化模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.availableModels.map((model) {
              final isSelected = _currentAiModel == model['name'];
              final isFree = model['free'] == 'true';
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? AppTheme.primaryOf(context) : Colors.grey,
                ),
                title: Text(model['label']!),
                subtitle: isFree
                    ? const Text('免费大模型', style: TextStyle(fontSize: 12))
                    : const Text('付费大模型',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                selected: isSelected,
                onTap: () => Navigator.pop(context, model['name']),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _currentAiModel = result);
    }
  }

  void _showVoiceSettingsDialog() {
    context.push('/settings/voice');
  }

  Future<void> _aiEnhanceSelectedBlock() async {
    final block = _state.selectedBlock;
    if (block == null) return;
    setState(() => _state = _state.copyWith(isProcessing: true));
    try {
      final blocksData = [{0: block.text}];
      final corrected = await AiService.instance.enhanceTextBlocks(
        widget.imageFile,
        blocksData,
        _currentAiModel,
      );
      if (corrected[0] != null) {
        final blocks = _state.textBlocks
            .map((b) => b.id == block.id
                ? b.copyWith(
                    aiEnhancedText: corrected[0],
                    text: corrected[0],
                    originalText: b.originalText ?? b.text,
                    clearTranslatedText: true,
                    clearAiTranslatedText: true,
                  )
                : b)
            .toList();
        setState(() {
          _state = _state.copyWith(
            textBlocks: blocks,
            isProcessing: false,
            hasChanges: true,
          );
        });
        ToastUtil.success('已强化选中文字块');
      } else {
        setState(() => _state = _state.copyWith(isProcessing: false));
        ToastUtil.error('AI强化失败');
      }
    } catch (_) {
      setState(() => _state = _state.copyWith(isProcessing: false));
      ToastUtil.error('AI强化失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_state.hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmExit();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('编辑第 ${widget.pageIndex + 1} 页'),
          flexibleSpace: Container(
            decoration:
                BoxDecoration(gradient: AppTheme.appBarGradientOf(context)),
          ),
          actions: [
            if (_state.textBlocks.isNotEmpty)
              IconButton(
                icon: Icon(Icons.table_chart,
                    color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _navigateToResultsTable,
                tooltip: '查看结果表格',
              ),
                  IconButton(
              icon: Icon(Icons.save,
                  color: _state.hasChanges
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.4)),
              onPressed: _state.hasChanges ? _saveAndReturn : null,
              tooltip: '保存',
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: Theme.of(context).colorScheme.onPrimary),
              tooltip: '更多操作',
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                if (_state.backgroundImage != null)
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
                                  (m) => m['name'] == _currentAiModel,
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
                if (_state.backgroundImage != null)
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
                if (_state.selectedBlockId != null) ...[
                  const PopupMenuDivider(),
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
            ),
      
          ],
        ),
        body: _state.backgroundImage == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  _layoutSize = constraints.biggest;
                  if (!_imageFitted && !_fitRequested) {
                    _fitRequested = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_imageFitted) {
                        _fitTransform(_layoutSize);
                      }
                    });
                  }

                  final currentScale = _transform.getMaxScaleOnAxis();

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Gesture layer covering entire body
                      Positioned.fill(
                        child: GestureDetector(
                          onTapUp: _onTapUp,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onScaleEnd: _onScaleEnd,
                          behavior: HitTestBehavior.opaque,
                          child: Container(color: Colors.grey[900]),
                        ),
                      ),
                      // Transformed canvas (visual only, no hit absorption)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: Transform(
                            transform: _transform,
                            child: CustomPaint(
                              size: _state.canvasSize,
                              painter: BookEditorPainter(
                                backgroundImage: _state.backgroundImage,
                                textBlocks: _state.textBlocks,
                                selectedBlockId: _state.selectedBlockId,
                                drawRect: _state.currentDrawRect,
                                isDrawing: _state.isDrawing,
                                scale: currentScale,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Processing
                      if (_state.isProcessing)
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('处理中...',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Toolbar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: BookEditorToolbar(
                          hasSelection: _state.selectedBlockId != null,
                          isDrawing: _state.isDrawing,
                          hasBlocks: _state.textBlocks.any((b) => !b.isDeleted),
                          onEditText: _editSelectedBlockText,
                          onPlay: _playSelectedBlock,
                          onDelete: _deleteSelectedBlock,
                          onAiEnhance: _aiEnhanceAll,
                          onNewBlock: _toggleDrawing,
                          onZoomIn: _zoomIn,
                          onZoomOut: _zoomOut,
                          onResetZoom: _resetZoom,
                          onReOcr: _reOcr,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
