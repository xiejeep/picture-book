import 'dart:io';
import '../models/book_model.dart';
import '../models/page_model.dart';
import '../models/text_block_model.dart';
import '../repositories/book_repository.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../services/book_service.dart';
import '../../core/constants/constants.dart';

class BookRepositoryImpl implements BookRepository {
  final StorageService _storageService;
  final ImageService _imageService;
  final BookService _bookService;

  BookRepositoryImpl(
    this._storageService,
    this._imageService,
    this._bookService,
  );

  @override
  Future<BookModel> createBook(String title) async {
    return await _bookService.createBook(title);
  }

  @override
  Future<PageModel> addPageToBook(
    String bookId,
    File imageFile,
    List<TextBlockModel> textBlocks,
  ) async {
    return await _bookService.addPageToBook(bookId, imageFile, textBlocks);
  }

  @override
  Future<void> removePageFromBook(String bookId, int pageIndex) async {
    await _bookService.removePageFromBook(bookId, pageIndex);
  }

  @override
  Future<void> updateBookTitle(String bookId, String newTitle) async {
    await _bookService.updateBookTitle(bookId, newTitle);
  }

  @override
  Future<void> updatePageTextBlocks(
    String bookId,
    int pageIndex,
    List<TextBlockModel> newTextBlocks,
  ) async {
    await _bookService.updatePageTextBlocks(bookId, pageIndex, newTextBlocks);
  }

  @override
  Future<void> reorderPages(String bookId, int oldIndex, int newIndex) async {
    await _bookService.reorderPages(bookId, oldIndex, newIndex);
  }

  @override
  Future<void> deleteBook(String bookId) async {
    await _bookService.deleteBook(bookId);
  }

  @override
  List<BookModel> getAllBooks() {
    return _bookService.getAllBooks();
  }

  @override
  BookModel? getBook(String bookId) {
    return _bookService.getBook(bookId);
  }

  @override
  int getBookCount() {
    return _bookService.getBookCount();
  }

  @override
  List<BookModel> searchBooks(String query) {
    return _bookService.searchBooks(query);
  }

  @override
  List<BookModel> sortBooksByDate(bool descending) {
    return _bookService.sortBooksByDate(descending);
  }
}
