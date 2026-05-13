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
      final text = b.values.first.replaceAll('\n', '\\n');
      return '{"index":${b.keys.first},"text":"$text"}';
    }).join('\n');

    debugPrint('发送给AI的blocksDescription:\n$blocksDescription');

    final prompt = '''TASK: Clean OCR text from children's picture book.

INPUT COUNT: ${blocks.length} blocks (indices: 0, 1, 2, ... ${blocks.length - 1})
OUTPUT COUNT: MUST be exactly ${blocks.length} blocks

INPUT BLOCKS:
$blocksDescription

=== STRICT RULES ===

1. ONE-TO-ONE MAPPING (CRITICAL):
   - Input has ${blocks.length} blocks → Output MUST have ${blocks.length} blocks
   - Input index 0 → Output index 0
   - Input index ${blocks.length - 1} → Output index ${blocks.length - 1}
   - MISSING ANY INDEX = FAILURE

2. MULTI-LINE TEXT IS ONE BLOCK (CRITICAL):
   - A block with multiple lines (shown as \\n in text) is ONE SINGLE BLOCK
   - Example: {"index":5,"text":"sharpness\\nMore damage\\nMore drops"} is ONE block at index 5
   - DO NOT split it into multiple indices
   - DO NOT merge it with adjacent blocks
   - Keep all \\n line breaks inside the block

3. NO MERGING, NO SKIPPING (CRITICAL):
   - Each input block → ONE output block at same index
   - Never combine two blocks into one
   - NEVER skip any block
   - If a block is meaningless (just "#", garbage text, etc.), output it with corrected="" (empty string)
   - NEVER re-number indices - keep original index even if content is empty
   - Example: If input has indices 0,1,2,3,4 and index 2 is "#", output MUST be 0,1,2,3,4 (not 0,1,3,4)

=== CLEANING RULES ===
1. Extract meaningful content:
   - Identify actual sentences/words, ignore OCR noise
   - Noise examples: "F#At", "FRA", "FAABMA!", "60t9!", "#7NNRHo" (random letters/symbols)
   - Keep real words: "Netherite is super strong!" from "F#At\nNetherite is\nsuper strong!\nFAABMA!"
   
2. Remove decorative symbols: #, |, **, numbering
   Remove ALL phonetic transcriptions (IPA) — any text enclosed in slashes like /ˈpɪkæks/, /hoʊ/, /sɔːrd/, /ˈwʊdn/, /boʊ/, /ækz/, /ˈærəʊ/, /ˈʃoʊvəl/, /ʃiːld/, /stoʊn/, /ˈaɪərn/, /ˈdaɪəmənd/, /ˈneðəraɪt/, /hau/, etc. Remove the entire "/.../" pattern including the slashes.
   
3. Remove meaningless line breaks:
   - "Diamond is\nthe best!" → "Diamond is the best!" (one sentence)
   - But keep meaningful structure: "sharpness\nMore damage" if they are list items
   
4. Remove Chinese characters - keep ONLY English
   
5. Trim whitespace. Empty result → return ""

=== EXAMPLE (5 blocks shown, your actual input has ${blocks.length} blocks) ===
{"index":0,"text":"Title"}
{"index":1,"text":"pickaxe /ˈpɪkæks/"}
{"index":2,"text":"#"}
{"index":3,"text":"Diamond is\\nthe best!"}
{"index":4,"text":"netherite /ˈneðəraɪt/\\nF#At\\nFRA\\nNetherite is\\nsuper strong!\\nFAABMA!"}

Correct Output (5 items, indices 0-4):
[{"index":0,"corrected":"Title"},{"index":1,"corrected":"pickaxe"},{"index":2,"corrected":""},{"index":3,"corrected":"Diamond is the best!"},{"index":4,"corrected":"Netherite is super strong!"}]

Note:
- index 1: word + phonetic /ˈpɪkæks/ → keep only "pickaxe"
- index 3: one sentence → remove line break
- index 4: remove phonetic /ˈneðəraɪt/ and noise → extract only "Netherite is super strong!"

WRONG Output (kept phonetics):
[{"index":0,"corrected":"Title"},{"index":1,"corrected":"pickaxe /ˈpɪkæks/"},{"index":3,"corrected":"Diamond is the best!"},{"index":4,"corrected":"netherite /ˈneðəraɪt/ Netherite is super strong FAABMA"}]
↑ WRONG: kept phonetics, skipped index 2

=== FINAL CHECK ===
Before outputting, COUNT your results:
- You MUST have exactly ${blocks.length} items
- Indices MUST be: 0, 1, 2, 3, ... ${blocks.length - 1} (all present, no gaps)

Return ONLY this JSON object (no markdown, no explanation):
{"blocks":[{"index":0,"corrected":"..."},{"index":1,"corrected":"..."},...{"index":${blocks.length - 1},"corrected":"..."}]}''';

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
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API request failed: ${response.statusCode}');
      }

      final responseBody = jsonDecode(response.body);
      final content = responseBody['choices'][0]['message']['content'] as String;
      
      debugPrint('AI返回的原始content: $content');

final rawResult = _parseResponse(content);
      
debugPrint('解析后的结果:');
rawResult.forEach((key, value) {
  debugPrint('  result[$key]: "$value"');
});

final result = <int, String>{};

final isConsecutiveFromZero = () {
  if (rawResult.length == 0) return false;
  for (int i = 0; i < rawResult.length; i++) {
    if (!rawResult.containsKey(i)) return false;
  }
  return true;
}();

if (isConsecutiveFromZero && rawResult.length < blocks.length) {
  debugPrint('检测到AI重新编号了index（连续0-${rawResult.length-1}），需要按顺序映射');
  for (int i = 0; i < blocks.length; i++) {
    final originalIndex = blocks[i].keys.first;
    final originalText = blocks[i].values.first;
    if (i < rawResult.length) {
      result[originalIndex] = rawResult[i]!;
    } else {
      result[originalIndex] = originalText;
      debugPrint('  填充超出范围的位置$i (原始index $originalIndex): "$originalText"');
    }
  }
} else {
  for (int i = 0; i < blocks.length; i++) {
    final originalIndex = blocks[i].keys.first;
    final originalText = blocks[i].values.first;
    if (rawResult.containsKey(originalIndex)) {
      result[originalIndex] = rawResult[originalIndex]!;
    } else {
      result[originalIndex] = originalText;
      debugPrint('  填充缺失index $originalIndex: "$originalText"');
    }
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
        final indexValue = block['index'];
        int index;
        if (indexValue is int) {
          index = indexValue;
        } else if (indexValue is String) {
          final match = RegExp(r'\d+').firstMatch(indexValue);
          if (match == null) {
            debugPrint('无法解析index: $indexValue');
            continue;
          }
          index = int.parse(match.group(0)!);
        } else {
          debugPrint('index类型错误: ${indexValue.runtimeType}');
          continue;
        }
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