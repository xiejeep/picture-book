import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/services/translation_service.dart';

class ReaderState {
  final BookModel book;
  final int currentIndex;
  final int? playingBlockIndex;
  final int? loadingBlockIndex;
  final String? playingText;
  final bool showBorders;
  final bool showAppBar;
  final bool showTranslation;
  final int? translatedBlockIndex;
  final String? translatedText;
  final bool isTranslating;
  final TranslationStatus translationStatus;

  const ReaderState({
    required this.book,
    this.currentIndex = 0,
    this.playingBlockIndex,
    this.loadingBlockIndex,
    this.playingText,
    this.showBorders = true,
    this.showAppBar = true,
    this.showTranslation = true,
    this.translatedBlockIndex,
    this.translatedText,
    this.isTranslating = false,
    this.translationStatus = TranslationStatus.idle,
  });

  ReaderState copyWith({
    BookModel? book,
    int? currentIndex,
    int? playingBlockIndex,
    int? loadingBlockIndex,
    String? playingText,
    bool? showBorders,
    bool? showAppBar,
    bool? showTranslation,
    int? translatedBlockIndex,
    String? translatedText,
    bool? isTranslating,
    TranslationStatus? translationStatus,
    bool clearPlayingBlockIndex = false,
    bool clearPlayingText = false,
    bool clearLoadingBlockIndex = false,
    bool clearTranslatedBlockIndex = false,
    bool clearTranslatedText = false,
  }) {
    return ReaderState(
      book: book ?? this.book,
      currentIndex: currentIndex ?? this.currentIndex,
      playingBlockIndex: clearPlayingBlockIndex
          ? null
          : (playingBlockIndex ?? this.playingBlockIndex),
      loadingBlockIndex: clearLoadingBlockIndex
          ? null
          : (loadingBlockIndex ?? this.loadingBlockIndex),
      playingText: clearPlayingText ? null : (playingText ?? this.playingText),
      showBorders: showBorders ?? this.showBorders,
      showAppBar: showAppBar ?? this.showAppBar,
      showTranslation: showTranslation ?? this.showTranslation,
      translatedBlockIndex: clearTranslatedBlockIndex
          ? null
          : (translatedBlockIndex ?? this.translatedBlockIndex),
      translatedText:
          clearTranslatedText ? null : (translatedText ?? this.translatedText),
      isTranslating: isTranslating ?? this.isTranslating,
      translationStatus: translationStatus ?? this.translationStatus,
    );
  }
}
