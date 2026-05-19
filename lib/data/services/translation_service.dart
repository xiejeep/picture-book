import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../../core/utils/platform_utils.dart';

enum TranslationStatus {
  idle,
  downloadingModel,
  translating,
  done,
  failed,
}

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  static TranslationService get instance => _instance;
  TranslationService._internal();

  OnDeviceTranslator? _translator;
  final _modelManager = OnDeviceTranslatorModelManager();
  bool _isReady = false;
  bool _isDownloading = false;

  final _sourceLanguage = TranslateLanguage.english;
  final _targetLanguage = TranslateLanguage.chinese;

  bool get isDownloadingModel => _isDownloading;

  static bool get isSupported => PlatformUtils.supportsMlKit;

  Future<void> ensureReady() async {
    if (!isSupported) return;
    if (_isReady && _translator != null) return;

    _translator = OnDeviceTranslator(
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
    );
    _isReady = true;
  }

  Future<bool> _ensureModelDownloaded() async {
    final targetTag = _targetLanguage.bcpCode;
    final isDownloaded = await _modelManager.isModelDownloaded(targetTag);
    if (isDownloaded) return true;

    debugPrint('翻译模型未下载，开始下载...');
    _isDownloading = true;
    try {
      await _modelManager.downloadModel(targetTag);
      debugPrint('翻译模型下载完成');
      _isDownloading = false;
      return true;
    } catch (e) {
      debugPrint('翻译模型下载失败: $e');
      _isDownloading = false;
      return false;
    }
  }

  Future<TranslationResult> translateWithStatus(String text) async {
    if (!isSupported) {
      return TranslationResult(
        status: TranslationStatus.failed,
        message: '当前平台不支持翻译功能',
      );
    }

    if (text.trim().isEmpty) {
      return TranslationResult(status: TranslationStatus.idle);
    }

    if (_isDownloading) {
      return TranslationResult(
        status: TranslationStatus.downloadingModel,
        message: '翻译模型正在下载中，请稍候...',
      );
    }

    final downloaded = await _ensureModelDownloaded();
    if (!downloaded) {
      return TranslationResult(
        status: TranslationStatus.failed,
        message: '翻译模型下载失败，请检查网络后重试',
      );
    }

    await ensureReady();

    try {
      final result = await _translator!.translateText(text);
      debugPrint('翻译结果: "$text" -> "$result"');
      return TranslationResult(
        status: TranslationStatus.done,
        translatedText: result,
      );
    } catch (e) {
      debugPrint('翻译失败: $e');
      return TranslationResult(
        status: TranslationStatus.failed,
        message: '翻译失败',
      );
    }
  }

  Future<String?> translateWithDownloadCheck(String text) async {
    final result = await translateWithStatus(text);
    return result.translatedText;
  }

  Future<bool> isModelDownloaded() async {
    return _modelManager.isModelDownloaded(_targetLanguage.bcpCode);
  }

  Future<bool> deleteModel() async {
    final deleted = await _modelManager.deleteModel(_targetLanguage.bcpCode);
    if (deleted) {
      _translator?.close();
      _translator = null;
      _isReady = false;
      debugPrint('翻译模型已删除');
    }
    return deleted;
  }

  void dispose() {
    _translator?.close();
    _translator = null;
    _isReady = false;
    _isDownloading = false;
  }
}

class TranslationResult {
  final TranslationStatus status;
  final String? translatedText;
  final String? message;

  const TranslationResult({
    required this.status,
    this.translatedText,
    this.message,
  });
}
