import 'dart:async';
import 'dart:io';

import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/models/page_model.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/image_service.dart';
import 'package:book_app/data/services/tts_service.dart';
import 'package:book_app/presentation/widgets/reading_text_block_painter.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class BookReaderPage extends StatefulWidget {
  final BookModel book;

  const BookReaderPage({
    super.key,
    required this.book,
  });

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  late PageController _pageController;
  int _currentIndex;
  int? _playingBlockIndex;
  Size _viewportSize = Size.zero;
  Timer? _longPressTimer;

  _BookReaderPageState() : _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.book.currentPageIndex;
    _pageController = PageController(initialPage: _currentIndex);
    TtsService.instance.onPlayingComplete = _onTtsComplete;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    if (TtsService.instance.onPlayingComplete == _onTtsComplete) {
      TtsService.instance.onPlayingComplete = null;
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onTtsComplete() {
    if (mounted) {
      setState(() {
        _playingBlockIndex = null;
      });
    }
  }

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
    if (block == null) return;

    final index = page.textBlocks.indexOf(block);
    setState(() {
      _playingBlockIndex = index;
    });

    TtsService.instance.speak(block.text);
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

    _showBlockDetailSheet(block);
  }

  void _showBlockDetailSheet(TextBlockModel block) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (block.translatedText != null &&
                block.translatedText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '翻译: ${block.translatedText}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
            if (block.aiEnhancedText != null &&
                block.aiEnhancedText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'AI 增强: ${block.aiEnhancedText}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blueGrey,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  TtsService.instance.speak(block.text);
                  Navigator.pop(ctx);
                },
                child: const Text('朗读'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _viewportSize = MediaQuery.of(context).size;
    final pages = widget.book.pages;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (context, index) {
              final page = pages[index];
              final file = _imageFile(page.imagePath);
              final imageSize = Size(page.imageWidth, page.imageHeight);
              final hasValidSize = imageSize.width > 0 && imageSize.height > 0;
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
                        image: AssetImage('assets/placeholder.png'),
                        fit: BoxFit.contain,
                      ),
                    if (hasValidSize && activeBlocks.isNotEmpty)
                      CustomPaint(
                        size: imageSize,
                        painter: ReadingTextBlockPainter(
                          textBlocks: page.textBlocks,
                          imageWidth: page.imageWidth,
                          imageHeight: page.imageHeight,
                          displayWidth: page.imageWidth,
                          displayHeight: page.imageHeight,
                          playingBlockIndex: _playingBlockIndex,
                          textBlockMaskColor:
                              Colors.orange.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
                childSize: hasValidSize ? imageSize : null,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 3,
                heroAttributes: PhotoViewHeroAttributes(tag: page.imagePath),
                onTapDown: (context, details, ctrlVal) =>
                    _onTapDown(details, ctrlVal, page),
                onTapUp: (context, details, ctrlVal) =>
                    _handleTapUp(context, details, ctrlVal, page),
                onScaleEnd: (context, details, ctrlVal) => _cancelLongPress(),
              );
            },
            itemCount: pages.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _playingBlockIndex = null;
              });
            },
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (pages.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${pages.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
