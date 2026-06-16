import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/services/ai_service.dart';

class AiBlockHelper {
  static String? _cachedVisionDescription;
  static String? _cachedVisionImagePath;

  static Future<bool> checkApiKey(BuildContext context) async {
    final hasKey = await AiService.instance.hasApiKey();
    if (!hasKey && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 API Key')),
      );
    }
    return hasKey;
  }

  static Future<String> getVisionDescription(
    File imageFile,
    String model,
  ) async {
    if (_cachedVisionImagePath == imageFile.path &&
        _cachedVisionDescription != null) {
      return _cachedVisionDescription!;
    }
    _cachedVisionDescription =
        await AiService.instance.extractVisionText(imageFile, model);
    _cachedVisionImagePath = imageFile.path;
    return _cachedVisionDescription!;
  }

  static Future<Map<int, String>> enhance({
    required File imageFile,
    required List<Map<int, String>> blocks,
    required String model,
    void Function(String message)? onProgress,
    String? visionDescription,
  }) async {
    return await AiService.instance.enhanceTextBlocks(
      imageFile,
      blocks,
      model,
      onProgress: onProgress,
      visionDescription: visionDescription,
    );
  }

  static Future<Map<int, String>> translate({
    required File imageFile,
    required List<Map<int, String>> blocks,
    required String model,
    void Function(String message)? onProgress,
    String? visionDescription,
  }) async {
    return await AiService.instance.enhanceTranslation(
      imageFile,
      blocks,
      model,
      onProgress: onProgress,
      visionDescription: visionDescription,
    );
  }

  static void clearCache() {
    _cachedVisionDescription = null;
    _cachedVisionImagePath = null;
  }
}
