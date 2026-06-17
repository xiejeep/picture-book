import 'dart:async';
import 'dart:io';

import 'package:book_app/core/constants/constants.dart';
import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/core/theme/app_tokens.dart';
import 'package:book_app/core/utils/ai_block_helper.dart';
import 'package:book_app/core/utils/platform_utils.dart';
import 'package:book_app/core/utils/toast_util.dart';
import 'package:book_app/data/models/ai_settings_model.dart';
import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/models/page_model.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/ai_service.dart';
import 'package:book_app/data/services/image_service.dart';
import 'package:book_app/data/services/nfc_service.dart';
import 'package:book_app/data/services/translation_service.dart';
import 'package:book_app/data/services/tts_service.dart';
import 'package:book_app/presentation/providers/service_providers.dart';
import 'package:book_app/presentation/providers/settings_provider.dart';
import 'package:book_app/presentation/widgets/page_indicator.dart';
import 'package:book_app/presentation/widgets/reading_text_block_painter.dart';
import 'package:book_app/presentation/widgets/semantics_icon_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:book_app/vendor/photo_view/photo_view.dart';
import 'package:book_app/vendor/photo_view/photo_view_gallery.dart';

class BookReaderPage extends ConsumerStatefulWidget {
  final BookModel book;
  final String? autoPlayPageId;
  final String? autoPlayBlockId;

