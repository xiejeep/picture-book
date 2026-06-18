import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/constants/app_log.dart';
import '../../core/constants/constants.dart';
import 'storage_service.dart';
import 'vision_service.dart';
import 'text_cleaning_service.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  static AiService get instance => _instance;
  AiService._internal();

  Future<String?> getApiKey() async {
    return await StorageService.instance.getApiKey();
  }

  Future<void> saveApiKey(String apiKey) async {
    await StorageService.instance.saveApiKey(apiKey);
  }

  Future<void> deleteApiKey() async {
    await StorageService.instance.deleteApiKey();
  }

  Future<bool> hasApiKey() async {
    return await StorageService.instance.hasApiKey();
  }

  String getSelectedModel() {
    final settings = StorageService.instance.getAiSettings();
    return settings?.selectedModel ?? AppConstants.defaultModel;
  }

  String getTextModel() => TextCleaningService.instance.getTextModel();

  Future<bool> testConnection(String apiKey, String model) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.zhipuApiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': '你好'}
              ]
            }
          ],
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Test connection error: $e');
      return false;
    }
  }

  Future<String> extractVisionText(File imageFile, String model) async {
    return await VisionService.instance.extractText(imageFile, model);
  }

  Future<Map<int, String>> enhanceTextBlocks(
    File imageFile,
    List<Map<int, String>> blocks,
    String model, {
    void Function(String message)? onProgress,
    String? visionDescription,
  }) async {
    debugPrint('=== AiService.enhanceTextBlocks ===');
    debugPrint('输入blocks数: ${blocks.length}');
    debugPrint('复用vision: ${visionDescription != null}');

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    String visionResult;
    if (visionDescription != null) {
      visionResult = visionDescription;
      debugPrint('使用缓存的视觉描述');
    } else {
      onProgress?.call('AI正在理解图片内容...');
      visionResult = await VisionService.instance.extractText(imageFile, model);
    }

    AppLog.content('视觉模型提取的文本:\n$visionResult');

    return await TextCleaningService.instance.enhanceTextBlocks(
      visionResult,
      blocks,
      getTextModel(),
      onProgress: onProgress,
    );
  }

  Future<Map<int, String>> enhanceTranslation(
    File imageFile,
    List<Map<int, String>> blocksWithDraft,
    String model, {
    void Function(String message)? onProgress,
    String? visionDescription,
  }) async {
    debugPrint('=== AiService.enhanceTranslation ===');
    debugPrint('输入blocks数: ${blocksWithDraft.length}');
    debugPrint('复用vision: ${visionDescription != null}');

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    String visionResult;
    if (visionDescription != null) {
      visionResult = visionDescription;
      debugPrint('使用缓存的视觉描述');
    } else {
      onProgress?.call('AI正在理解图片内容...');
      visionResult = await VisionService.instance.extractText(imageFile, model);
    }

    AppLog.content('翻译用视觉模型描述:\n$visionResult');

    return await TextCleaningService.instance.enhanceTranslation(
      visionResult,
      blocksWithDraft,
      getTextModel(),
      onProgress: onProgress,
    );
  }
}
