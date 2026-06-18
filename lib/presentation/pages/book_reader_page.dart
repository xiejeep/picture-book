import 'dart:async';
import 'dart:io';

import 'package:book_app/core/constants/constants.dart';
import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/core/theme/app_tokens.dart';
import 'package:book_app/application/reading/text_block_ai_use_case.dart';
import 'package:book_app/application/reading/play_text_block_use_case.dart';
import 'package:book_app/core/utils/platform_utils.dart';
import 'package:book_app/core/utils/toast_util.dart';
import 'package:book_app/data/models/ai_settings_model.dart';
import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/models/page_model.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/image_service.dart';
import 'package:book_app/data/services/nfc_service.dart';
import 'package:book_app/data/services/translation_service.dart';
import 'package:book_app/data/services/tts_service.dart';
import 'package:book_app/presentation/providers/service_providers.dart';
import 'package:book_app/presentation/providers/settings_provider.dart';
import 'package:book_app/presentation/providers/repository_providers.dart';
import 'package:book_app/presentation/providers/nfc_action_handler.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_block_actions_sheet.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_nfc_bind_dialog.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_text_edit_sheet.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_voice_settings_dialog.dart';
import 'package:book_app/presentation/features/reader/views/book_reader_view.dart';
import 'package:book_app/presentation/features/reader/view_models/reader_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:book_app/vendor/photo_view/photo_view.dart';

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
  late AnimationController _loadingSpinnerController;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  Size _viewportSize = Size.zero;
  Timer? _longPressTimer;

  late AnimationController _focusAnimationController;
  late AnimationController _bounceAnimationController;
  Animation<Rect?>? _focusAnimation;
  Animation<double>? _bounceAnimation;
  Rect? _previousFocusRect;
  Rect? _currentFocusRect;
  bool _hasPlayedBefore = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _pageController = PageController(initialPage: _book.currentPageIndex);

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

    _subscribeToTtsState();

    _loadingSpinnerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _loadVoiceSettings();
    _pendingNfcActionSubscription = ref
        .listenManual<NfcAction?>(pendingNfcActionProvider, (previous, next) {
      if (next != null && mounted) {
        _playFromNfcAction(next);
        ref.read(pendingNfcActionProvider.notifier).state = null;
      }
    }, fireImmediately: true);

    if (widget.autoPlayPageId != null && widget.autoPlayBlockId != null) {
      TtsService.instance.initialize().then((_) {
        if (mounted) _autoPlayFromNfc();
      });
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _ttsStateSubscription?.cancel();
    _pendingNfcActionSubscription?.close();
    _focusAnimationController.dispose();
    _bounceAnimationController.dispose();
    _loadingSpinnerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  StreamSubscription<TtsPlaybackState>? _ttsStateSubscription;
  ProviderSubscription<NfcAction?>? _pendingNfcActionSubscription;

  void _subscribeToTtsState() {
    _ttsStateSubscription = TtsService.instance.stateStream.listen((state) {
      if (!mounted) return;
      switch (state.phase) {
        case TtsPlaybackPhase.playing:
          _loadingSpinnerController.stop();
          ref.read(readerProvider.notifier).setPlaybackStarted();
        case TtsPlaybackPhase.completed:
          ref.read(readerProvider.notifier).clearPlayback();
        case TtsPlaybackPhase.loading:
        case TtsPlaybackPhase.idle:
        case TtsPlaybackPhase.error:
          break;
      }
    });
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

    if (ref.read(readerProvider).currentIndex != ti) {
      ref.read(readerProvider.notifier).setCurrentIndex(ti);
      _pageController.jumpToPage(ti);
    }

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
    final offsetFromCenter =
        screenPos - Offset(viewportSize.width / 2, viewportSize.height / 2);
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
    final useCase = ref.read(playTextBlockUseCaseProvider);
    if (ref.read(readerProvider).playingText != null) {
      if (!mounted) return;
      await useCase.stop();
    }

    if (!mounted) return;
    ref
        .read(readerProvider.notifier)
        .setPlaybackLoading(blockIndex, block.text);
    _loadingSpinnerController.repeat();

    _updateFocusAnimation(block);

    if (PlatformUtils.supportsMlKit) {
      _translateBlock(block, blockIndex);
    }

    final result = await useCase.speak(block.text);
    if (!mounted) return;

    if (result.phase == PlayTextBlockPhase.failed) {
      _loadingSpinnerController.stop();
    }
    _clearPlaybackIfCurrent(blockIndex, block.text);
  }

  void _clearPlaybackIfCurrent(int blockIndex, String text) {
    final current = ref.read(readerProvider);
    if (current.playingBlockIndex == blockIndex &&
        current.playingText == text) {
      ref.read(readerProvider.notifier).clearPlayback();
    }
  }

  void _updateFocusAnimation(TextBlockModel block) {
    final page = _book.pages[ref.read(readerProvider).currentIndex];
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
        0,
        0,
        imageWidth,
        imageHeight,
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
    ref.read(playTextBlockUseCaseProvider).stop();
    _loadingSpinnerController.stop();
    ref.read(readerProvider.notifier).clearPlayback();
    setState(() {
      _currentFocusRect = null;
      _focusAnimation = null;
      _previousFocusRect = null;
      _hasPlayedBefore = false;
    });
  }

  void _replayCurrentBlock() {
    final translatedBlockIndex = ref.read(readerProvider).translatedBlockIndex;
    if (translatedBlockIndex == null) return;
    final page = _book.pages[ref.read(readerProvider).currentIndex];
    if (translatedBlockIndex >= page.textBlocks.length) return;
    final block = page.textBlocks[translatedBlockIndex];
    _playTextBlock(block, translatedBlockIndex);
  }

  Future<void> _translateBlock(TextBlockModel block, int blockIndex) async {
    final notifier = ref.read(readerProvider.notifier);
    final current = ref.read(readerProvider);
    if (current.translatedBlockIndex == blockIndex &&
        current.translatedText != null) {
      return;
    }

    if (block.aiTranslatedText != null) {
      notifier.setCachedTranslation(blockIndex, block.aiTranslatedText!);
      return;
    }

    if (block.translatedText != null) {
      notifier.setCachedTranslation(blockIndex, block.translatedText!);
      return;
    }

    notifier.setTranslationLoading(blockIndex);

    final result = await ref
        .read(translationServiceProvider)
        .translateWithStatus(block.text);

    if (!mounted) return;

    notifier.setTranslationResult(
      status: result.status,
      translatedText: result.translatedText,
    );

    if (result.status == TranslationStatus.done &&
        result.translatedText != null) {
      final updatedBlock =
          block.copyWith(aiTranslatedText: result.translatedText);
      await _updateBlockInPage(blockIndex, updatedBlock);
    }
  }

  void _clearTranslation() {
    ref.read(readerProvider.notifier).clearTranslation();
    setState(() {
      _currentFocusRect = null;
      _focusAnimation = null;
      _previousFocusRect = null;
      _hasPlayedBefore = false;
    });
  }

  void _toggleAppBar() {
    ref.read(readerProvider.notifier).toggleAppBar();
  }

  void _toggleBorders() {
    ref.read(readerProvider.notifier).toggleBorders();
  }

  void _toggleTranslation() {
    ref.read(readerProvider.notifier).toggleTranslation();
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
    final current = ref.read(readerProvider);
    if (index == current.playingBlockIndex ||
        index == current.loadingBlockIndex) {
      return;
    }
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

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ReaderBlockActionsSheet(
        showNfcAction: ref.read(nfcEnabledProvider),
        onEditText: () {
          Navigator.pop(ctx);
          _editBlockText(block, index);
        },
        onEditTranslation: () {
          Navigator.pop(ctx);
          _editBlockTranslation(block, index);
        },
        onBindNfc: () {
          Navigator.pop(ctx);
          _showNfcBindDialog(block, index);
        },
      ),
    );
  }

  Future<void> _updateBlockInPage(
      int index, TextBlockModel updatedBlock) async {
    final currentIndex = ref.read(readerProvider).currentIndex;
    final page = _book.pages[currentIndex];
    final textBlocks = List<TextBlockModel>.from(page.textBlocks);
    textBlocks[index] = updatedBlock;
    await ref.read(bookRepositoryProvider).updatePageTextBlocks(
          _book.id,
          currentIndex,
          textBlocks,
        );
    setState(() {});
  }

  Future<void> _editBlockText(TextBlockModel block, int index) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ReaderTextEditSheet(
        title: '编辑文字',
        fieldLabel: '最终文本',
        initialText: block.text,
        aiButtonLabel: 'AI 优化',
        aiButtonIcon: Icons.auto_fix_high,
        aiButtonColor: AppTheme.primaryOf(ctx).withValues(alpha: 0.85),
        onAiFill: () => _requestAiEnhancedText(index),
        onSave: (text) {
          if (text != block.text) {
            final updatedBlock = block.copyWith(
              text: text,
              clearTranslatedText: true,
              clearAiTranslatedText: true,
            );
            _updateBlockInPage(index, updatedBlock);
          }
        },
      ),
    );
  }

  Future<void> _editBlockTranslation(TextBlockModel block, int index) async {
    final currentTranslation =
        block.aiTranslatedText ?? block.translatedText ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ReaderTextEditSheet(
        title: '编辑翻译',
        fieldLabel: '翻译文本',
        initialText: currentTranslation,
        aiButtonLabel: 'AI 翻译',
        aiButtonIcon: Icons.g_translate,
        aiButtonColor: Colors.deepPurple.withValues(alpha: 0.85),
        onAiFill: () => _requestAiTranslatedText(index),
        onSave: (text) {
          if (text != currentTranslation) {
            final updatedBlock = block.copyWith(aiTranslatedText: text);
            _updateBlockInPage(index, updatedBlock);
            ref.read(readerProvider.notifier).setTranslatedBlock(index, text);
          }
        },
      ),
    );
  }

  final _textBlockAiUseCase = TextBlockAiUseCase();

  Future<String?> _requestAiEnhancedText(int index) async {
    final hasKey = await _textBlockAiUseCase.checkApiKey();
    if (!hasKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置 API Key')),
        );
      }
      return null;
    }

    final result = await _textBlockAiUseCase.enhanceTextBlock(
      bookId: _book.id,
      pageIndex: ref.read(readerProvider).currentIndex,
      blockIndex: index,
    );

    if (!mounted) return null;

    if (result.text != null) {
      ToastUtil.success('AI 优化完成');
      return result.text;
    }

    final msg = result.message ?? 'AI 优化完成，无需修改';
    if (result.isError) {
      ToastUtil.error(msg);
    } else if (result.changed) {
      ToastUtil.success(msg);
    } else {
      ToastUtil.info(msg);
    }
    return null;
  }

  Future<String?> _requestAiTranslatedText(int index) async {
    final hasKey = await _textBlockAiUseCase.checkApiKey();
    if (!hasKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置 API Key')),
        );
      }
      return null;
    }

    final result = await _textBlockAiUseCase.translateTextBlock(
      bookId: _book.id,
      pageIndex: ref.read(readerProvider).currentIndex,
      blockIndex: index,
    );

    if (!mounted) return null;

    if (result.text != null) {
      ToastUtil.success('AI 翻译完成');
      return result.text;
    }

    if (result.isError) {
      ToastUtil.error(result.message ?? 'AI 翻译失败');
    } else {
      ToastUtil.info(result.message ?? 'AI 翻译无结果');
    }
    return null;
  }

  void _showNfcBindDialog(TextBlockModel block, int blockIndex) async {
    final nfcService = ref.read(nfcServiceProvider);
    final available = await nfcService.isAvailable();
    if (!mounted) return;
    if (!available) {
      ToastUtil.warning('此设备不支持 NFC 功能');
      return;
    }

    final page = _book.pages[ref.read(readerProvider).currentIndex];
    await showDialog<void>(
      context: context,
      builder: (context) => ReaderNfcBindDialog(
        blockText: block.text,
        onBind: () async {
          try {
            await nfcService.writeTag(_book.id, page.id, block.id);
            return null;
          } catch (e) {
            return e is NfcException ? e.message : '绑定失败，请重试';
          }
        },
        onBound: () => ToastUtil.success('NFC 标签绑定成功'),
      ),
    );
  }

  void _showVoiceSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => ReaderVoiceSettingsDialog(
        engine: _ttsEngine,
        speechRate: _currentSpeechRate,
        onMoreSettings: () => context.push('/settings'),
        onSave: _saveSpeechRate,
      ),
    );
  }

  Future<void> _saveSpeechRate(double speechRate) async {
    final currentSettings = ref.read(storageServiceProvider).getAiSettings();
    final settings = (currentSettings ??
            AiSettingsModel(
              selectedModel: AppConstants.defaultModel,
            ))
        .copyWith(
      speechRate: speechRate,
    );
    await ref.read(storageServiceProvider).saveAiSettings(settings);

    if (!mounted) return;
    setState(() {
      _currentSpeechRate = speechRate;
    });
    ToastUtil.success('语速已调整');
  }

  @override
  Widget build(BuildContext context) {
    _viewportSize = MediaQuery.of(context).size;
    final nfcEnabled = ref.watch(nfcEnabledProvider);
    final readingState = ref.watch(readerProvider);

    return BookReaderView(
      readingState: readingState,
      pageController: _pageController,
      loadingAnimationValue: _loadingSpinnerController.value,
      focusAnimation: _focusAnimation,
      currentFocusRect: _currentFocusRect,
      bounceAnimation: _bounceAnimation,
      focusBounceAnimation: Listenable.merge([
        _focusAnimationController,
        _bounceAnimationController,
      ]),
      supportsTranslation: PlatformUtils.supportsMlKit,
      showNfcScan: Platform.isIOS && nfcEnabled,
      imageFileResolver: _imageFile,
      onEditBook: () => context.push('/book/${_book.id}/manage', extra: _book),
      onToggleAppBar: _toggleAppBar,
      onToggleTranslation: _toggleTranslation,
      onToggleBorders: _toggleBorders,
      onVoiceSettings: _showVoiceSettingsDialog,
      onScanNfc: () => ref.read(nfcServiceProvider).startIosScan(),
      onDoubleTap: _toggleAppBar,
      onTapDown: _onTapDown,
      onTapUp: _handleTapUp,
      onScaleEnd: _cancelLongPress,
      onPageChanged: (index) {
        ref.read(readerProvider.notifier).setCurrentIndex(index);
        _clearTranslation();
        ref.read(bookRepositoryProvider).updateCurrentPageIndex(
              _book.id,
              index,
            );
      },
      onStopPlaying: _stopPlaying,
      onReplay: _replayCurrentBlock,
      onClose: _clearTranslation,
    );
  }
}
