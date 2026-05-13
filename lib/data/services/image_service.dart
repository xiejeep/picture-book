import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/constants.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  static ImageService get instance => _instance;
  ImageService._internal();

  late Directory _appDir;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _appDir = await getApplicationDocumentsDirectory();
    _isInitialized = true;
  }

  String get appPath => _appDir.path;

  Future<String> saveImage(File imageFile, String bookId, String pageId) async {
    if (!_isInitialized) {
      await initialize();
    }

    final bookDir = Directory('${_appDir.path}/${AppConstants.booksDirectoryName}/$bookId');
    if (!bookDir.existsSync()) {
      bookDir.createSync(recursive: true);
    }

    final extension = imageFile.path.split('.').last.toLowerCase();
    final newImagePath = '${bookDir.path}/${pageId}.$extension';
    
    await imageFile.copy(newImagePath);
    
    final relativePath = '${AppConstants.booksDirectoryName}/$bookId/${pageId}.$extension';
    return relativePath;
  }

  Future<String> saveCoverImage(File imageFile, String bookId) async {
    if (!_isInitialized) {
      await initialize();
    }

    final bookDir = Directory('${_appDir.path}/${AppConstants.booksDirectoryName}/$bookId');
    if (!bookDir.existsSync()) {
      bookDir.createSync(recursive: true);
    }

    final extension = imageFile.path.split('.').last.toLowerCase();
    final coverFileName = 'cover_$bookId';
    final newImagePath = '${bookDir.path}/$coverFileName.$extension';
    
    await imageFile.copy(newImagePath);
    
    final relativePath = '${AppConstants.booksDirectoryName}/$bookId/$coverFileName.$extension';
    return relativePath;
  }

  String _resolveImagePath(String imagePath) {
    if (imagePath.startsWith(AppConstants.booksDirectoryName) || 
        imagePath.startsWith('/${AppConstants.booksDirectoryName}')) {
      final relativePath = imagePath.startsWith('/') 
          ? imagePath.substring(1) 
          : imagePath;
      return '${_appDir.path}/$relativePath';
    }
    
    if (imagePath.contains('/Application/') && imagePath.contains('/Documents/')) {
      final parts = imagePath.split('/Documents/');
      if (parts.length == 2) {
        return '${_appDir.path}/${parts[1]}';
      }
    }
    
    return imagePath;
  }

  Future<void> deleteImage(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }
    final resolvedPath = _resolveImagePath(imagePath);
    final file = File(resolvedPath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> deleteBookDirectory(String bookId) async {
    final bookDir = Directory('${_appDir.path}/${AppConstants.booksDirectoryName}/$bookId');
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
  }

  File? getImageFile(String imagePath) {
    if (!_isInitialized) {
      return null;
    }
    final resolvedPath = _resolveImagePath(imagePath);
    final file = File(resolvedPath);
    return file.existsSync() ? file : null;
  }

  bool imageExists(String imagePath) {
    if (!_isInitialized) {
      return false;
    }
    final resolvedPath = _resolveImagePath(imagePath);
    return File(resolvedPath).existsSync();
  }

  Future<int> getBookStorageSize(String bookId) async {
    final bookDir = Directory('${_appDir.path}/${AppConstants.booksDirectoryName}/$bookId');
    if (!bookDir.existsSync()) return 0;

    int totalSize = 0;
    for (final file in bookDir.listSync()) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    return totalSize;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> clearAllBooksDirectory() async {
    final booksDir = Directory('${_appDir.path}/${AppConstants.booksDirectoryName}');
    if (booksDir.existsSync()) {
      await booksDir.delete(recursive: true);
    }
  }
}