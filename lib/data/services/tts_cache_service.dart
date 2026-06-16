import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TtsCacheService {
  static final TtsCacheService _instance = TtsCacheService._internal();
  static TtsCacheService get instance => _instance;
  TtsCacheService._internal();

  Directory? _cacheDir;
  static const int _maxCacheSize = 50 * 1024 * 1024;

  Future<void> initialize() async {
    final appDir = await getApplicationSupportDirectory();
    _cacheDir = Directory('${appDir.path}/tts_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
      debugPrint('TTS缓存目录创建: ${_cacheDir!.path}');
    }

    await _cleanOldCache();
  }

  String _generateSupertonicCacheKey(
      String text, String voice, int steps, double speed) {
    final keyString = '${text}_${voice}_${steps}_${speed.toStringAsFixed(2)}';
    final bytes = utf8.encode(keyString);
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  Future<String?> getCachedSupertonicAudio(
      String text, String voice, int steps, double speed) async {
    if (_cacheDir == null) {
      await initialize();
    }

    final cacheKey = _generateSupertonicCacheKey(text, voice, steps, speed);
    final cacheFile = File('${_cacheDir!.path}/$cacheKey.wav');

    if (await cacheFile.exists()) {
      debugPrint('使用Supertonic缓存音频: $cacheKey');
      return cacheFile.path;
    }

    return null;
  }

  Future<String> saveSupertonicToCache(
      String tempAudioPath, String text, String voice, int steps, double speed) async {
    if (_cacheDir == null) {
      await initialize();
    }

    final cacheKey = _generateSupertonicCacheKey(text, voice, steps, speed);
    final cacheFile = File('${_cacheDir!.path}/$cacheKey.wav');

    final tempFile = File(tempAudioPath);
    if (await tempFile.exists()) {
      await tempFile.copy(cacheFile.path);
      await tempFile.delete();
      debugPrint('Supertonic音频已缓存: $cacheKey');
    }

    return cacheFile.path;
  }

  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;

    int totalSize = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }

    return totalSize;
  }

  Future<void> _cleanOldCache() async {
    final currentSize = await getCacheSize();

    if (currentSize > _maxCacheSize) {
      debugPrint('缓存超限 (${currentSize ~/ 1024 ~/ 1024}MB)，开始清理旧文件');

      final files = <File>[];
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      files
          .sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      int deletedSize = 0;
      for (final file in files) {
        if (currentSize - deletedSize <= _maxCacheSize * 0.8) break;

        final fileSize = await file.length();
        await file.delete();
        deletedSize += fileSize;
        debugPrint('删除旧缓存: ${file.path}');
      }
    }
  }

  Future<void> clearCache() async {
    if (_cacheDir == null) return;

    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }

    debugPrint('TTS缓存已清空');
  }

  Future<int> getCacheFileCount() async {
    if (_cacheDir == null) return 0;

    int count = 0;
    await for (final entity in _cacheDir!.list()) {
      if (entity is File) {
        count++;
      }
    }

    return count;
  }
}
