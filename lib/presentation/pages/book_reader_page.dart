import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/book_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/text_block_model.dart';
import '../../data/models/ai_settings_model.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/nfc_service.dart';
import '../../data/services/ai_service.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/toast_util.dart';
import '../../core/utils/ai_block_helper.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/reading_text_block_painter.dart';
import '../widgets/semantics_icon_button.dart';

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
  int _currentPage = 0;
  bool _showControls = true;
  bool _isZoomed = false;

  final PageController _pageController = PageController();
  final List<TransformationController> _transformControllers = [];

  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  TransformationController? _animatingController;

  Offset? _swipeStart;
  int _activePointers = 0;
  Size _viewportSize = Size.zero;

  // --- Tap-to-read state ---
  int? _playingBlockIndex;
  int? _loadingBlockIndex;
  String? _playingText;
  Timer? _loadingIndicatorTimer;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  String _currentTtsEngine = 'system';

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
  Size? _displaySize;
  Size? _imageSize;

  bool _showBorders = true;
  bool _showTranslation = true;

  // --- NFC ---
  StreamSubscription<NfcAction>? _nfcSubscription;
  ({TextBlockModel block, int index})? _pendingAutoPlay;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _currentPage = 0;

    for (int i = 0; i < _book.pages.length; i++) {
      _transformControllers.add(TransformationController());
    }

    _zoomAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _zoomAnimController.addListener(_onZoomAnimTick);

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

    _initTtsCallbacks();
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
    final ttsService = TtsService.instance;
    ttsService.onLoadingStarted = null;
    ttsService.onPlayingStarted = null;
    ttsService.onPlayingComplete = null;
    _loadingIndicatorTimer?.cancel();
    _nfcSubscription?.cancel();
    _pageController.dispose();
    _zoomAnimController.dispose();
    _focusAnimationController.dispose();
    _bounceAnimationController.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Zoom animation
  // ---------------------------------------------------------------------------

  void _onZoomAnimTick() {
    if (_zoomAnimation != null && _animatingController != null) {
      _animatingController!.value = _zoomAnimation!.value;
    }
  }

  void _updateZoomState(int pageIndex) {
    final scale = _transformControllers[pageIndex].value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  // ---------------------------------------------------------------------------
  // Page navigation
  // ---------------------------------------------------------------------------

  void _onPageChanged(int page) {
    ref.read(ttsServiceProvider).stop();
    _loadingIndicatorTimer?.cancel();
    final scale = _transformControllers[page].value.getMaxScaleOnAxis();
    setState(() {
      _currentPage = page;
      _isZoomed = scale > 1.05;
      _playingText = null;
      _playingBlockIndex = null;
      _loadingBlockIndex = null;
      _translatedBlockIndex = null;
      _translatedText = null;
      _isTranslating = false;
      _translationStatus = TranslationStatus.idle;
      _currentFocusRect = null;
      _focusAnimation = null;
      _previousFocusRect = null;
      _hasPlayedBefore = false;
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _toggleBorders() {
    setState(() => _showBorders = !_showBorders);
  }

  void _toggleTranslation() {
    setState(() => _showTranslation = !_showTranslation);
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_currentPage < _book.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Edge-swipe detection (page turn while zoomed)
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1) {
      _swipeStart = event.localPosition;
    }
  }

  void _onPointerUp(PointerUpEvent event, int pageIndex) {
    _activePointers--;
    if (_activePointers > 0) return;

    final controller = _transformControllers[pageIndex];
    final scale = controller.value.getMaxScaleOnAxis();

    if (scale <= 1.05 || _swipeStart == null) {
      _swipeStart = null;
      return;
    }

    final dx = event.localPosition.dx - _swipeStart!.dx;
    final dy = event.localPosition.dy - _swipeStart!.dy;

    if (dx.abs() <= 50 || dy.abs() >= dx.abs() * 0.5) {
      _swipeStart = null;
      return;
    }

    final translationX = controller.value.getTranslation().x;
    final viewportWidth = _viewportSize.width;
    final contentWidth = viewportWidth * scale;
    final minTranslationX = viewportWidth - contentWidth;

    if (dx > 0 && translationX >= -1.0) {
      _goToPreviousPage();
    } else if (dx < 0 && translationX <= minTranslationX + 1.0) {
      _goToNextPage();
    }

    _swipeStart = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers--;
    if (_activePointers <= 0) {
      _activePointers = 0;
      _swipeStart = null;
    }
  }

  // ---------------------------------------------------------------------------
  // TTS playback
  // ---------------------------------------------------------------------------

  void _loadVoiceSettings() {
    final settings = ref.read(storageServiceProvider).getAiSettings();
    setState(() {
      _currentTtsEngine = settings?.ttsEngine ?? 'system';
      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _currentSpeechRate = settings.speechRate;
      } else {
        _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
      }
    });
  }

  void _initTtsCallbacks() {
    final ttsService = ref.read(ttsServiceProvider);
    ttsService.onLoadingStarted = () {
      if (mounted) setState(() {});
    };
    ttsService.onPlayingStarted = () {
      if (mounted) {
        _loadingIndicatorTimer?.cancel();
        setState(() {
          _loadingBlockIndex = null;
        });
      }
    };
  }

  Future<void> _playTextBlock(TextBlockModel block, int blockIndex) async {
    if (kDebugMode) {
      debugPrint(
          '>>> _playTextBlock: blockIndex=$blockIndex, text=${block.text.length > 20 ? block.text.substring(0, 20) : block.text}...');
    }

    final ttsService = TtsService.instance;
    ttsService.onLoadingStarted = () {
      if (mounted) setState(() {});
    };
    ttsService.onPlayingStarted = () {
      if (mounted) {
        _loadingIndicatorTimer?.cancel();
        setState(() {
          _loadingBlockIndex = null;
        });
      }
    };

    _updateFocusAnimation(block);

    if (PlatformUtils.supportsMlKit) {
      _translateBlock(block, blockIndex);
    }

    if (_playingText != null) {
      if (!mounted) return;
      await ref.read(ttsServiceProvider).stop();
    }

    if (!mounted) return;
    setState(() {
      _playingText = block.text;
      _playingBlockIndex = blockIndex;
    });

    _loadingIndicatorTimer?.cancel();
    if (_currentTtsEngine == 'glm' || _currentTtsEngine == 'supertonic') {
      _loadingIndicatorTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted &&
            _playingBlockIndex == blockIndex &&
            _loadingBlockIndex == null &&
            ttsService.isLoading) {
          setState(() => _loadingBlockIndex = blockIndex);
        }
      });
    }

    try {
      if (!mounted) return;
      await ref.read(ttsServiceProvider).speak(block.text);
    } catch (e) {
      if (!mounted) return;
      _loadingIndicatorTimer?.cancel();
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

  void _stopPlaying() {
    ref.read(ttsServiceProvider).stop();
    _loadingIndicatorTimer?.cancel();
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
    final page = _book.pages[_currentPage];
    if (_translatedBlockIndex! >= page.textBlocks.length) return;
    final block = page.textBlocks[_translatedBlockIndex!];
    _playTextBlock(block, _translatedBlockIndex!);
  }

  // ---------------------------------------------------------------------------
  // Translation
  // ---------------------------------------------------------------------------

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
      final page = _book.pages[_currentPage];
      final updatedTextBlocks = List<TextBlockModel>.from(page.textBlocks);
      updatedTextBlocks[blockIndex] = updatedBlock;
      final updatedPage = page.copyWith(textBlocks: updatedTextBlocks);
      _book.pages[_currentPage] = updatedPage;
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

  // ---------------------------------------------------------------------------
  // NFC
  // ---------------------------------------------------------------------------

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

  void _handlePendingAutoPlay() {
    if (_pendingAutoPlay == null) return;
    final pending = _pendingAutoPlay!;
    _pendingAutoPlay = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playTextBlock(pending.block, pending.index);
    });
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

    final page = _book.pages[targetPageIndex];
    int? targetBlockIndex;
    for (int i = 0; i < page.textBlocks.length; i++) {
      if (page.textBlocks[i].id == action.blockId) {
        targetBlockIndex = i;
        break;
      }
    }
    if (targetBlockIndex == null) return;

    if (!mounted) return;
    _pageController.jumpToPage(targetPageIndex);

    final block = page.textBlocks[targetBlockIndex];
    if (_displaySize == null || _imageSize == null) {
      _pendingAutoPlay = (block: block, index: targetBlockIndex);
    } else {
      _playTextBlock(block, targetBlockIndex);
    }
  }

  void _autoPlayFromNfc() {
    final pageId = widget.autoPlayPageId;
    final blockId = widget.autoPlayBlockId;
    if (pageId == null || blockId == null) return;

    int? targetPageIndex;
    for (int i = 0; i < _book.pages.length; i++) {
      if (_book.pages[i].id == pageId) {
        targetPageIndex = i;
        break;
      }
    }
    if (targetPageIndex == null) return;

    final page = _book.pages[targetPageIndex];
    int? targetBlockIndex;
    for (int i = 0; i < page.textBlocks.length; i++) {
      if (page.textBlocks[i].id == blockId) {
        targetBlockIndex = i;
        break;
      }
    }
    if (targetBlockIndex == null) return;

    _pageController.jumpToPage(targetPageIndex);

    final block = page.textBlocks[targetBlockIndex];
    if (_displaySize == null || _imageSize == null) {
      _pendingAutoPlay = (block: block, index: targetBlockIndex);
    } else {
      _playTextBlock(block, targetBlockIndex);
    }
  }

  // ---------------------------------------------------------------------------
  // Focus animation
  // ---------------------------------------------------------------------------

  void _updateFocusAnimation(TextBlockModel block) {
    if (_displaySize == null || _imageSize == null) return;

    final page = _book.pages[_currentPage];
    final scaleX = _displaySize!.width /
        (page.imageWidth > 0 ? page.imageWidth : _imageSize!.width);
    final scaleY = _displaySize!.height /
        (page.imageHeight > 0 ? page.imageHeight : _imageSize!.height);

    final blockRect = Rect.fromLTRB(
      block.boundingBox.left * scaleX,
      block.boundingBox.top * scaleY,
      block.boundingBox.right * scaleX,
      block.boundingBox.bottom * scaleY,
    );

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
        _displaySize!.width,
        _displaySize!.height,
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (_book.pages.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: isDark
              ? const BoxDecoration(color: AppTheme.darkBackground)
              : AppTheme.readingPageGradient,
          child: SafeArea(child: _buildEmptyState()),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _showControls ? _buildAppBar(isDark) : null,
      body: Container(
        decoration: isDark
            ? const BoxDecoration(color: AppTheme.darkBackground)
            : AppTheme.readingPageGradient,
        child: Stack(
          children: [
            SafeArea(
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: _book.pages.length,
                itemBuilder: (context, index) => _buildPage(index),
              ),
            ),
            if (_translatedBlockIndex != null) _buildReadingBar(),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${_book.pages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark
          ? AppTheme.darkSurface.withValues(alpha: 0.85)
          : AppTheme.softOrange.withValues(alpha: 0.85),
      elevation: 0,
      leading: Semantics(
        label: '返回',
        hint: '返回上一页',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
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
        Semantics(
          label: '隐藏导航栏',
          hint: '点击页面可重新显示',
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
            onPressed: _toggleControls,
            tooltip: '隐藏导航栏',
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.appBarGradientOf(context),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page content
  // ---------------------------------------------------------------------------

  Widget _buildPage(int index) {
    final page = _book.pages[index];
    final imageFile =
        ref.read(imageServiceProvider).getImageFile(page.imagePath);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (imageFile == null) {
          return GestureDetector(
            onTap: _toggleControls,
            child: _buildImageError(),
          );
        }

        if (page.imageWidth > 0 && page.imageHeight > 0) {
          final imageSize = Size(page.imageWidth, page.imageHeight);
          final displaySize =
              _calculateDisplaySize(imageSize, _viewportSize);
          if (index == _currentPage) {
            _displaySize = displaySize;
            _imageSize = imageSize;
            _handlePendingAutoPlay();
          }
          return _buildPageContent(
              index, page, imageFile, displaySize, imageSize);
        }

        return FutureBuilder<Size>(
          future: _getImageSize(imageFile),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryOf(context),
                ),
              );
            }
            final imageSize = snapshot.data!;
            final displaySize =
                _calculateDisplaySize(imageSize, _viewportSize);
            if (index == _currentPage) {
              _displaySize = displaySize;
              _imageSize = imageSize;
              _handlePendingAutoPlay();
            }
            return _buildPageContent(
                index, page, imageFile, displaySize, imageSize);
          },
        );
      },
    );
  }

  Widget _buildPageContent(
    int index,
    PageModel page,
    File imageFile,
    Size displaySize,
    Size imageSize,
  ) {
    return GestureDetector(
      onDoubleTap: _toggleControls,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: (e) => _onPointerUp(e, index),
        onPointerCancel: _onPointerCancel,
        child: InteractiveViewer(
          transformationController: _transformControllers[index],
          minScale: 1.0,
          maxScale: 4.0,
          onInteractionEnd: (_) => _updateZoomState(index),
          child: Center(
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.file(
                    imageFile,
                    width: displaySize.width,
                    height: displaySize.height,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageError(),
                  ),
                  if (page.textBlocks.isNotEmpty && _showBorders)
                    CustomPaint(
                      size: displaySize,
                      painter: ReadingTextBlockPainter(
                        textBlocks: page.textBlocks,
                        imageWidth: page.imageWidth > 0
                            ? page.imageWidth
                            : imageSize.width,
                        imageHeight: page.imageHeight > 0
                            ? page.imageHeight
                            : imageSize.height,
                        displayWidth: displaySize.width,
                        displayHeight: displaySize.height,
                        playingBlockIndex: _playingBlockIndex,
                        textBlockMaskColor:
                            AppTheme.primaryOf(context)
                                .withValues(alpha: 0.25),
                      ),
                    ),
                  if (page.textBlocks.isNotEmpty)
                    ..._buildTextBlockTapAreas(page, displaySize, imageSize),
                  _buildFocusBorder(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text block overlays
  // ---------------------------------------------------------------------------

  List<Widget> _buildTextBlockTapAreas(
      PageModel page, Size displaySize, Size imageSize) {
    final scaleX = displaySize.width /
        (page.imageWidth > 0 ? page.imageWidth : imageSize.width);
    final scaleY = displaySize.height /
        (page.imageHeight > 0 ? page.imageHeight : imageSize.height);

    List<Widget> widgets = [];

    for (int i = 0; i < page.textBlocks.length; i++) {
      final block = page.textBlocks[i];
      if (block.isDeleted) continue;

      final displayRect = Rect.fromLTRB(
        block.boundingBox.left * scaleX,
        block.boundingBox.top * scaleY,
        block.boundingBox.right * scaleX,
        block.boundingBox.bottom * scaleY,
      );

      const padding = 12.0;
      widgets.add(
        Positioned(
          left: displayRect.left - padding,
          top: displayRect.top - padding,
          width: displayRect.width + padding * 2,
          height: displayRect.height + padding * 2,
          child: Semantics(
            label: block.text,
            hint: '点击播放朗读',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _playTextBlock(block, i),
              onLongPress: () => _showBlockActionsBottomSheet(block, i),
              child: const Padding(
                padding: EdgeInsets.all(padding),
              ),
            ),
          ),
        ),
      );

      if (_loadingBlockIndex == i) {
        final tipHeight = (displayRect.height * 0.15).clamp(24.0, 40.0);
        final tipGap = (displayRect.height * 0.04).clamp(2.0, 8.0);
        final iconSize = (displayRect.height * 0.08).clamp(12.0, 16.0);
        widgets.add(
          Positioned(
            left: displayRect.left,
            top: displayRect.top - tipHeight - tipGap,
            width: displayRect.width,
            height: tipHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      (displayRect.height * 0.06).clamp(6.0, 10.0),
                  vertical: (displayRect.height * 0.04).clamp(4.0, 6.0),
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOf(context).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(
                      (displayRect.height * 0.04).clamp(4.0, 6.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    SizedBox(
                        width:
                            (displayRect.height * 0.04).clamp(4.0, 6.0)),
                    Text(
                      '加载中',
                      style: TextStyle(
                        fontSize:
                            (displayRect.height * 0.1).clamp(10.0, 13.0),
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
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
                  color: AppTheme.primaryOf(context),
                  width: (scaledRect.height * 0.03).clamp(2.0, 6.0),
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

  // ---------------------------------------------------------------------------
  // Reading bar
  // ---------------------------------------------------------------------------

  Widget _buildReadingBar() {
    final block =
        _book.pages[_currentPage].textBlocks[_translatedBlockIndex!];
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
                      const SizedBox(
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

  // ---------------------------------------------------------------------------
  // Long-press block actions
  // ---------------------------------------------------------------------------

  void _showBlockActionsBottomSheet(TextBlockModel block, int index) {
    _clearTranslation();
    final nfcEnabled = ref.read(nfcEnabledProvider);

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
                  color: AppTheme.mutedOf(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildActionTile(
                ctx,
                icon: Icons.edit,
                title: '编辑文字',
                subtitle: '修改此文字块的识别文本',
                color: AppTheme.primaryOf(context),
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
              color: AppTheme.onSurfaceOf(context))),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6))),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // ---------------------------------------------------------------------------
  // Block editing
  // ---------------------------------------------------------------------------

  void _updateBlockInPage(int index, TextBlockModel updatedBlock) {
    final page = _book.pages[_currentPage];
    final textBlocks = List<TextBlockModel>.from(page.textBlocks);
    textBlocks[index] = updatedBlock;
    _book.pages[_currentPage] = page.copyWith(textBlocks: textBlocks);
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
                        backgroundColor:
                            Colors.deepPurple.withValues(alpha: 0.85),
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

    final page = _book.pages[_currentPage];
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

    final page = _book.pages[_currentPage];
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

  // ---------------------------------------------------------------------------
  // NFC bind dialog
  // ---------------------------------------------------------------------------

  void _showNfcBindDialog(TextBlockModel block, int blockIndex) async {
    final nfcService = ref.read(nfcServiceProvider);
    final available = await nfcService.isAvailable();
    if (!available) {
      if (mounted) {
        ToastUtil.warning('此设备不支持 NFC 功能');
      }
      return;
    }

    final page = _book.pages[_currentPage];
    bool isWriting = false;
    String? errorMessage;

    if (!mounted) return;
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
                        await nfcService.writeTag(
                            _book.id, page.id, block.id);
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

  // ---------------------------------------------------------------------------
  // Voice settings dialog
  // ---------------------------------------------------------------------------

  void _showVoiceSettingsDialog() {
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
                        child: Icon(
                          Icons.record_voice_over_rounded,
                          color: AppTheme.primaryOf(context),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '当前语速',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '${(_currentSpeechRate * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.focusHighlightOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _currentSpeechRate,
                    min: _currentTtsEngine == 'supertonic'
                        ? AppConstants.supertonicMinSpeed
                        : AppConstants.systemTtsMinSpeed,
                    max: _currentTtsEngine == 'supertonic'
                        ? AppConstants.supertonicMaxSpeed
                        : AppConstants.systemTtsMaxSpeed,
                    divisions: _currentTtsEngine == 'supertonic'
                        ? AppConstants.supertonicSpeedDivisions
                        : AppConstants.systemTtsSpeedDivisions,
                    activeColor: AppTheme.primaryOf(context),
                    onChanged: (value) {
                      setDialogState(() {
                        _currentSpeechRate = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentTtsEngine == 'supertonic' ? '慢速' : '最慢',
                        style: TextStyle(
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                            fontSize: 12),
                      ),
                      Text(
                        _currentTtsEngine == 'system' ? '最快' : '快速',
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
                                      selectedModel: AppConstants.defaultModel,
                                    ))
                                .copyWith(
                              ttsEngine: _currentTtsEngine,
                              speechRate: _currentSpeechRate,
                            );
                            await ref
                                .read(storageServiceProvider)
                                .saveAiSettings(settings);

                            setState(() {});
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

  // ---------------------------------------------------------------------------
  // Utility widgets & methods
  // ---------------------------------------------------------------------------

  Widget _buildImageError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorOf(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 48,
              color: AppTheme.errorOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '图片不存在',
            style: TextStyle(color: AppTheme.mutedOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.sweetPink.withValues(alpha: 0.2),
                  AppTheme.lavender.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.pages_outlined,
              size: 64,
              color: AppTheme.primaryOf(context).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '读本还没有页面',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<Size> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final decodedImage = await decodeImageFromList(bytes);
    return Size(
      decodedImage.width.toDouble(),
      decodedImage.height.toDouble(),
    );
  }

  Size _calculateDisplaySize(Size imageSize, Size containerSize) {
    final imageAspect = imageSize.width / imageSize.height;
    final containerAspect = containerSize.width / containerSize.height;

    if (imageAspect > containerAspect) {
      return Size(containerSize.width, containerSize.width / imageAspect);
    } else {
      return Size(containerSize.height * imageAspect, containerSize.height);
    }
  }
}
