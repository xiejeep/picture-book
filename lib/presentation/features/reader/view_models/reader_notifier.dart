import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/services/translation_service.dart';
import 'package:book_app/presentation/features/reader/models/reader_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderNotifier extends AutoDisposeNotifier<ReaderState> {
  ReaderNotifier(this._initialBook);

  final BookModel? _initialBook;

  @override
  ReaderState build() {
    final book = _initialBook;
    if (book == null) {
      return ReaderState(
        book: BookModel(
          id: '',
          title: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          pages: [],
        ),
      );
    }
    return ReaderState(book: book, currentIndex: book.currentPageIndex);
  }

  void updateBook(BookModel book) {
    state = state.copyWith(book: book);
  }

  void setCurrentIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void toggleAppBar() {
    state = state.copyWith(showAppBar: !state.showAppBar);
  }

  void toggleBorders() {
    state = state.copyWith(showBorders: !state.showBorders);
  }

  void toggleTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }

  void setPlaybackLoading(int blockIndex, String text) {
    state = state.copyWith(
      playingText: text,
      playingBlockIndex: blockIndex,
      loadingBlockIndex: blockIndex,
    );
  }

  void setPlaybackStarted() {
    state = state.copyWith(clearLoadingBlockIndex: true);
  }

  void clearPlayback() {
    state = state.copyWith(
      clearPlayingText: true,
      clearPlayingBlockIndex: true,
      clearLoadingBlockIndex: true,
    );
  }

  void setTranslationLoading(int blockIndex) {
    state = state.copyWith(
      translatedBlockIndex: blockIndex,
      clearTranslatedText: true,
      isTranslating: true,
      translationStatus: TranslationStatus.translating,
    );
  }

  void setCachedTranslation(int blockIndex, String text) {
    state = state.copyWith(
      translatedBlockIndex: blockIndex,
      translatedText: text,
      isTranslating: false,
      translationStatus: TranslationStatus.done,
    );
  }

  void setTranslationResult({
    required TranslationStatus status,
    String? translatedText,
  }) {
    state = state.copyWith(
      isTranslating: false,
      translationStatus: status,
      translatedText: translatedText,
    );
  }

  void setTranslatedBlock(int blockIndex, String text) {
    state = state.copyWith(
      translatedText: text,
      translatedBlockIndex: blockIndex,
    );
  }

  void clearTranslation() {
    state = state.copyWith(
      clearTranslatedBlockIndex: true,
      clearTranslatedText: true,
      isTranslating: false,
      translationStatus: TranslationStatus.idle,
      clearPlayingBlockIndex: true,
      clearPlayingText: true,
    );
  }
}

final readerProvider =
    AutoDisposeNotifierProvider<ReaderNotifier, ReaderState>(() {
  return ReaderNotifier(null);
});
