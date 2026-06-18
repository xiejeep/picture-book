import 'dart:io';

import 'package:book_app/data/models/page_model.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_focus_border.dart';
import 'package:book_app/presentation/widgets/reading_text_block_painter.dart';
import 'package:book_app/vendor/photo_view/photo_view.dart';
import 'package:book_app/vendor/photo_view/photo_view_gallery.dart';
import 'package:flutter/material.dart';

class ReaderGallery extends StatelessWidget {
  final List<PageModel> pages;
  final PageController pageController;
  final bool showBorders;
  final int? playingBlockIndex;
  final int? loadingBlockIndex;
  final double loadingAnimationValue;
  final Animation<Rect?>? focusAnimation;
  final Rect? currentFocusRect;
  final Animation<double>? bounceAnimation;
  final Listenable focusBounceAnimation;
  final File? Function(String imagePath) imageFileResolver;
  final VoidCallback onDoubleTap;
  final void Function(TapDownDetails details, PhotoViewControllerValue ctrlVal,
      PageModel page) onTapDown;
  final void Function(BuildContext context, TapUpDetails details,
      PhotoViewControllerValue ctrlVal, PageModel page) onTapUp;
  final VoidCallback onScaleEnd;
  final void Function(int index) onPageChanged;

  const ReaderGallery({
    super.key,
    required this.pages,
    required this.pageController,
    required this.showBorders,
    required this.playingBlockIndex,
    required this.loadingBlockIndex,
    required this.loadingAnimationValue,
    required this.focusAnimation,
    required this.currentFocusRect,
    required this.bounceAnimation,
    required this.focusBounceAnimation,
    required this.imageFileResolver,
    required this.onDoubleTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onScaleEnd,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (context, index) {
        final page = pages[index];
        final file = imageFileResolver(page.imagePath);
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
                const Image(
                  image: AssetImage('assets/placeholder.png'),
                  fit: BoxFit.contain,
                ),
              if (hasValidSize && activeBlocks.isNotEmpty && showBorders)
                CustomPaint(
                  size: imageSize,
                  painter: ReadingTextBlockPainter(
                    textBlocks: page.textBlocks,
                    imageWidth: page.imageWidth,
                    imageHeight: page.imageHeight,
                    displayWidth: page.imageWidth,
                    displayHeight: page.imageHeight,
                    playingBlockIndex: playingBlockIndex,
                    loadingBlockIndex: loadingBlockIndex,
                    loadingAnimationValue: loadingAnimationValue,
                    textBlockMaskColor: Colors.orange.withValues(alpha: 0.25),
                  ),
                ),
              ReaderFocusBorder(
                focusAnimation: focusAnimation,
                currentFocusRect: currentFocusRect,
                bounceAnimation: bounceAnimation,
                animation: focusBounceAnimation,
              ),
            ],
          ),
          childSize: hasValidSize ? imageSize : null,
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 3,
          onDoubleTap: onDoubleTap,
          heroAttributes: PhotoViewHeroAttributes(tag: page.imagePath),
          onTapDown: (context, details, ctrlVal) =>
              onTapDown(details, ctrlVal, page),
          onTapUp: (context, details, ctrlVal) =>
              onTapUp(context, details, ctrlVal, page),
          onScaleEnd: (context, details, ctrlVal) => onScaleEnd(),
        );
      },
      itemCount: pages.length,
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      pageController: pageController,
      onPageChanged: onPageChanged,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );
  }
}
