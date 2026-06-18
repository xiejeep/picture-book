import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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

    _migrateBlockIdsIfNeeded();
  }

  void _migrateBlockIdsIfNeeded() {
    final migrated = _appSettingsBox.get('block_id_migrated') as bool? ?? false;
    if (migrated) return;

    final uuid = const Uuid();
    for (final book in _booksBox.values) {
      bool bookChanged = false;
      for (int p = 0; p < book.pages.length; p++) {
        final blocks = book.pages[p].textBlocks;
        final newBlocks = <TextBlockModel>[];
        for (final block in blocks) {
          newBlocks.add(block.copyWith(id: uuid.v4()));
          bookChanged = true;
        }
        if (bookChanged) {
          book.pages[p] = book.pages[p].copyWith(textBlocks: newBlocks);
        }
      }
      if (bookChanged) {
        book.save();
      }
    }

    _appSettingsBox.put('block_id_migrated', true);
    debugPrint('Storage: migrated block IDs for existing books');
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
      debugPrint('  页面数: ${book.pages.length}');
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

  bool getNfcEnabled() {
    return _appSettingsBox.get('nfc_enabled', defaultValue: false) as bool;
  }

  Future<void> saveNfcEnabled(bool enabled) async {
    await _appSettingsBox.put('nfc_enabled', enabled);
  }
}
