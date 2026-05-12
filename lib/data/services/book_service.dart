import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/book_model.dart';
import '../models/page_model.dart';
import '../models/text_block_model.dart';
import 'storage_service.dart';
import 'image_service.dart';
import '../../core/constants/constants.dart';

class BookService {
  static final BookService _instance = BookService._internal();
  static BookService get instance => _instance;
  BookService._internal();

  final _uuid = const Uuid();

  Future<BookModel> createBook(String title) async {
    final now = DateTime.now();
    final book = BookModel(
      id: _uuid.v4(),
      title: title.isEmpty ? AppConstants.defaultBookTitle : title,
      createdAt: now,
      updatedAt: now,
      pages: [],
      currentPageIndex: 0,
    );

    await StorageService.instance.saveBook(book);
    return book;
  }

  Future<PageModel> addPageToBook(
    String bookId,
    File imageFile,
    List<TextBlockModel> textBlocks,
  ) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found: $bookId');
    }

    final pageId = _uuid.v4();
    final pageIndex = book.pages.length;
    
    final imagePath = await ImageService.instance.saveImage(imageFile, bookId, pageId);
    
    // 获取图片尺寸
    final bytes = imageFile.readAsBytesSync();
    final decodedImage = await decodeImageFromList(bytes);
    final imageWidth = decodedImage.width.toDouble();
    final imageHeight = decodedImage.height.toDouble();
    
    final page = PageModel(
      id: pageId,
      imagePath: imagePath,
      textBlocks: textBlocks,
      pageIndex: pageIndex,
      createdAt: DateTime.now(),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    book.addPage(page);
    
    return page;
  }

  Future<void> removePageFromBook(String bookId, int pageIndex) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found: $bookId');
    }

    if (pageIndex < 0 || pageIndex >= book.pages.length) {
      throw Exception('Invalid page index: $pageIndex');
    }

    final page = book.pages[pageIndex];
    await ImageService.instance.deleteImage(page.imagePath);
    
    book.removePage(pageIndex);
  }

  Future<void> updateBookTitle(String bookId, String newTitle) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found: $bookId');
    }

    book.title = newTitle;
    book.updatedAt = DateTime.now();
    book.save();
  }

  Future<void> updatePageTextBlocks(
    String bookId,
    int pageIndex,
    List<TextBlockModel> newTextBlocks,
  ) async {
    debugPrint('=== updatePageTextBlocks ===');
    debugPrint('bookId: $bookId, pageIndex: $pageIndex');
    debugPrint('newTextBlocks数: ${newTextBlocks.length}');
    for (int i = 0; i < newTextBlocks.length; i++) {
      debugPrint('  newTextBlocks[$i]: text="${newTextBlocks[i].text}", isDeleted=${newTextBlocks[i].isDeleted}');
    }

    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found: $bookId');
    }

    if (pageIndex < 0 || pageIndex >= book.pages.length) {
      throw Exception('Invalid page index: $pageIndex');
    }

    final oldPage = book.pages[pageIndex];
    debugPrint('旧页面的textBlocks:');
    for (int i = 0; i < oldPage.textBlocks.length; i++) {
      debugPrint('  oldPage.textBlocks[$i]: text="${oldPage.textBlocks[i].text}", isDeleted=${oldPage.textBlocks[i].isDeleted}');
    }

    final newPage = oldPage.copyWith(textBlocks: newTextBlocks);
    debugPrint('newPage的textBlocks:');
    for (int i = 0; i < newPage.textBlocks.length; i++) {
      debugPrint('  newPage.textBlocks[$i]: text="${newPage.textBlocks[i].text}", isDeleted=${newPage.textBlocks[i].isDeleted}');
    }
    
    book.updatePage(pageIndex, newPage);
    
    debugPrint('更新后book.pages[$pageIndex].textBlocks:');
    for (int i = 0; i < book.pages[pageIndex].textBlocks.length; i++) {
      debugPrint('  updated.textBlocks[$i]: text="${book.pages[pageIndex].textBlocks[i].text}", isDeleted=${book.pages[pageIndex].textBlocks[i].isDeleted}');
    }
  }

  Future<void> reorderPages(String bookId, int oldIndex, int newIndex) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) {
      throw Exception('Book not found: $bookId');
    }

    if (oldIndex < 0 || oldIndex >= book.pages.length ||
        newIndex < 0 || newIndex >= book.pages.length) {
      throw Exception('Invalid page indices');
    }

    final page = book.pages.removeAt(oldIndex);
    book.pages.insert(newIndex, page);
    
    for (int i = 0; i < book.pages.length; i++) {
      book.pages[i] = book.pages[i].copyWith(pageIndex: i);
    }
    
    book.updatedAt = DateTime.now();
    book.save();
  }

  Future<void> deleteBook(String bookId) async {
    final book = StorageService.instance.getBook(bookId);
    if (book == null) return;

    await ImageService.instance.deleteBookDirectory(bookId);
    await StorageService.instance.deleteBook(bookId);
  }

  List<BookModel> getAllBooks() {
    return StorageService.instance.getAllBooks();
  }

  BookModel? getBook(String bookId) {
    return StorageService.instance.getBook(bookId);
  }

  int getBookCount() {
    return StorageService.instance.booksCount;
  }

  List<BookModel> searchBooks(String query) {
    final allBooks = getAllBooks();
    if (query.isEmpty) return allBooks;
    
    return allBooks.where((book) {
      return book.title.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  List<BookModel> sortBooksByDate(bool descending) {
    final allBooks = getAllBooks();
    allBooks.sort((a, b) {
      return descending 
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt);
    });
    return allBooks;
  }
}