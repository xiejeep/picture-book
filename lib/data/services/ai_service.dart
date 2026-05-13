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

  static const int _maxBatchSize = 12;

  Future<Map<int, String>> enhanceTextBlocks(
    File imageFile,
    List<Map<int, String>> blocks,
    String model,
  ) async {
    debugPrint('=== AiService.enhanceTextBlocks ===');
    debugPrint('输入blocks数: ${blocks.length}');

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }

    final batches = <List<Map<int, String>>>[];
    for (int i = 0; i < blocks.length; i += _maxBatchSize) {
      final end = (i + _maxBatchSize).clamp(0, blocks.length);
      batches.add(blocks.sublist(i, end));
    }

    if (batches.length > 1) {
      debugPrint('分${batches.length}批处理');
    }

    final mergedResult = <int, String>{};
    for (int i = 0; i < batches.length; i++) {
      debugPrint('处理第${i + 1}/${batches.length}批 (${batches[i].length}块)');
      final batchResult = await _enhanceBatch(
        imageFile, batches[i], model, apiKey, batchIndex: i,
      );
      mergedResult.addAll(batchResult);
    }

    return mergedResult;
  }

  Future<Map<int, String>> _enhanceBatch(
    File imageFile,
    List<Map<int, String>> batch,
    String model,
    String apiKey, {
    int batchIndex = 0,
    int retryCount = 0,
  }) async {
    for (final b in batch) {
      debugPrint('  输入block: index=${b.keys.first}, text="${b.values.first}"');
    }

    final base64Image = await _imageToBase64(imageFile);

    final blocksDescription = batch.map((b) {
      final text = b.values.first.replaceAll('\n', '\\n');
      return '{"index":${b.keys.first},"text":"$text"}';
    }).join('\n');

    debugPrint('批次$batchIndex发送给AI的blocksDescription:\n$blocksDescription');

    final prompt = _buildPrompt(batch.length, blocksDescription, batch);

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

      debugPrint('批次$batchIndex AI返回的原始content: $content');

      final rawResult = _parseResponse(content);

      debugPrint('批次$batchIndex 解析后的结果:');
      rawResult.forEach((key, value) {
        debugPrint('  result[$key]: "$value"');
      });

      final result = <int, String>{};
      int validatedCount = 0;

      for (final b in batch) {
        final originalIndex = b.keys.first;
        final originalText = b.values.first;

        if (rawResult.containsKey(originalIndex)) {
          final corrected = rawResult[originalIndex]!;
          if (_isRelevant(originalText, corrected)) {
            result[originalIndex] = corrected;
            validatedCount++;
          } else {
            result[originalIndex] = originalText;
            debugPrint('  内容校验不通过 index=$originalIndex: "$originalText" → "$corrected", 回退原文');
          }
        } else {
          result[originalIndex] = originalText;
          debugPrint('  填充缺失index $originalIndex: "$originalText"');
        }
      }

      final indexMatched = batch.where((b) => rawResult.containsKey(b.keys.first)).length;
      debugPrint('批次$batchIndex index匹配: $indexMatched/${batch.length}, 内容校验通过: $validatedCount/$indexMatched');

      if (indexMatched < batch.length && retryCount < 1) {
        debugPrint('批次$batchIndex 存在index不匹配($indexMatched/${batch.length})，重试');
        return _enhanceBatch(
          imageFile, batch, model, apiKey,
          batchIndex: batchIndex,
          retryCount: retryCount + 1,
        );
      }

      return result;
    } catch (e) {
      debugPrint('批次$batchIndex Enhance error: $e');
      throw Exception('AI enhancement failed: $e');
    }
  }

  bool _isRelevant(String original, String corrected) {
    if (corrected.isEmpty) return true;

    final origWords = _extractWords(original);
    if (origWords.isEmpty) return true;

    final corrWords = _extractWords(corrected);
    if (corrWords.isEmpty) return true;

    int matchCount = 0;
    for (final ow in origWords) {
      for (final cw in corrWords) {
        if (ow == cw || ow.contains(cw) || cw.contains(ow)) {
          matchCount++;
          break;
        }
      }
    }

    if (matchCount / origWords.length < 0.2) return false;

    if (origWords.length >= 1 && corrWords.length > origWords.length * 2) {
      debugPrint('  合并嫌疑: 原文${origWords.length}词 vs 修正${corrWords.length}词');
      return false;
    }

    return true;
  }

  Set<String> _extractWords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[/#|*()\\[\\]{}<>]'), ' ')
        .replaceAll(RegExp(r'[^a-zA-Z\s]'), ' ')
        .trim()
        .toLowerCase();
    if (cleaned.isEmpty) return {};
    return cleaned.split(RegExp(r'\s+')).where((w) => w.length >= 2).toSet();
  }

  String _buildPrompt(int count, String blocksDescription, List<Map<int, String>> batch) {
    final firstIndex = batch.first.keys.first;
    final lastIndex = batch.last.keys.first;

    return '''TASK: Clean OCR text from children's picture book.

INPUT COUNT: $count blocks (indices: $firstIndex .. $lastIndex)
OUTPUT COUNT: MUST be exactly $count blocks

INPUT BLOCKS:
$blocksDescription

=== STRICT RULES ===

1. ONE-TO-ONE MAPPING (CRITICAL):
   - Input has $count blocks → Output MUST have exactly $count blocks
   - Each input index MUST appear in output with THE SAME index number
   - Input index $firstIndex → Output index $firstIndex
   - Input index $lastIndex → Output index $lastIndex
   - MISSING ANY INDEX = COMPLETE FAILURE

2. EACH BLOCK IS AN INDEPENDENT OCR REGION (CRITICAL):
   - Every block comes from a SEPARATE rectangular area on the page
   - They are NOT related even if content looks connected
   - A word block and its example sentence are TWO SEPARATE blocks
   - A phonetic guide and its word are TWO SEPARATE blocks
   - DO NOT merge adjacent blocks, even if they form a logical unit together

3. MULTI-LINE TEXT IS ONE BLOCK (CRITICAL):
   - A block containing \\n is ONE SINGLE block from ONE page region
   - It represents MULTIPLE LINES WITHIN that single region
   - DO NOT split it into separate output indices
   - DO NOT merge it with adjacent blocks
   - Clean each line within the block, then join them back with spaces
   - Example: {"index":5,"text":"Punch a tree\\nBuild a shelter"} → {"index":5,"corrected":"Punch a tree Build a shelter"}

4. NO MERGING, NO SKIPPING, NO RE-NUMBERING:
   - Each input block → exactly ONE output block at the SAME index
   - NEVER combine two or more input blocks into one output block
   - NEVER skip any block — if meaningless output corrected="" (empty string)
   - NEVER change index numbers

=== CLEANING RULES ===
1. Extract meaningful content, ignore OCR noise:
   - Noise: "F#At", "FRA", "FAABMA!", "60t9!", "#7NNRHo", "ikEN2#6!", "tPFF", "B LALAFF!", "F2!", "ES", "E5", "AO"
   - Keep real text: "Punch a tree" from "Punch a tree ES"

2. Remove decorative symbols: #, ##, |, **, numbering prefixes
   Remove ALL phonetic transcriptions (IPA) — text in /slashes/ like /haus/, /mi:t/, /ˈpɪkæks/
   Remove the entire /.../ pattern including slashes.

3. Remove meaningless line breaks: join multi-line text into one line for the block
   - "Diamond is\\nthe best!" → "Diamond is the best!"

4. Remove Chinese characters — keep ONLY English text

5. Trim whitespace. Empty/garbage result → corrected=""

=== EXAMPLE (6 blocks, indices 2-7) ===
Input:
{"index":2,"text":"house /haus/"}
{"index":3,"text":"I build a house."}
{"index":4,"text":"mine /man/\\nikEN2#6!"}
{"index":5,"text":"Punch a tree ES\\nBuild a shelter tPFF\\nFind food AO"}
{"index":6,"text":"bed bed/"}
{"index":7,"text":"## ocabulary | i"}

Correct Output (6 items, indices 2-7):
{"blocks":[{"index":2,"corrected":"house"},{"index":3,"corrected":"I build a house."},{"index":4,"corrected":"mine"},{"index":5,"corrected":"Punch a tree Build a shelter Find food"},{"index":6,"corrected":"bed"},{"index":7,"corrected":"Vocabulary"}]}

Note:
- index 2 and 3: TWO SEPARATE blocks → keep separate
- index 4: remove phonetic /man/ and noise → "mine"
- index 5: multi-line block → clean each line, join with spaces, DO NOT split into indices 5,6,7
- index 6: remove trailing "bed/" → "bed"
- index 7: remove ## and | → "Vocabulary"

WRONG Output (SPLIT multi-line block):
{"blocks":[{"index":2,"corrected":"house"},{"index":3,"corrected":"I build a house."},{"index":4,"corrected":"mine"},{"index":5,"corrected":"Punch a tree"},{"index":6,"corrected":"Build a shelter"},{"index":7,"corrected":"Find food"}]}
↑ WRONG: index 5 was split into 5,6,7 — original indices 6,7 lost their content

WRONG Output (MERGED blocks):
{"blocks":[{"index":2,"corrected":"house I build a house."},{"index":3,"corrected":"mine"}]}
↑ WRONG: only 2 items instead of 6, merged blocks 2+3

=== FINAL CHECK ===
COUNT your output items:
- You MUST have exactly $count items
- Indices MUST be: $firstIndex, ${firstIndex + 1}, ... $lastIndex (all present, no gaps, no extra)

Return ONLY this JSON object (no markdown, no explanation):
{"blocks":[{"index":$firstIndex,"corrected":"..."},{"index":${firstIndex + 1},"corrected":"..."},...{"index":$lastIndex,"corrected":"..."}]}''';
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