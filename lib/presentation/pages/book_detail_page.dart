import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/book_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/text_block_model.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/nfc_service.dart';
import '../../data/services/translation_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../providers/service_providers.dart';
import '../widgets/page_indicator.dart';
import '../widgets/reading_text_block_painter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/toast_util.dart';
import '../../core/utils/platform_utils.dart';
import '../providers/settings_provider.dart';

class BookDetailPage extends ConsumerStatefulWidget {
  final BookModel book;
  final String? autoPlayPageId;
  final String? autoPlayBlockId;

  const BookDetailPage({
    super.key,
    required this.book,
    this.autoPlayPageId,
    this.autoPlayBlockId,
  });

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage>
    with TickerProviderStateMixin {
  late BookModel _book;
  int _currentPageIndex = 0;
  bool _showBorders = true;
  bool _showAppBar = true;
  bool _showTranslation = !Platform.isMacOS;
  String? _playingText;
  int? _playingBlockIndex;
  int? _loadingBlockIndex;
  Timer? _loadingIndicatorTimer;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  bool _currentUseGlmTts = false;
  StreamSubscription<NfcAction>? _nfcSubscription;
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
  ({TextBlockModel block, int index})? _pendingAutoPlay;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _currentPageIndex = _book.currentPageIndex;

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

    _initNfc();
    _initTtsCallbacks();
    _loadVoiceSettings();

    if (widget.autoPlayPageId != null && widget.autoPlayBlockId != null) {
      TtsService.instance.initialize().then((_) {
        if (mounted) _autoPlayFromNfc();
      });
    }
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

  void _initNfc() {
    final nfcEnabled = ref.read(nfcEnabledProvider);
    if (!nfcEnabled) return;

    final nfcService = ref.read(nfcServiceProvider);
    nfcService.startForegroundListening();
    _nfcSubscription = nfcService.onTagDetected.listen((action) {
      if (action.bookId == _book.id) {
        nfcService.markActionConsumed();
        _playFromNfcAction(action);
      }
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
    setState(() {
      _currentPageIndex = targetPageIndex!;
    });

    final block = page.textBlocks[targetBlockIndex];
    if (_displaySize == null || _imageSize == null) {
      _pendingAutoPlay = (block: block, index: targetBlockIndex);
    } else {
      _playTextBlock(block, targetBlockIndex);
    }
  }

  void _loadVoiceSettings() {
    final settings = ref.read(storageServiceProvider).getAiSettings();
    setState(() {
      _currentUseGlmTts = settings?.useGlmTts ?? false;
      if (settings?.speechRate != null && settings!.speechRate > 0) {
        _currentSpeechRate = settings.speechRate;
      } else {
        _currentSpeechRate = _currentUseGlmTts
            ? AppConstants.glmTtsDefaultSpeed
            : AppConstants.systemTtsDefaultSpeed;
      }
    });
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

    setState(() {
      _currentPageIndex = targetPageIndex!;
    });

    final block = page.textBlocks[targetBlockIndex];
    if (_displaySize == null || _imageSize == null) {
      _pendingAutoPlay = (block: block, index: targetBlockIndex);
    } else {
      _playTextBlock(block, targetBlockIndex);
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

    final page = _book.pages[_currentPageIndex];
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
                            errorMessage = '绑定失败，请重试';
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

  @override
  void dispose() {
    final ttsService = TtsService.instance;
    ttsService.onLoadingStarted = null;
    ttsService.onPlayingStarted = null;
    _nfcSubscription?.cancel();
    _loadingIndicatorTimer?.cancel();
    _focusAnimationController.dispose();
    _bounceAnimationController.dispose();
    super.dispose();
  }

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
                    min: _currentUseGlmTts
                        ? AppConstants.glmTtsMinSpeed
                        : AppConstants.systemTtsMinSpeed,
                    max: _currentUseGlmTts
                        ? AppConstants.glmTtsMaxSpeed
                        : AppConstants.systemTtsMaxSpeed,
                    divisions: _currentUseGlmTts
                        ? AppConstants.glmTtsSpeedDivisions
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
                        _currentUseGlmTts ? '慢速' : '最慢',
                        style: TextStyle(
                            color: AppTheme.onSurfaceOf(context)
                                .withValues(alpha: 0.6),
                            fontSize: 12),
                      ),
                      Text(
                        _currentUseGlmTts ? '快速' : '最快',
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
                              useGlmTts: _currentUseGlmTts,
                              speechRate: _currentSpeechRate,
                            );
                            await ref
                                .read(storageServiceProvider)
                                .saveAiSettings(settings);

                            setState(() {});
                            Navigator.pop(context);

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

  void _goToPreviousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
        _clearTranslation();
      });
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _book.pages.length - 1) {
      setState(() {
        _currentPageIndex++;
        _clearTranslation();
      });
    }
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

  Future<void> _playTextBlock(TextBlockModel block, int blockIndex) async {
    if (kDebugMode) {
      debugPrint(
          '>>> _playTextBlock called: blockIndex=$blockIndex, text=${block.text.length > 20 ? block.text.substring(0, 20) : block.text}...');
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
    if (_currentUseGlmTts) {
      _loadingIndicatorTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted &&
            _playingBlockIndex == blockIndex &&
            _loadingBlockIndex == null) {
          setState(() => _loadingBlockIndex = blockIndex);
        }
      });
    }