  const BookReaderPage({
    super.key,
    required this.book,
    this.autoPlayPageId,
    this.autoPlayBlockId,
  });

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage>
    with TickerProviderStateMixin {
  late BookModel _book;
  int _currentIndex;
  int? _playingBlockIndex;
  int? _loadingBlockIndex;
  late AnimationController _loadingSpinnerController;
  String? _playingText;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  Size _viewportSize = Size.zero;
  Timer? _longPressTimer;
  bool _showBorders = true;
  bool _showAppBar = true;
  bool _showTranslation = true;

  int? _translatedBlockIndex;
  String? _translatedText;
  bool _isTranslating = false;
  TranslationStatus _translationStatus = TranslationStatus.idle;

  late AnimationController _focusAnimationController;
  late AnimationController _bounceAnimationController;
  Animation<Rect?>? _focusAnimation;
  Animation<double>? _bounceAnimation;
  Rect? _previousFocusRect;
  Rect? _currentFocusRect;
  bool _hasPlayedBefore = false;

  StreamSubscription<NfcAction>? _nfcSubscription;

  _BookReaderPageState() : _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _currentIndex = _book.currentPageIndex;

    _focusAnimationController = AnimationController(
      duration: AppAnim.quick,
      vsync: this,
    );
    _bounceAnimationController = AnimationController(
      duration: AppAnim.slow,
      vsync: this,
    );
    _focusAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startBounceAnimation();
      }
    });

    TtsService.instance.onPlayingComplete = _onTtsComplete;
    _initTtsCallbacks();

    _loadingSpinnerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _loadVoiceSettings();
    _initNfc();

    if (widget.autoPlayPageId != null && widget.autoPlayBlockId != null) {
      TtsService.instance.initialize().then((_) {
        if (mounted) _autoPlayFromNfc();
      });
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    if (TtsService.instance.onPlayingComplete == _onTtsComplete) {
      TtsService.instance.onPlayingComplete = null;
    }
    TtsService.instance.onLoadingStarted = null;
    TtsService.instance.onPlayingStarted = null;
    _nfcSubscription?.cancel();
    _focusAnimationController.dispose();
    _bounceAnimationController.dispose();
    _loadingSpinnerController.dispose();
    super.dispose();
  }

  void _onTtsComplete() {
    if (mounted) {
      setState(() {
        _playingText = null;
        _playingBlockIndex = null;
      });
    }
  }

  void _initTtsCallbacks() {
    final ttsService = TtsService.instance;
    ttsService.onLoadingStarted = () {
      if (mounted) setState(() {});
    };
    ttsService.onPlayingStarted = () {
      if (mounted) {
        setState(() {
          _loadingBlockIndex = null;
        });
      }
    };
  }

  String get _ttsEngine {
    final settings = ref.read(storageServiceProvider).getAiSettings();
    return settings?.ttsEngine ?? 'system';
  }

  void _loadVoiceSettings() {
    final settings = ref.read(storageServiceProvider).getAiSettings();
    if (settings != null) {
      _currentSpeechRate = settings.speechRate;
    }
  }

  void _initNfc() {
    final nfcEnabled = ref.read(nfcEnabledProvider);
    if (!nfcEnabled) return;

    final nfcService = ref.read(nfcServiceProvider);
    _nfcSubscription = nfcService.onTagDetected.listen((action) {
      if (action.bookId == _book.id) {
        nfcService.markActionConsumed();
        _playFromNfcAction(action);
      }
    });

    if (Platform.isIOS) return;

    nfcService.startForegroundListening();
  }

  void _playFromNfcAction(NfcAction action) {
    int? targetPageIndex;
    for (int i = 0; i < _book.pages.length; i++) {
      if (_book.pages[i].id == action.pageId) {
        targetPageIndex = i;
        break;
      }
    }
    if (targetPageIndex == null) return;
    final ti = targetPageIndex;

    final page = _book.pages[ti];
    int? targetBlockIndex;
    for (int i = 0; i < page.textBlocks.length; i++) {
      if (page.textBlocks[i].id == action.blockId) {
        targetBlockIndex = i;
        break;
      }
    }
    if (targetBlockIndex == null) return;
    final bi = targetBlockIndex;

    setState(() {
      if (_currentIndex != ti) {
        _currentIndex = ti;
        _pageController.jumpToPage(ti);
      }
    });

    final block = page.textBlocks[bi];
    _playTextBlock(block, bi);
  }

  void _autoPlayFromNfc() {
    final action = NfcAction(
      bookId: _book.id,
      pageId: widget.autoPlayPageId!,
      blockId: widget.autoPlayBlockId!,
    );
    _playFromNfcAction(action);
  }

  late PageController _pageController;

  File? _imageFile(String imagePath) {
    return ImageService.instance.getImageFile(imagePath);
  }

  Offset _screenToImagePixel(
    Offset screenPos,
    Size viewportSize,
    Size imageSize,
    double scale,
    Offset panOffset,
  ) {
    final offsetFromCenter = screenPos -
        Offset(viewportSize.width / 2, viewportSize.height / 2);
    final imageLocal = offsetFromCenter - panOffset;
    return Offset(
      (imageLocal.dx / scale) + imageSize.width / 2,
      (imageLocal.dy / scale) + imageSize.height / 2,
    );
  }

  TextBlockModel? _hitTestBlock(
    Offset imagePoint,
    List<TextBlockModel> blocks,
  ) {
    for (int i = blocks.length - 1; i >= 0; i--) {
      final block = blocks[i];
      if (block.isDeleted) continue;
      if (block.boundingBox.contains(imagePoint)) return block;
    }
    return null;
  }

  Future<void> _playTextBlock(TextBlockModel block, int blockIndex) async {
    final ttsService = TtsService.instance;
    ttsService.onLoadingStarted = () {
      if (mounted) setState(() {});
    };
    ttsService.onPlayingStarted = () {
      if (mounted) {
        _loadingSpinnerController.stop();
        setState(() {
          _loadingBlockIndex = null;
        });
      }
    };

    if (_playingText != null) {
      if (!mounted) return;
      await ref.read(ttsServiceProvider).stop();
    }

    if (!mounted) return;
    setState(() {
      _playingText = block.text;
      _playingBlockIndex = blockIndex;
      _loadingBlockIndex = blockIndex;
    });
    _loadingSpinnerController.repeat();

    _updateFocusAnimation(block);

    if (PlatformUtils.supportsMlKit) {
      _translateBlock(block, blockIndex);
    }

    try {
      if (!mounted) return;
      await ref.read(ttsServiceProvider).speak(block.text);
    } catch (e) {
      if (!mounted) return;
      _loadingSpinnerController.stop();
      setState(() {
        _loadingBlockIndex = null;
      });
    }

    if (mounted) {
      setState(() {
        _playingText = null;
      });
    }
  }

  void _updateFocusAnimation(TextBlockModel block) {
    final page = _book.pages[_currentIndex];
    final imageWidth = page.imageWidth;
    final imageHeight = page.imageHeight;
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final blockRect = block.boundingBox;

    final targetRect = Rect.fromCenter(
      center: blockRect.center,
      width: blockRect.width * 1.1,
      height: blockRect.height * 1.2,
    );

    final isSameBlock = _previousFocusRect != null &&
        targetRect.left == _previousFocusRect!.left &&
        targetRect.top == _previousFocusRect!.top &&
        targetRect.width == _previousFocusRect!.width &&
        targetRect.height == _previousFocusRect!.height;

    Rect beginRect;
    Rect endRect;
    Curve curve;

    if (!_hasPlayedBefore) {
      beginRect = Rect.fromLTWH(
        0, 0, imageWidth, imageHeight,
      );
      endRect = targetRect;
      curve = Curves.easeInOut;
      _focusAnimationController.duration = AppAnim.quick;
      _hasPlayedBefore = true;
    } else if (isSameBlock) {
      _focusAnimation = RectTween(
        begin: targetRect,
        end: targetRect,
      ).animate(_focusAnimationController);
      _focusAnimationController.duration = Duration.zero;
      _focusAnimationController.forward(from: 0.0);
      _startBounceAnimation();
      return;
    } else {
      beginRect = _previousFocusRect ?? targetRect;
      endRect = targetRect;
      curve = Curves.easeInOut;
      _focusAnimationController.duration = AppAnim.quick;
    }

    _focusAnimation = RectTween(
      begin: beginRect,
      end: endRect,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController,
      curve: curve,
    ));

    _previousFocusRect = targetRect;
    _currentFocusRect = targetRect;

    _bounceAnimationController.reset();
    _focusAnimationController.forward(from: 0.0);
  }

  void _startBounceAnimation() {
    if (_currentFocusRect == null) return;

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.85)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 45,
      ),
    ]).animate(_bounceAnimationController);
    _bounceAnimationController.duration = AppAnim.slow;

    _bounceAnimationController.forward(from: 0.0);
  }

  void _stopPlaying() {
    ref.read(ttsServiceProvider).stop();
    _loadingSpinnerController.stop();
    setState(() {
      _playingText = null;
      _playingBlockIndex = null;
      _loadingBlockIndex = null;
      _currentFocusRect = null;
      _focusAnimation = null;
      _previousFocusRect = null;
      _hasPlayedBefore = false;
    });
  }

  void _replayCurrentBlock() {
    if (_translatedBlockIndex == null) return;
    final page = _book.pages[_currentIndex];
    if (_translatedBlockIndex! >= page.textBlocks.length) return;
    final block = page.textBlocks[_translatedBlockIndex!];
    _playTextBlock(block, _translatedBlockIndex!);
  }

  Future<void> _translateBlock(TextBlockModel block, int blockIndex) async {
    if (_translatedBlockIndex == blockIndex && _translatedText != null) return;

    if (block.aiTranslatedText != null) {
      setState(() {
        _translatedBlockIndex = blockIndex;
        _translatedText = block.aiTranslatedText;
        _isTranslating = false;
        _translationStatus = TranslationStatus.done;
      });
      return;
    }

    if (block.translatedText != null) {
      setState(() {
        _translatedBlockIndex = blockIndex;
        _translatedText = block.translatedText;
        _isTranslating = false;
        _translationStatus = TranslationStatus.done;
      });
      return;
    }

    setState(() {
      _translatedBlockIndex = blockIndex;
      _translatedText = null;
      _isTranslating = true;
      _translationStatus = TranslationStatus.translating;
    });

    final result = await ref
        .read(translationServiceProvider)
        .translateWithStatus(block.text);

    if (!mounted) return;

    setState(() {
      _isTranslating = false;
      _translationStatus = result.status;
      _translatedText = result.translatedText;
    });

    if (result.status == TranslationStatus.done &&
        result.translatedText != null) {
      final updatedBlock =
          block.copyWith(aiTranslatedText: result.translatedText);
      final page = _book.pages[_currentIndex];
      final updatedTextBlocks = List<TextBlockModel>.from(page.textBlocks);
      updatedTextBlocks[blockIndex] = updatedBlock;
      final updatedPage = page.copyWith(textBlocks: updatedTextBlocks);
      _book.pages[_currentIndex] = updatedPage;
      _book.updatedAt = DateTime.now();
      _book.save();
    }
  }

  void _clearTranslation() {
    setState(() {
      _translatedBlockIndex = null;
      _translatedText = null;
      _isTranslating = false;
      _translationStatus = TranslationStatus.idle;
      _playingBlockIndex = null;
      _currentFocusRect = null;
      _focusAnimation = null;
      _previousFocusRect = null;
      _hasPlayedBefore = false;
    });
  }

  void _toggleAppBar() {
    setState(() => _showAppBar = !_showAppBar);
  }

  void _toggleBorders() {
    setState(() => _showBorders = !_showBorders);
  }

  void _toggleTranslation() {
    setState(() => _showTranslation = !_showTranslation);
  }

  void _handleTapUp(
    BuildContext context,
    TapUpDetails details,
    PhotoViewControllerValue ctrlVal,
    PageModel page,
  ) {
    _longPressTimer?.cancel();
    _longPressTimer = null;

    final imageSize = Size(page.imageWidth, page.imageHeight);
    if (imageSize.width <= 0 || imageSize.height <= 0) return;
    if (page.textBlocks.isEmpty) return;

    final imagePoint = _screenToImagePixel(
      details.localPosition,
      _viewportSize,
      imageSize,
      ctrlVal.scale ?? 1.0,
      ctrlVal.position,
    );

    final block = _hitTestBlock(imagePoint, page.textBlocks);
    if (block == null) {
      _toggleAppBar();
      return;
    }

    final index = page.textBlocks.indexOf(block);
    if (index == _playingBlockIndex || index == _loadingBlockIndex) return;
    _playTextBlock(block, index);
  }

  void _onTapDown(
    TapDownDetails details,
    PhotoViewControllerValue ctrlVal,
    PageModel page,
  ) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      _handleLongPress(details.localPosition, ctrlVal, page);
    });
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _handleLongPress(
    Offset localPosition,
    PhotoViewControllerValue ctrlVal,
    PageModel page,
  ) {
    final imageSize = Size(page.imageWidth, page.imageHeight);
    if (imageSize.width <= 0 || imageSize.height <= 0) return;
    if (page.textBlocks.isEmpty) return;

    final imagePoint = _screenToImagePixel(
      localPosition,
      _viewportSize,
      imageSize,
      ctrlVal.scale ?? 1.0,
      ctrlVal.position,
    );

    final block = _hitTestBlock(imagePoint, page.textBlocks);
    if (block == null) return;

    final index = page.textBlocks.indexOf(block);
    _showBlockActionsBottomSheet(block, index);
  }

  void _showBlockActionsBottomSheet(TextBlockModel block, int index) {
    _clearTranslation();
    final nfcEnabled = ref.read(nfcEnabledProvider);
    final primaryColor = AppTheme.primaryOf(context);
    final mutedColor = AppTheme.mutedOf(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          color: AppTheme.surfaceOf(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: mutedColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildActionTile(
                ctx,
                icon: Icons.edit,
                title: '编辑文字',
                subtitle: '修改此文字块的识别文本',
                color: primaryColor,
                onTap: () {
                  Navigator.pop(ctx);
                  _editBlockText(block, index);
                },
              ),
              _buildActionTile(
                ctx,
                icon: Icons.translate,
                title: '编辑翻译',
                subtitle: '修改此文字块的翻译文本',
                color: AppTheme.accentOf(context),
                onTap: () {
                  Navigator.pop(ctx);
                  _editBlockTranslation(block, index);
                },
              ),
              if (nfcEnabled)
                _buildActionTile(
                  ctx,
                  icon: Icons.nfc,
                  title: '绑定 NFC 标签',
                  subtitle: '将此文字块绑定到 NFC 标签',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showNfcBindDialog(block, index);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceOf(ctx))),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceOf(ctx).withValues(alpha: 0.6))),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _updateBlockInPage(int index, TextBlockModel updatedBlock) {
    final page = _book.pages[_currentIndex];
    final textBlocks = List<TextBlockModel>.from(page.textBlocks);
    textBlocks[index] = updatedBlock;
    _book.pages[_currentIndex] = page.copyWith(textBlocks: textBlocks);
    _book.updatedAt = DateTime.now();
    _book.save();
    setState(() {});
  }

  Future<void> _editBlockText(TextBlockModel block, int index) async {
    final controller = TextEditingController(text: block.text);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);
    bool isAiLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          color: AppTheme.surfaceOf(context),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('编辑文字',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceColor)),
                    SemanticsIconButton(
                        icon: Icons.close,
                        label: '关闭',
                        hint: '关闭编辑窗口',
                        color: onSurfaceColor,
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: '最终文本', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isAiLoading
                          ? null
                          : () => _aiEnhanceAndFill(
                              ctx, setDialogState, controller, index,
                              setLoading: () => isAiLoading = true,
                              clearLoading: () => isAiLoading = false),
                      icon: isAiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('AI 优化'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppTheme.primaryOf(context).withValues(alpha: 0.85),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('取消',
                            style: TextStyle(
                                color: onSurfaceColor.withValues(alpha: 0.6)))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (controller.text != block.text) {
                          final updatedBlock = block.copyWith(
                            text: controller.text,
                            clearTranslatedText: true,
                            clearAiTranslatedText: true,
                          );
                          _updateBlockInPage(index, updatedBlock);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editBlockTranslation(
      TextBlockModel block, int index) async {
    final currentTranslation =
        block.aiTranslatedText ?? block.translatedText ?? '';
    final controller = TextEditingController(text: currentTranslation);
    final onSurfaceColor = AppTheme.onSurfaceOf(context);
    bool isAiLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          color: AppTheme.surfaceOf(context),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('编辑翻译',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceColor)),
                    SemanticsIconButton(
                        icon: Icons.close,
                        label: '关闭',
                        hint: '关闭编辑窗口',
                        color: onSurfaceColor,
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: '翻译文本', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isAiLoading
                          ? null
                          : () => _aiTranslateAndFill(
                              ctx, setDialogState, controller, index,
                              setLoading: () => isAiLoading = true,
                              clearLoading: () => isAiLoading = false),
                      icon: isAiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.g_translate, size: 18),
                      label: const Text('AI 翻译'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.85),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('取消',
                            style: TextStyle(
                                color: onSurfaceColor.withValues(alpha: 0.6)))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (controller.text != currentTranslation) {
                          final updatedBlock = block.copyWith(
                              aiTranslatedText: controller.text);
                          _updateBlockInPage(index, updatedBlock);
                          _translatedText = controller.text;
                          _translatedBlockIndex = index;
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _aiEnhanceAndFill(
    BuildContext ctx,
    StateSetter setDialogState,
    TextEditingController controller,
    int index, {
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
  }) async {
    if (!ctx.mounted) return;
    final hasKey = await AiBlockHelper.checkApiKey(ctx);
    if (!hasKey) return;

    final page = _book.pages[_currentIndex];
    final imageFile =
        ref.read(imageServiceProvider).getImageFile(page.imagePath);
    if (imageFile == null || !imageFile.existsSync()) {
      if (ctx.mounted) ToastUtil.error('图片文件不存在');
      return;
    }

    final model = AiService.instance.getSelectedModel();
    final block = page.textBlocks[index];

    setDialogState(setLoading);

    try {
      final corrected = await AiBlockHelper.enhance(
        imageFile: imageFile,
        blocks: [{0: block.text}],
        model: model,
      );

      if (!ctx.mounted) return;

      if (corrected[0] != null && corrected[0] != block.text) {
        controller.text = corrected[0]!;
        ToastUtil.success('AI 优化完成');
      } else {
        ToastUtil.info('AI 优化完成，无需修改');
      }
    } catch (e) {
      if (ctx.mounted) ToastUtil.error('AI 优化失败: $e');
    } finally {
      if (ctx.mounted) setDialogState(clearLoading);
    }
  }

  Future<void> _aiTranslateAndFill(
    BuildContext ctx,
    StateSetter setDialogState,
    TextEditingController controller,
    int index, {
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
  }) async {
    if (!ctx.mounted) return;
    final hasKey = await AiBlockHelper.checkApiKey(ctx);
    if (!hasKey) return;

    final page = _book.pages[_currentIndex];
    final imageFile =
        ref.read(imageServiceProvider).getImageFile(page.imagePath);
    if (imageFile == null || !imageFile.existsSync()) {
      if (ctx.mounted) ToastUtil.error('图片文件不存在');
      return;
    }

    final model = AiService.instance.getSelectedModel();
    final block = page.textBlocks[index];

    setDialogState(setLoading);

    try {
      final result = await AiBlockHelper.translate(
        imageFile: imageFile,
        blocks: [{0: block.text}],
        model: model,
      );

      if (!ctx.mounted) return;

      if (result[0] != null && result[0]!.isNotEmpty) {
        controller.text = result[0]!;
        ToastUtil.success('AI 翻译完成');
      } else {
        ToastUtil.info('AI 翻译无结果');
      }
    } catch (e) {
      if (ctx.mounted) ToastUtil.error('AI 翻译失败: $e');
    } finally {
      if (ctx.mounted) setDialogState(clearLoading);
    }
  }

  void _showNfcBindDialog(TextBlockModel block, int blockIndex) async {
    final nfcService = ref.read(nfcServiceProvider);
    final available = await nfcService.isAvailable();
    if (!available) {
      if (mounted) {
        ToastUtil.warning('此设备不支持 NFC 功能');
      }
      return;
    }

    final page = _book.pages[_currentIndex];
    bool isWriting = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.nfc,
                  color: AppTheme.primaryOf(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '绑定 NFC 标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将此文本块绑定到一张 NFC 标签：',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardOf(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  block.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceOf(context),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              if (isWriting)
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '请将 NFC 标签贴近手机背面...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryOf(context),
                      ),
                    ),
                  ],
                )
              else if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.errorOf(context),
                  ),
                )
              else
                Text(
                  '点击"开始绑定"后请将 NFC 标签贴近手机背面',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryOf(context),
                  ),
                ),
            ],
          ),
          actions: [
            if (!isWriting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  errorMessage != null ? '关闭' : '取消',
                  style: TextStyle(
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: isWriting
                  ? null
                  : () async {
                      setDialogState(() {
                        isWriting = true;
                        errorMessage = null;
                      });
                      try {
                        await nfcService.writeTag(_book.id, page.id, block.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ToastUtil.success('NFC 标签绑定成功');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() {
                            isWriting = false;
                            errorMessage = e is NfcException
                                ? e.message
                                : '绑定失败，请重试';
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppTheme.primaryOf(context).withValues(alpha: 0.85),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(errorMessage != null ? '重新绑定' : '开始绑定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceSettingsDialog() {
    final dialogEngine = _ttsEngine;
    double dialogRate = (_currentSpeechRate).clamp(
      dialogEngine == 'supertonic'
          ? AppConstants.supertonicMinSpeed
          : AppConstants.systemTtsMinSpeed,
      dialogEngine == 'supertonic'
          ? AppConstants.supertonicMaxSpeed
          : AppConstants.systemTtsMaxSpeed,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOf(context)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.record_voice_over_rounded,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '语音设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardOf(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _ttsEngine == 'supertonic'
                                ? AppTheme.accentOf(context).withValues(alpha: 0.2)
                                : AppTheme.primaryOf(context).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _ttsEngine == 'supertonic' ? 'Supertonic' : '系统TTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                          color: dialogEngine == 'supertonic'
                                  ? AppTheme.accentOf(context)
                                  : AppTheme.primaryOf(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '语速',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(dialogRate * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: dialogRate,
                    min: _ttsEngine == 'supertonic'
                        ? AppConstants.supertonicMinSpeed
                        : AppConstants.systemTtsMinSpeed,
                    max: _ttsEngine == 'supertonic'
                        ? AppConstants.supertonicMaxSpeed
                        : AppConstants.systemTtsMaxSpeed,
                    divisions: _ttsEngine == 'supertonic'
                        ? AppConstants.supertonicSpeedDivisions
                        : AppConstants.systemTtsSpeedDivisions,
                    activeColor: AppTheme.primaryOf(context),
                    onChanged: (value) {
                      setDialogState(() => dialogRate = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '慢速',
                        style: TextStyle(
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                            fontSize: 12),
                      ),
                      Text(
                        '快速',
                        style: TextStyle(
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/settings');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: AppTheme.primaryOf(context)
                                .withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '更多设置',
                            style: TextStyle(
                                color: AppTheme.onSurfaceOf(context)
                                    .withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final currentSettings = ref
                                .read(storageServiceProvider)
                                .getAiSettings();
                            final settings = (currentSettings ??
                                    AiSettingsModel(
                                      selectedModel:
                                          AppConstants.defaultModel,
                                    ))
                                .copyWith(
                              speechRate: dialogRate,
                            );
                            await ref
                                .read(storageServiceProvider)
                                .saveAiSettings(settings);

                            setState(() {
                              _currentSpeechRate = dialogRate;
                            });
                            if (context.mounted) Navigator.pop(context);

                            ToastUtil.success('语速已调整');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOf(context)
                                .withValues(alpha: 0.85),
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadingBar() {
    final block = _book.pages[_currentIndex].textBlocks[_translatedBlockIndex!];
    final isPlaying = _playingText != null;

    String statusText;
    if (_translationStatus == TranslationStatus.downloadingModel) {
      statusText = '正在下载翻译模型...';
    } else if (_isTranslating) {
      statusText = '翻译中...';
    } else if (_translationStatus == TranslationStatus.failed) {
      statusText = '翻译失败';
    } else {
      statusText = '';
    }

    return Positioned(
      bottom: 72,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.isDarkMode(context)
                ? AppTheme.darkCard
                : const Color(0xFF2D2D3A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      block.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: isPlaying ? '停止朗读' : '重新播放',
                    hint: '控制朗读播放',
                    button: true,
                    child: GestureDetector(
                      onTap: isPlaying ? _stopPlaying : _replayCurrentBlock,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    label: '关闭',
                    hint: '关闭阅读栏',
                    button: true,
                    child: GestureDetector(
                      onTap: _clearTranslation,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_showTranslation && _isTranslating)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else if (_showTranslation && _translatedText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _translatedText!,
                      style: TextStyle(
                        color: AppTheme.accentOf(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else if (_showTranslation &&
                  _translationStatus == TranslationStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusBorder() {
    if (_focusAnimation == null || _currentFocusRect == null) {
      return const SizedBox.shrink();
    }

    final animation = Listenable.merge([
      _focusAnimationController,
      _bounceAnimationController,
    ]);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final flyRect = _focusAnimation!.value ?? _currentFocusRect!;
        final bounceScale = _bounceAnimation?.value ?? 1.0;

        final center = flyRect.center;
        final scaledWidth = flyRect.width * bounceScale;
        final scaledHeight = flyRect.height * bounceScale;
        final scaledRect = Rect.fromCenter(
          center: center,
          width: scaledWidth,
          height: scaledHeight,
        );

        return Positioned(
          left: scaledRect.left,
          top: scaledRect.top,
          width: scaledRect.width,
          height: scaledRect.height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.focusHighlightColor,
                  width: (scaledRect.height * 0.04).clamp(3.0, 8.0),
                ),
                borderRadius: BorderRadius.circular(
                  (scaledRect.height * 0.08).clamp(4.0, 12.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _viewportSize = MediaQuery.of(context).size;
    final pages = _book.pages;
    final isDark = AppTheme.isDarkMode(context);

    if (pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_book.title),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.appBarGradientOf(context),
            ),
          ),
        ),
        body: Container(
          decoration: AppTheme.gradientBoxOf(context),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.calmBlue.withValues(alpha: 0.2),
                            AppTheme.gentleGreen.withValues(alpha: 0.2),
                            AppTheme.sweetPink.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 64,
                        color: AppTheme.primaryOf(context).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '读本还没有页面',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '「${_book.title}」中还没有任何页面，\n先去添加一些页面吧',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/book/${_book.id}/manage'),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('去编辑读本'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: isDark
                  ? AppTheme.darkSurface.withValues(alpha: 0.85)
                  : AppTheme.softOrange.withValues(alpha: 0.85),
              elevation: 0,
              title: Text(_book.title),
              actions: [
                Semantics(
                  label: '语音设置',
                  hint: '调整朗读语速和语音',
                  button: true,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _showVoiceSettingsDialog,
                    tooltip: '语音设置',
                  ),
                ),
                Semantics(
                  label: '隐藏导航栏',
                  hint: '双击页面可重新显示',
                  button: true,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.visibility_off_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _toggleAppBar,
                    tooltip: '隐藏导航栏',
                  ),
                ),
                if (PlatformUtils.supportsMlKit)
                  Semantics(
                    label: _showTranslation ? '隐藏翻译' : '显示翻译',
                    hint: '切换翻译显示状态',
                    button: true,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _showTranslation
                              ? Icons.translate_rounded
                              : Icons.translate_outlined,
                          size: 18,
                          color: _showTranslation
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      onPressed: _toggleTranslation,
                      tooltip: _showTranslation ? '隐藏翻译' : '显示翻译',
                    ),
                  ),
                Semantics(
                  label: _showBorders ? '隐藏边框' : '显示边框',
                  hint: '切换文字块边框显示',
                  button: true,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _showBorders
                            ? Icons.border_color_rounded
                            : Icons.border_clear_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: _toggleBorders,
                    tooltip: _showBorders ? '隐藏边框' : '显示边框',
                  ),
                ),
                if (Platform.isIOS && ref.watch(nfcEnabledProvider))
                  Semantics(
                    label: '扫描NFC标签',
                    hint: '靠近NFC标签自动识别并播放',
                    button: true,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.nfc,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        final nfcService = ref.read(nfcServiceProvider);
                        nfcService.startIosScan();
                      },
                      tooltip: '扫描NFC标签',
                    ),
                  ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.appBarGradientOf(context),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, index) {
                final page = pages[index];
                final file = _imageFile(page.imagePath);
                final imageSize = Size(page.imageWidth, page.imageHeight);
                final hasValidSize =
                    imageSize.width > 0 && imageSize.height > 0;
                final activeBlocks =
                    page.textBlocks.where((b) => !b.isDeleted).toList();

                return PhotoViewGalleryPageOptions.customChild(
                  child: Stack(
                    children: [
                      if (file != null)
                        Image.file(
                          file,
                          fit: BoxFit.contain,
                          width: hasValidSize ? imageSize.width : null,
                          height: hasValidSize ? imageSize.height : null,
                        )
                      else
                        Image(
                          image: const AssetImage('assets/placeholder.png'),
                          fit: BoxFit.contain,
                        ),
                      if (hasValidSize && activeBlocks.isNotEmpty && _showBorders)
                        CustomPaint(
                          size: imageSize,
                          painter: ReadingTextBlockPainter(
                            textBlocks: page.textBlocks,
                            imageWidth: page.imageWidth,
                            imageHeight: page.imageHeight,
                            displayWidth: page.imageWidth,
                            displayHeight: page.imageHeight,
                            playingBlockIndex: _playingBlockIndex,
                            loadingBlockIndex: _loadingBlockIndex,
                            loadingAnimationValue:
                                _loadingSpinnerController.value,
                            textBlockMaskColor:
                                Colors.orange.withValues(alpha: 0.25),
                          ),
                        ),
                      _buildFocusBorder(),
                    ],
                  ),
                  childSize: hasValidSize ? imageSize : null,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 3,
                onDoubleTap: _toggleAppBar,
                heroAttributes:
                    PhotoViewHeroAttributes(tag: page.imagePath),
                  onTapDown: (context, details, ctrlVal) =>
                      _onTapDown(details, ctrlVal, page),
                  onTapUp: (context, details, ctrlVal) =>
                      _handleTapUp(context, details, ctrlVal, page),
                  onScaleEnd: (context, details, ctrlVal) =>
                      _cancelLongPress(),
                );
              },
              itemCount: pages.length,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              pageController: _pageController = PageController(
                initialPage: _currentIndex,
              ),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _clearTranslation();
                });
                _book.currentPageIndex = index;
                _book.updatedAt = DateTime.now();
                _book.save();
              },
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          if (!_showAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _toggleAppBar,
                child: Container(
                  height: 60,
                  color: Colors.transparent,
                ),
              ),
            ),
          if (_translatedBlockIndex != null) _buildReadingBar(),
          if (pages.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: PageIndicator(
                  currentPage: _currentIndex,
                  totalPages: pages.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
