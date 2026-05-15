import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/book_model.dart';
import '../models/page_model.dart';
import '../models/text_block_model.dart';
import '../models/ai_settings_model.dart';
import '../../core/constants/constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static StorageService get instance => _instance;
  StorageService._internal();

  late Box<BookModel> _booksBox;
  late Box<AiSettingsModel> _aiSettingsBox;
  late Box<dynamic> _appSettingsBox;
  late FlutterSecureStorage _secureStorage;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    Hive.registerAdapter(BookModelAdapter());
    Hive.registerAdapter(PageModelAdapter());
    Hive.registerAdapter(TextBlockModelAdapter());
    Hive.registerAdapter(AiSettingsModelAdapter());

    _booksBox = await Hive.openBox<BookModel>(AppConstants.hiveBoxName);
    _aiSettingsBox =
        await Hive.openBox<AiSettingsModel>(AppConstants.aiSettingsBoxName);
    _appSettingsBox = await Hive.openBox<dynamic>('app_settings');
    _secureStorage = const FlutterSecureStorage();
    _isInitialized = true;
  }

  Box<BookModel> get booksBox {
    if (!_isInitialized) {
      throw Exception(
          'StorageService not initialized. Call initialize() first.');
    }
    return _booksBox;
  }

  Box<AiSettingsModel> get aiSettingsBox {
    if (!_isInitialized) {
      throw Exception(
          'StorageService not initialized. Call initialize() first.');
    }
    return _aiSettingsBox;
  }

  FlutterSecureStorage get secureStorage {
    if (!_isInitialized) {
      throw Exception(
          'StorageService not initialized. Call initialize() first.');
    }
    return _secureStorage;
  }

  Future<void> saveBook(BookModel book) async {
    await booksBox.put(book.id, book);
  }

  BookModel? getBook(String id) {
    final book = booksBox.get(id);
    if (book != null) {
      debugPrint('=== StorageService.getBook ===');
      debugPrint('bookId: $id, title: ${book.title}');
      for (int p = 0; p < book.pages.length; p++) {
        debugPrint('  pages[$p]:');
        for (int b = 0; b < book.pages[p].textBlocks.length; b++) {
          debugPrint(
              '    textBlocks[$b]: text="${book.pages[p].textBlocks[b].text}", isDeleted=${book.pages[p].textBlocks[b].isDeleted}');
        }
      }
    }
    return book;
  }

  List<BookModel> getAllBooks() {
    return booksBox.values.toList();
  }

  Future<void> deleteBook(String id) async {
    await booksBox.delete(id);
  }

  Future<void> updateBook(BookModel book) async {
    await booksBox.put(book.id, book);
  }

  int get booksCount => booksBox.length;

  Future<void> clearAll() async {
    await booksBox.clear();
    await _aiSettingsBox.clear();
    await _appSettingsBox.clear();
    await _secureStorage.delete(key: AppConstants.secureStorageApiKeyKey);
  }

  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }

  AiSettingsModel? getAiSettings() {
    return _aiSettingsBox.get('settings');
  }

  Future<void> saveAiSettings(AiSettingsModel settings) async {
    await _aiSettingsBox.put('settings', settings);
  }

  Future<void> deleteAiSettings() async {
    await _aiSettingsBox.delete('settings');
    await _secureStorage.delete(key: AppConstants.secureStorageApiKeyKey);
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: AppConstants.secureStorageApiKeyKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    await _secureStorage.write(
        key: AppConstants.secureStorageApiKeyKey, value: apiKey);
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: AppConstants.secureStorageApiKeyKey);
  }

  Future<bool> hasApiKey() async {
    final key =
        await _secureStorage.read(key: AppConstants.secureStorageApiKeyKey);
    return key != null && key.isNotEmpty;
  }

  ThemeMode getThemeMode() {
    final value =
        _appSettingsBox.get('theme_mode', defaultValue: 'system') as String;
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _appSettingsBox.put('theme_mode', value);
  }
}
