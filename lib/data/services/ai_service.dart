import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/constants.dart';
import 'storage_service.dart';
import 'tts_cache_service.dart';

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

  String getTtsVoice() {
    final settings = StorageService.instance.getAiSettings();
    return settings?.ttsVoice ?? AppConstants.defaultTtsVoice;
  }

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

  Future<String?> synthesizeSpeech(
    String text, {
    String? voice,
    double? speechRate,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    final settings = StorageService.instance.getAiSettings();
    final ttsVoice = voice ?? settings?.ttsVoice ?? AppConstants.defaultTtsVoice;
    final ttsSpeed = speechRate ?? settings?.speechRate ?? AppConstants.glmTtsDefaultSpeed;
    const ttsVolume = 1.0;

    final cachedAudio = await TtsCacheService.instance.getCachedAudio(
      text, ttsVoice, ttsSpeed
    );
    
    if (cachedAudio != null) {
      debugPrint('使用缓存音频，无需调用API');
      return cachedAudio;
    }

    try {
      final response = await http.post(
        Uri.parse(AppConstants.zhipuTtsEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-tts',
          'input': text,
          'voice': ttsVoice,
          'response_format': 'wav',
          'speed': ttsSpeed,
          'volume': ttsVolume,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('TTS API Error: ${response.statusCode} - ${response.body}');
        throw Exception('statusCode:${response.statusCode}, body:${response.body}');
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempAudioFile = File('${tempDir.path}/tts_temp_$timestamp.wav');
      await tempAudioFile.writeAsBytes(response.bodyBytes);

      final cachedPath = await TtsCacheService.instance.saveToCache(
        tempAudioFile.path, text, ttsVoice, ttsSpeed
      );

      debugPrint('TTS音频已缓存: $cachedPath');
      return cachedPath;
    } catch (e) {
      debugPrint('Synthesize speech error: $e');
      throw Exception('TTS synthesis failed: $e');
    }
  }

  Future<Map<int, String>> enhanceTextBlocks(
    File imageFile,
    List<Map<int, String>> blocks,
    String model,
  ) async {
    debugPrint('=== AiService.enhanceTextBlocks ===');
    debugPrint('输入blocks数: ${blocks.length}');
    for (final b in blocks) {
      debugPrint('  输入block: index=${b.keys.first}, text="${b.values.first}"');
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    final base64Image = await _imageToBase64(imageFile);

    final blocksDescription = blocks.map((b) {
      return '[${b.keys.first}] ${b.values.first}';
    }).join('\n');

    debugPrint('发送给AI的blocksDescription:\n$blocksDescription');

    final prompt = '''You are cleaning text from a children's picture book. This is a TEXT PROCESSING task - you are NOT re-analyzing the image.

Input blocks (${blocks.length} total, index 0-${blocks.length - 1}):
$blocksDescription

⚠️ IMAGE IS FOR REFERENCE ONLY:
- The image helps you understand the visual context (e.g., this is a Minecraft book)
- DO NOT let visual positions override the INPUT TEXT INDEX ORDER
- DO NOT re-identify text from image - trust the INPUT blocks as authoritative
- Your task: clean INPUT text blocks, NOT re-recognize from image
- INPUT index sequence (0→1→2→...) is the ABSOLUTE AUTHORITY, not visual layout

🚨🚨🚨 ABSOLUTE NON-NEGOTIABLE RULES 🚨🚨🚨

1. ZERO MERGING/SKIPPING POLICY:
   - Output EXACTLY ${blocks.length} items - count must be identical
   - Each input block[i] MUST produce output block[i] at the SAME index
   - Missing ANY index = INVALID response (even if content is duplicate)

2. DUPLICATE CONTENT IS NORMAL - DO NOT SKIP:
   - If block[34] and block[35] have identical text, output BOTH at their indices
   - Example: Input block[34]="hello", block[35]="hello" → Output [{"index":34,"corrected":"hello"}, {"index":35,"corrected":"hello"}]
   - NEVER merge identical blocks - they are separate visual regions
   
3. INDEX SEQUENCE MUST BE CONTINUOUS:
   - Indices must be: 0, 1, 2, 3, ... ${blocks.length - 1} in exact order
   - NO gaps allowed: 0→1→2→...→${blocks.length - 1} (all present)
   - NO reordering: output index must match input index precisely

4. MULTI-LINE BLOCKS ARE SINGLE UNITS:
   - block[4] "#\\nEnchanting Words |" = ONE block, NOT two
   - Preserve \\n within blocks, but output at the SAME index
   - Do NOT split multi-line blocks into multiple indices

Cleaning rules (apply to each block independently):
- Remove: ##, ||, |, **, decorative symbols, phonetic marks (/æ/), numbering (1., ②)
- Remove Chinese text - keep ONLY English
- Preserve \\n (line breaks) in multi-line blocks
- Empty result → return ""

CRITICAL EXAMPLES:
✅ CORRECT: Input block[25]="#", block[26]="Title" → Output [{"index":25,"corrected":""}, {"index":26,"corrected":"Title"}]
❌ WRONG: Input block[25]="#", block[26]="Title" → Output [{"index":25,"corrected":"#Title"}] ← MERGED!

✅ CORRECT: Input block[34]="same", block[35]="same" → Output [{"index":34,"corrected":"same"}, {"index":35,"corrected":"same"}]
❌ WRONG: Input block[34]="same", block[35]="same" → Output [{"index":34,"corrected":"same"}] ← SKIPPED 35!

Return ONLY JSON array with EXACTLY ${blocks.length} consecutive items:
[{"index":0,"corrected":"..."},{"index":1,"corrected":"..."},...{"index":${blocks.length - 1},"corrected":"..."}]

COUNT CHECK: Your array MUST have ${blocks.length} items. Count them before responding!''';

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
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API request failed: ${response.statusCode}');
      }

      final responseBody = jsonDecode(response.body);
      final content = responseBody['choices'][0]['message']['content'] as String;
      
      debugPrint('AI返回的原始content: $content');

final result = _parseResponse(content);
      
debugPrint('解析后的结果:');
result.forEach((key, value) {
debugPrint('  result[$key]: "$value"');
});

if (result.length != blocks.length) {
final missingIndices = <int>[];
for (int i = 0; i < blocks.length; i++) {
if (!result.containsKey(i)) {
missingIndices.add(i);
}
}

final inputExample = missingIndices.take(3).map((i) {
final block = blocks[i];
return 'block[$i]: "${block.values.first}"';
}).join('\n');

throw Exception(
'AI返回${result.length}个结果，需要${blocks.length}个\n'
'缺失的index: ${missingIndices.join(', ')}\n'
'缺失block示例:\n$inputExample\n'
'可能原因: AI错误合并了多行文本块\n'
'解决方法: 点击重试按钮重新处理'
);
}

for (int i = 0; i < blocks.length; i++) {
if (!result.containsKey(i)) {
throw Exception('缺少index $i，请重新识别');
}
}

return result;
    } catch (e) {
      debugPrint('Enhance text blocks error: $e');
      throw Exception('AI enhancement failed: $e');
    }
  }

  Future<String> _imageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
  }

  Map<int, String> _parseResponse(String content) {
    try {
      String jsonStr = content;
      
      jsonStr = jsonStr.replaceAll(RegExp(r'```json\s*'), '');
      jsonStr = jsonStr.replaceAll(RegExp(r'```\s*'), '');
      jsonStr = jsonStr.trim();
      
      // Fix missing commas between JSON objects: "}\n{" -> "},\n{"
      jsonStr = jsonStr.replaceAllMapped(
        RegExp(r'\}\s*\n\s*\{'),
        (match) => '},\n{',
      );
      
      final decoded = jsonDecode(jsonStr);
      
      List blocksList;
      if (decoded is List) {
        blocksList = decoded;
      } else if (decoded is Map && decoded['blocks'] != null) {
        blocksList = decoded['blocks'] as List;
      } else {
        throw Exception('Invalid response format');
      }

      final result = <int, String>{};
      for (final block in blocksList) {
        final index = block['index'] as int;
        final corrected = block['corrected'] as String;
        result[index] = corrected;
      }

      return result;
    } catch (e) {
      debugPrint('Parse response error: $e');
      debugPrint('Content: $content');
      throw Exception('Failed to parse AI response');
    }
  }
}