    try {
      if (!mounted) return;
      await ref.read(ttsServiceProvider).speak(block.text);
    } catch (e) {
      if (!mounted) return;
      if (e is GlmTtsException) {
        _loadingIndicatorTimer?.cancel();
        setState(() {
          _loadingBlockIndex = null;
        });
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceOf(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorOf(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.volume_off_rounded,
                      size: 32,
                      color: AppTheme.errorOf(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '朗读失败',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceOf(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.userMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('确定'),
                      ),
                      if (e.isBalanceInsufficient()) const SizedBox(width: 8),
                      if (e.isBalanceInsufficient())
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/settings');
                          },
                          child: const Text('去设置'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _playingText = null;
      });
    }
  }

  void _updateFocusAnimation(TextBlockModel block) {
    if (_displaySize == null || _imageSize == null) return;

    final page = _book.pages[_currentPageIndex];
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

    if (kDebugMode) {
      debugPrint('=== Focus Animation Debug ===');
      debugPrint('isSameBlock: $isSameBlock');
      debugPrint('_previousFocusRect: $_previousFocusRect');
      debugPrint('targetRect: $targetRect');
      debugPrint('_hasPlayedBefore: $_hasPlayedBefore');
    }

    Rect beginRect;
    Rect endRect;
    Curve curve;

    if (!_hasPlayedBefore) {
      if (kDebugMode) {
        debugPrint('Case: First play - full screen to target');
      }
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
      if (kDebugMode) {
        debugPrint('Case: Same block - direct bounce (no fly animation)');
      }
      _focusAnimation = RectTween(
        begin: targetRect,
        end: targetRect,
      ).animate(_focusAnimationController);
      _focusAnimationController.duration = Duration.zero;
      _focusAnimationController.forward(from: 0.0);
      _startBounceAnimation();
      return;
    } else {
      if (kDebugMode) {
        debugPrint('Case: Different block - transition');
      }
      beginRect = _previousFocusRect ?? targetRect;
      endRect = targetRect;
      curve = Curves.easeInOut;
      _focusAnimationController.duration = AppAnim.quick;
    }

    if (kDebugMode) {
      debugPrint('beginRect: $beginRect');
      debugPrint('endRect: $endRect');
      debugPrint('curve: $curve');
      debugPrint('============================');
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

  void _replayCurrentBlock() {
    if (_translatedBlockIndex == null) return;
    final page = _book.pages[_currentPageIndex];
    if (_translatedBlockIndex! >= page.textBlocks.length) return;
    final block = page.textBlocks[_translatedBlockIndex!];
    _playTextBlock(block, _translatedBlockIndex!);
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
      final page = _book.pages[_currentPageIndex];
      final updatedTextBlocks = List<TextBlockModel>.from(page.textBlocks);
      updatedTextBlocks[blockIndex] = updatedBlock;
      final updatedPage = page.copyWith(textBlocks: updatedTextBlocks);
      _book.pages[_currentPageIndex] = updatedPage;
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
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
                const SizedBox(width: 8),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.appBarGradientOf(context),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: isDark
            ? BoxDecoration(color: AppTheme.darkBackground)
            : AppTheme.readingPageGradient,
        child: Stack(
          children: [
            SafeArea(
              child: GestureDetector(
                onDoubleTap: _toggleAppBar,
                child:
                    _book.pages.isEmpty ? _buildEmptyState() : _buildPageView(),
              ),
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
            if (_book.pages.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: PageIndicator(
                    currentPage: _currentPageIndex,
                    totalPages: _book.pages.length,
                    onPrevious: _goToPreviousPage,
                    onNext: _goToNextPage,
                  ),
                ),
              ),
          ],
        ),
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                context.push('/book/${_book.id}/manage', extra: _book),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('添加页面'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppTheme.primaryOf(context).withValues(alpha: 0.85),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    final page = _book.pages[_currentPageIndex];
    return _buildPageContent(page);
  }

  Widget _buildPageContent(PageModel page) {
    final imageFile =
        ref.read(imageServiceProvider).getImageFile(page.imagePath);

    if (imageFile == null) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          key: ValueKey(_currentPageIndex),
          minScale: 0.5,
          maxScale: 4.0,
          child: Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FutureBuilder<Size>(
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
                final displaySize = _calculateDisplaySize(imageSize,
                    Size(constraints.maxWidth, constraints.maxHeight));

                _displaySize = displaySize;
                _imageSize = imageSize;

                if (_pendingAutoPlay != null) {
                  final pending = _pendingAutoPlay!;
                  _pendingAutoPlay = null;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _playTextBlock(pending.block, pending.index);
                  });
                }

                return Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.playfulShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                                ),
                              ),
                            if (page.textBlocks.isNotEmpty)
                              ..._buildTextBlockTapAreas(
                                  page, displaySize, imageSize),
                            _buildFocusBorder(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
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

      final padding = 12.0;
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
              onLongPress: () {
                final nfcEnabled = ref.read(nfcEnabledProvider);
                if (nfcEnabled) {
                  _showNfcBindDialog(block, i);
                }
              },
              child: Padding(
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
                  horizontal: (displayRect.height * 0.06).clamp(6.0, 10.0),
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
                        width: (displayRect.height * 0.04).clamp(4.0, 6.0)),
                    Text(
                      '加载中',
                      style: TextStyle(
                        fontSize: (displayRect.height * 0.1).clamp(10.0, 13.0),
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

  Widget _buildReadingBar() {
    final block =
        _book.pages[_currentPageIndex].textBlocks[_translatedBlockIndex!];
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
      bottom: 64,
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
