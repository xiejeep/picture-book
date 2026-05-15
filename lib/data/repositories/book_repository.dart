import 'dart:io';
import '../models/book_model.dart';
import '../models/page_model.dart';
import '../models/text_block_model.dart';

abstract class BookRepository {
  Future<BookModel> createBook(String title);

  Future<PageModel> addPageToBook(
    String bookId,
    File imageFile,
    List<TextBlockModel> textBlocks,
  );

  Future<void> removePageFromBook(String bookId, int pageIndex);

  Future<void> updateBookTitle(String bookId, String newTitle);

  Future<void> updatePageTextBlocks(
    String bookId,
    int pageIndex,
    List<TextBlockModel> newTextBlocks,
  );

  Future<void> reorderPages(String bookId, int oldIndex, int newIndex);

  Future<void> deleteBook(String bookId);

  List<BookModel> getAllBooks();

  BookModel? getBook(String bookId);

  int getBookCount();

  List<BookModel> searchBooks(String query);

  List<BookModel> sortBooksByDate(bool descending);
}
