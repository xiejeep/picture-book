import 'package:flutter_test/flutter_test.dart';
import 'package:book_app/data/models/book_model.dart';
import 'package:book_app/data/services/translation_service.dart';
import 'package:book_app/presentation/features/reader/models/reader_state.dart';

void main() {
  late BookModel book;
  late ReaderState state;

  setUp(() {
    book = BookModel(
      id: 'test-book',
      title: 'Test Book',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      pages: [],
    );
    state = ReaderState(book: book, currentIndex: 0);
  });

  group('ReaderState defaults', () {
    test('has correct defaults', () {
      expect(state.currentIndex, 0);
      expect(state.showBorders, true);
      expect(state.showAppBar, true);
      expect(state.showTranslation, true);
      expect(state.isTranslating, false);
      expect(state.translationStatus, TranslationStatus.idle);
      expect(state.playingBlockIndex, isNull);
      expect(state.loadingBlockIndex, isNull);
      expect(state.playingText, isNull);
      expect(state.translatedBlockIndex, isNull);
      expect(state.translatedText, isNull);
    });
  });

  group('ReaderState.copyWith basic', () {
    test('updates currentIndex', () {
      final updated = state.copyWith(currentIndex: 3);
      expect(updated.currentIndex, 3);
    });

    test('updates booleans', () {
      final updated = state.copyWith(
        showAppBar: false,
        showBorders: false,
        showTranslation: false,
        isTranslating: true,
      );
      expect(updated.showAppBar, false);
      expect(updated.showBorders, false);
      expect(updated.showTranslation, false);
      expect(updated.isTranslating, true);
    });

    test('keeps original values with no args', () {
      final updated = state.copyWith();
      expect(updated.currentIndex, 0);
      expect(updated.showBorders, true);
    });

    test('updates book', () {
      final newBook = BookModel(
        id: 'other',
        title: 'Other',
        createdAt: DateTime(2024, 2, 2),
        updatedAt: DateTime(2024, 2, 2),
        pages: [],
      );
      final updated = state.copyWith(book: newBook);
      expect(updated.book.id, 'other');
    });
  });

  group('ReaderState.copyWith nullable fields', () {
    test('sets playingBlockIndex', () {
      final updated = state.copyWith(playingBlockIndex: 5);
      expect(updated.playingBlockIndex, 5);
    });

    test('sets playingText', () {
      final updated = state.copyWith(playingText: 'hello');
      expect(updated.playingText, 'hello');
    });

    test('partial null keeps original', () {
      final withValue = state.copyWith(playingBlockIndex: 5);
      final partial = withValue.copyWith(playingBlockIndex: null);
      expect(partial.playingBlockIndex, 5);
    });

    test('clearPlayingBlockIndex sets to null', () {
      final withValue = state.copyWith(playingBlockIndex: 5);
      final cleared = withValue.copyWith(clearPlayingBlockIndex: true);
      expect(cleared.playingBlockIndex, isNull);
    });

    test('clearPlayingText sets to null', () {
      final withValue = state.copyWith(playingText: 'hello');
      final cleared = withValue.copyWith(clearPlayingText: true);
      expect(cleared.playingText, isNull);
    });

    test('clearLoadingBlockIndex sets to null', () {
      final withValue = state.copyWith(loadingBlockIndex: 3);
      final cleared = withValue.copyWith(clearLoadingBlockIndex: true);
      expect(cleared.loadingBlockIndex, isNull);
    });

    test('clearTranslatedBlockIndex sets to null', () {
      final withValue = state.copyWith(translatedBlockIndex: 2);
      final cleared = withValue.copyWith(clearTranslatedBlockIndex: true);
      expect(cleared.translatedBlockIndex, isNull);
    });

    test('clearTranslatedText sets to null', () {
      final withValue = state.copyWith(translatedText: '你好');
      final cleared = withValue.copyWith(clearTranslatedText: true);
      expect(cleared.translatedText, isNull);
    });

    test('clear flag overrides explicit null', () {
      final withValue = state.copyWith(playingBlockIndex: 5);
      final cleared = withValue.copyWith(
        playingBlockIndex: null,
        clearPlayingBlockIndex: true,
      );
      expect(cleared.playingBlockIndex, isNull);
    });

    test('multiple clear flags work together', () {
      final withValue = state.copyWith(
        playingBlockIndex: 1,
        playingText: 'text',
        loadingBlockIndex: 2,
      );
      final cleared = withValue.copyWith(
        clearPlayingBlockIndex: true,
        clearPlayingText: true,
        clearLoadingBlockIndex: true,
      );
      expect(cleared.playingBlockIndex, isNull);
      expect(cleared.playingText, isNull);
      expect(cleared.loadingBlockIndex, isNull);
    });
  });

  group('ReaderState.copyWith translation fields', () {
    test('updates translationStatus', () {
      final updated = state.copyWith(
        translationStatus: TranslationStatus.translating,
      );
      expect(updated.translationStatus, TranslationStatus.translating);
    });

    test('keeps original translationStatus with null', () {
      final translating = state.copyWith(
        translationStatus: TranslationStatus.translating,
      );
      final same = translating.copyWith(translationStatus: null);
      expect(same.translationStatus, TranslationStatus.translating);
    });
  });
}
