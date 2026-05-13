import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/book_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/text_block_model.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/image_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/ai_settings_model.dart';
import '../../core/constants/constants.dart';
import '../widgets/page_indicator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import 'voice_settings_page.dart';

class BookDetailPage extends StatefulWidget {
  final BookModel book;

  const BookDetailPage({
    super.key,
    required this.book,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late BookModel _book;
  int _currentPageIndex = 0;
  bool _showBorders = true;
  bool _showAppBar = true;
  String? _playingText;
  int? _playingBlockIndex;
  int? _tappedBlockIndex;
  double _currentSpeechRate = AppConstants.systemTtsDefaultSpeed;
  bool _currentUseGlmTts = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _currentPageIndex = _book.currentPageIndex;

    _initTts();
    _loadVoiceSettings();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initTts() async {
    await TtsService.instance.initialize();
  }

  void _loadVoiceSettings() {
    final settings = StorageService.instance.getAiSettings();
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

  @override
  void dispose() {
    TtsService.instance.stop();
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
                color: Colors.white,
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
                          color: AppTheme.gentleGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.record_voice_over_rounded,
                          color: AppTheme.gentleGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '语音设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warmBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '当前语速',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '${(_currentSpeechRate * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gentleGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _currentSpeechRate,
                    min: _currentUseGlmTts ? AppConstants.glmTtsMinSpeed : AppConstants.systemTtsMinSpeed,
                    max: _currentUseGlmTts ? AppConstants.glmTtsMaxSpeed : AppConstants.systemTtsMaxSpeed,
                    divisions: _currentUseGlmTts ? AppConstants.glmTtsSpeedDivisions : AppConstants.systemTtsSpeedDivisions,
                    activeColor: AppTheme.gentleGreen,
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
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        _currentUseGlmTts ? '快速' : '最快',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const VoiceSettingsPage()),
                            ).then((_) {
                              _loadVoiceSettings();
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            '更多设置',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final currentSettings = StorageService.instance.getAiSettings();
                            final settings = AiSettingsModel(
                              selectedModel: currentSettings?.selectedModel ?? AppConstants.defaultModel,
                              useGlmTts: _currentUseGlmTts,
                              ttsVoice: currentSettings?.ttsVoice ?? AppConstants.defaultTtsVoice,
                              speechRate: _currentSpeechRate,
                            );
                            await StorageService.instance.saveAiSettings(settings);
                            
                            setState(() {});
                            Navigator.pop(context);
                            
                            ToastUtil.success('语速已调整');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gentleGreen,
                            foregroundColor: Colors.white,
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
      setState(() => _currentPageIndex--);
    }
  }

  void _goToNextPage() {
    if (_currentPageIndex < _book.pages.length - 1) {
      setState(() => _currentPageIndex++);
    }
  }

  void _toggleAppBar() {
    setState(() => _showAppBar = !_showAppBar);
  }

  void _toggleBorders() {
    setState(() => _showBorders = !_showBorders);
  }

  Future<void> _playTextBlock(TextBlockModel block, int blockIndex) async {
    setState(() => _tappedBlockIndex = blockIndex);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _tappedBlockIndex = null);
    });

    if (_playingText != null) {
      await TtsService.instance.stop();
      setState(() {
        _playingText = null;
        _playingBlockIndex = null;
      });
    }

    setState(() {
      _playingText = block.text;
      _playingBlockIndex = blockIndex;
    });

    try {
      await TtsService.instance.speak(block.text);
    } catch (e) {
      if (e is GlmTtsException) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B6B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.volume_off_rounded,
                      size: 32,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '朗读失败',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.userMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.warmBrown.withOpacity(0.7),
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
                      if (e.isBalanceInsufficient())
                        const SizedBox(width: 8),
                      if (e.isBalanceInsufficient())
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/settings');
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

    setState(() {
      _playingText = null;
      _playingBlockIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: AppTheme.softOrange.withOpacity(0.85),
              elevation: 0,
              title: Row(
                children: [
                  Text(_book.title),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                         SizedBox(width: 4),
                         Text(
                          '阅读',
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _showBorders ? Icons.border_color_rounded : Icons.border_clear_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: _toggleBorders,
                  tooltip: _showBorders ? '隐藏边框' : '显示边框',
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppTheme.softOrange,
                      Color(0xFFFF8C42),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: AppTheme.readingPageGradient,
        child: Stack(
          children: [
            SafeArea(
              child: GestureDetector(
                onDoubleTap: _toggleAppBar,
                child: _book.pages.isEmpty
                    ? _buildEmptyState()
                    : _buildPageView(),
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
            
            if (_playingText != null)
              Positioned(
                bottom: 60,
                left: MediaQuery.of(context).padding.left,
                right: MediaQuery.of(context).padding.right,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.honeyYellow,
                          AppTheme.softOrange,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.honeyYellow.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(
                            '正在朗读: ${_playingText!.length > 30 ? '${_playingText!.substring(0, 30)}...' : _playingText}',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            TtsService.instance.stop();
                            setState(() {
                              _playingText = null;
                              _playingBlockIndex = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.stop_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  AppTheme.sweetPink.withOpacity(0.2),
                  AppTheme.lavender.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              Icons.pages_outlined,
              size: 64,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '点读本还没有页面',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.warmBrown,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.honeyYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '请在点读本列表长按进入编辑模式',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.warmBrown.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
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
    final imageFile = ImageService.instance.getImageFile(page.imagePath);

    if (imageFile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B6B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.image_not_supported_rounded,
                size: 48,
                color: Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '图片不存在',
              style: TextStyle(color: AppTheme.softGray),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
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
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                final imageSize = snapshot.data!;
                final displaySize = _calculateDisplaySize(
                    imageSize, Size(constraints.maxWidth, constraints.maxHeight));

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
                                painter: TextBlockPainter(
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
                              ..._buildTextBlockTapAreas(page, displaySize, imageSize),
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

      final isTapped = _tappedBlockIndex == i;

      widgets.add(
        Positioned(
          left: displayRect.left,
          top: displayRect.top,
          width: displayRect.width,
          height: displayRect.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _playTextBlock(block, i),
            child: AnimatedScale(
              scale: isTapped ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: SizedBox(
                width: displayRect.width,
                height: displayRect.height,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isTapped
                        ? AppTheme.honeyYellow.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: isTapped
                        ? Border.all(
                            color: AppTheme.honeyYellow.withOpacity(0.6),
                            width: 2,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Future<Size> _getImageSize(File file) async {
    final bytes = file.readAsBytesSync();
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

class TextBlockPainter extends CustomPainter {
  final List<TextBlockModel> textBlocks;
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;
  final int? playingBlockIndex;

  TextBlockPainter({
    required this.textBlocks,
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
    this.playingBlockIndex,
  });

  double get scaleX => displayWidth / imageWidth;
  double get scaleY => displayHeight / imageHeight;

  Rect _convertRect(Rect originalRect) {
    return Rect.fromLTRB(
      originalRect.left * scaleX,
      originalRect.top * scaleY,
      originalRect.right * scaleX,
      originalRect.bottom * scaleY,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < textBlocks.length; i++) {
      final block = textBlocks[i];
      if (block.isDeleted) continue;

      final displayRect = _convertRect(block.boundingBox);
      final isPlaying = i == playingBlockIndex;

      final borderPaint = Paint()
        ..color = isPlaying
            ? AppTheme.honeyYellow.withOpacity(0.9)
            : AppTheme.gentleGreen.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPlaying ? 3.5 : 2.5;

      canvas.drawRRect(
        RRect.fromRectAndRadius(displayRect, const Radius.circular(4)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TextBlockPainter oldDelegate) {
    return oldDelegate.textBlocks != textBlocks ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.displayWidth != displayWidth ||
        oldDelegate.displayHeight != displayHeight ||
        oldDelegate.playingBlockIndex != playingBlockIndex;
  }
}