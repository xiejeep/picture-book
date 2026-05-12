import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/book_model.dart';
import '../../data/models/text_block_model.dart';
import '../providers/repository_providers.dart';

class BooksState {
  final List<BookModel> books;
  final bool isLoading;
  final String? error;

  const BooksState({
    this.books = const [],
    this.isLoading = true,
    this.error,
  });

  BooksState copyWith({
    List<BookModel>? books,
    bool? isLoading,
    String? error,
  }) {
    return BooksState(
      books: books ?? this.books,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BooksNotifier extends Notifier<BooksState> {
  @override
  BooksState build() {
    Future.microtask(() => refresh());
    return const BooksState();
  }

  void refresh() {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final books = ref.read(bookRepositoryProvider).getAllBooks();
      state = BooksState(books: books, isLoading: false);
    } catch (e) {
      state = BooksState(isLoading: false, error: e.toString());
    }
  }

  Future<BookModel> createBook(String title) async {
    final book = await ref.read(bookRepositoryProvider).createBook(title);
    refresh();
    return book;
  }

  Future<void> deleteBook(String bookId) async {
    await ref.read(bookRepositoryProvider).deleteBook(bookId);
    refresh();
  }

  Future<void> addPageToBook(
    String bookId,
    dynamic imageFile,
    List<dynamic> textBlocks,
  ) async {
    final blocks = textBlocks.map((block) {
      if (block is TextBlockModel) {
        return block;
      }
      if (block is Map) {
        return TextBlockModel.fromData(
          boundingBox: block['boundingBox'] as Rect,
          text: block['text'] as String,
          isDeleted: block['isDeleted'] as bool? ?? false,
        );
      }
      return block as TextBlockModel;
    }).cast<TextBlockModel>().toList();
    
    await ref.read(bookRepositoryProvider).addPageToBook(
      bookId,
      imageFile as File,
      blocks,
    );
    refresh();
  }
}

final booksProvider = NotifierProvider<BooksNotifier, BooksState>(() {
  return BooksNotifier();
});

final bookCountProvider = Provider<int>((ref) {
  return ref.watch(booksProvider).books.length;
});

final searchBooksProvider = Provider.family<List<BookModel>, String>((ref, query) {
  if (query.isEmpty) return ref.watch(booksProvider).books;
  return ref.read(bookRepositoryProvider).searchBooks(query);
});

final sortedBooksProvider = Provider.family<List<BookModel>, bool>((ref, descending) {
  return ref.read(bookRepositoryProvider).sortBooksByDate(descending);
});