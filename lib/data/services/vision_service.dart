import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/constants/app_log.dart';
import '../../core/constants/constants.dart';
import '../../core/constants/app_prompts.dart';
import 'storage_service.dart';

class VisionService {
  static final VisionService _instance = VisionService._internal();
  static VisionService get instance => _instance;
  VisionService._internal();

  Future<String> extractText(File imageFile, String model) async {
    final apiKey = await StorageService.instance.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }
    return await _visionExtractText(imageFile, model, apiKey);
  }

  Future<String> _visionExtractText(
    File imageFile,
    String visionModel,
    String apiKey,
  ) async {
    final base64Image = await _imageToBase64(imageFile);

    final prompt = AppPrompts.visionExtractText();

    final response = await http.post(
      Uri.parse(AppConstants.zhipuApiEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': visionModel,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': base64Image}
              },
              {'type': 'text', 'text': prompt}
            ]
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('Step1 API Error: ${response.statusCode}');
      throw Exception('Vision model request failed: ${response.statusCode}');
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    AppLog.content('Step1视觉模型原始返回:\n$content');

    return content;
  }

  Future<String> _imageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
  }
}
