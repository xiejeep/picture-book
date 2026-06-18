import 'dart:io';

import 'package:book_app/core/theme/app_theme.dart';
import 'package:book_app/data/models/page_model.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_app_bar.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_empty_state.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_gallery.dart';
import 'package:book_app/presentation/features/reader/widgets/reader_reading_bar.dart';
import 'package:book_app/presentation/widgets/page_indicator.dart';
import 'package:book_app/vendor/photo_view/photo_view.dart';
import 'package:flutter/material.dart';
import 'package:book_app/presentation/features/reader/models/reader_state.dart';

class BookReaderView extends StatelessWidget {
  final ReaderState readingState;
  final PageController pageController;
  final double loadingAnimationValue;
  final Animation<Rect?>? focusAnimation;
  final Rect? currentFocusRect;
  final Animation<double>? bounceAnimation;
  final Listenable focusBounceAnimation;
  final bool supportsTranslation;
  final bool showNfcScan;
  final File? Function(String imagePath) imageFileResolver;
  final VoidCallback onEditBook;
  final VoidCallback onToggleAppBar;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleBorders;
  final VoidCallback onVoiceSettings;
  final VoidCallback onScanNfc;
  final VoidCallback onDoubleTap;
  final void Function(TapDownDetails details, PhotoViewControllerValue ctrlVal,
      PageModel page) onTapDown;
  final void Function(BuildContext context, TapUpDetails details,
      PhotoViewControllerValue ctrlVal, PageModel page) onTapUp;
  final VoidCallback onScaleEnd;
  final void Function(int index) onPageChanged;
  final VoidCallback onStopPlaying;
  final VoidCallback onReplay;
  final VoidCallback onClose;

  const BookReaderView({
    super.key,
    required this.readingState,
    required this.pageController,
    required this.loadingAnimationValue,
    required this.focusAnimation,
    required this.currentFocusRect,
    required this.bounceAnimation,
    required this.focusBounceAnimation,
    required this.supportsTranslation,
    required this.showNfcScan,
    required this.imageFileResolver,
    required this.onEditBook,
    required this.onToggleAppBar,
    required this.onToggleTranslation,
    required this.onToggleBorders,
    required this.onVoiceSettings,
    required this.onScanNfc,
    required this.onDoubleTap,
    required this.onTapDown,
    required this.onTapUp,
    required this.onScaleEnd,
    required this.onPageChanged,
    required this.onStopPlaying,
    required this.onReplay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final book = readingState.book;
    final pages = book.pages;

    if (pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(book.title),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.appBarGradientOf(context),
            ),
          ),
        ),
        body: Container(
          decoration: AppTheme.gradientBoxOf(context),
          child: ReaderEmptyState(
            bookTitle: book.title,
            onEditBook: onEditBook,
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: readingState.showAppBar
          ? ReaderAppBar(
              title: book.title,
              showTranslation: readingState.showTranslation,
              showBorders: readingState.showBorders,
              supportsTranslation: supportsTranslation,
              showNfcScan: showNfcScan,
              onVoiceSettings: onVoiceSettings,
              onToggleAppBar: onToggleAppBar,
              onToggleTranslation: onToggleTranslation,
              onToggleBorders: onToggleBorders,
              onScanNfc: onScanNfc,
            )
          : null,
      body: Stack(
        children: [
          ReaderGallery(
            pages: pages,
            pageController: pageController,
            showBorders: readingState.showBorders,
            playingBlockIndex: readingState.playingBlockIndex,
            loadingBlockIndex: readingState.loadingBlockIndex,
            loadingAnimationValue: loadingAnimationValue,
            focusAnimation: focusAnimation,
            currentFocusRect: currentFocusRect,
            bounceAnimation: bounceAnimation,
            focusBounceAnimation: focusBounceAnimation,
            imageFileResolver: imageFileResolver,
            onDoubleTap: onDoubleTap,
            onTapDown: onTapDown,
            onTapUp: onTapUp,
            onScaleEnd: onScaleEnd,
            onPageChanged: onPageChanged,
          ),
          if (!readingState.showAppBar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: onToggleAppBar,
                child: Container(
                  height: 60,
                  color: Colors.transparent,
                ),
              ),
            ),
          if (readingState.translatedBlockIndex != null)
            ReaderReadingBar(
              block: book.pages[readingState.currentIndex]
                  .textBlocks[readingState.translatedBlockIndex!],
              isPlaying: readingState.playingText != null,
              showTranslation: readingState.showTranslation,
              isTranslating: readingState.isTranslating,
              translationStatus: readingState.translationStatus,
              translatedText: readingState.translatedText,
              onStopPlaying: onStopPlaying,
              onReplay: onReplay,
              onClose: onClose,
            ),
          if (pages.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: PageIndicator(
                  currentPage: readingState.currentIndex,
                  totalPages: pages.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
