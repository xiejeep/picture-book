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

  String getTextModel() {
    final settings = StorageService.instance.getAiSettings();
    if (settings?.selectedTextModel != null) {
      final exists = AppConstants.availableTextModels
          .any((m) => m['name'] == settings!.selectedTextModel);
      if (exists) return settings!.selectedTextModel;
    }
    return AppConstants.defaultTextModel;
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
          'watermark_enabled': false,
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

  static const int _maxBatchSize = 50;

  Future<String> extractVisionText(File imageFile, String model) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key not configured');
    }
    return await _visionExtractText(imageFile, model, apiKey);
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

    final batches = <List<Map<int, String>>>[];
    for (int i = 0; i < blocks.length; i += _maxBatchSize) {
      final end = (i + _maxBatchSize).clamp(0, blocks.length);
      batches.add(blocks.sublist(i, end));
    }

    if (batches.length > 1) {
      debugPrint('分${batches.length}批处理');
    }

    String visionResult;
    if (visionDescription != null) {
      visionResult = visionDescription;
      debugPrint('使用缓存的视觉描述');
    } else {
      onProgress?.call('AI正在理解图片内容...');
      visionResult = await _visionExtractText(imageFile, model, apiKey);
    }

    debugPrint('视觉模型提取的文本:\n$visionResult');

    final mergedResult = <int, String>{};
    for (int i = 0; i < batches.length; i++) {
      debugPrint('处理第${i + 1}/${batches.length}批 (${batches[i].length}块)');
      final batchLabel = batches.length > 1 ? ' (${i + 1}/${batches.length})' : '';
      onProgress?.call('AI正在清洗文本$batchLabel...');

      final batchResult = await _textCleanBatch(
        visionResult, batches[i], getTextModel(), apiKey, batchIndex: i,
      );

      debugPrint('批次$i Step2文本模型输出:');
      batchResult.forEach((key, value) {
        debugPrint('  result[$key]: "$value"');
      });

      final result = _validateAndMerge(batchResult, batches[i]);
      final validatedCount = batches[i].where((b) {
        final idx = b.keys.first;
        return result[idx] != b.values.first;
      }).length;
      debugPrint('批次$i 最终结果: 有效修正$validatedCount/${batches[i].length}块');

      mergedResult.addAll(result);
    }

    onProgress?.call('AI优化完成');
    return mergedResult;
  }

  Future<String> _visionExtractText(
    File imageFile,
    String visionModel,
    String apiKey,
  ) async {
    final base64Image = await _imageToBase64(imageFile);

    final prompt = '''This is a page from a children's English picture book.

TASK: Extract ALL English text visible in this image.

RULES:
1. List every English word, phrase, or sentence you can see
2. Keep the text exactly as shown — do NOT translate, correct, or paraphrase
3. Include phonetic guides if visible (e.g. /haus/)
4. Include decorative or heading text if present
5. If there is Chinese text, ignore it
6. Describe the approximate position of each text (e.g. "top-left", "center", "bottom-right")
7. Preserve line breaks within a text block

OUTPUT: Plain text, one text item per line, with position info.
Example:
[top-left] house /haus/
[center] I build a house.
[bottom-right] Punch a tree\\nBuild a shelter

Do NOT output JSON. Just plain text with position annotations.''' ;

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
      debugPrint('Step1 API Error: ${response.statusCode} - ${response.body}');
      throw Exception('Vision model request failed: ${response.statusCode}');
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    debugPrint('Step1视觉模型原始返回:\n$content');

    return content;
  }

  Future<Map<int, String>> _textCleanBatch(
    String visionContext,
    List<Map<int, String>> batch,
    String textModel,
    String apiKey, {
    int batchIndex = 0,
  }) async {
    final firstIndex = batch.first.keys.first;
    final lastIndex = batch.last.keys.first;
    final count = batch.length;

    final blocksInput = batch.map((b) {
      final text = b.values.first.replaceAll('\n', '\\n');
      return '{"index":${b.keys.first},"text":"$text"}';
    }).join('\n');

    final escapedVisionContext = visionContext
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');

    final prompt = '''TASK: Clean OCR text from a children's English picture book.

=== IMAGE REFERENCE (text extracted from the book page by vision AI) ===
$escapedVisionContext

=== OCR BLOCKS TO CLEAN ($count blocks, indices $firstIndex to $lastIndex) ===
$blocksInput

=== RULES ===

1. ONE-TO-ONE MAPPING (CRITICAL):
   - Input has $count blocks → Output MUST have exactly $count blocks
   - Each input index MUST appear in output with THE SAME index number
   - MISSING ANY INDEX = COMPLETE FAILURE

2. USE THE IMAGE REFERENCE to help identify real text vs OCR noise:
   - If OCR says "hou5e" but image reference says "house", correct to "house"
   - If OCR says "Punch a tree ES" and image shows "Punch a tree", remove noise "ES"
   - If OCR text is NOT found in the image reference at all, it may be noise

3. EACH BLOCK IS AN INDEPENDENT OCR REGION (CRITICAL):
   - Every block comes from a SEPARATE rectangular area on the page
   - DO NOT merge adjacent blocks, even if they form a logical unit
   - DO NOT split multi-line blocks (containing \\n) into separate indices

4. CLEANING RULES:
   - Remove phonetic transcriptions: /haus/, /mi:t/, /ˈpɪkæks/ (entire /.../ pattern)
   - Remove decorative symbols: #, ##, |, **, numbering prefixes
   - Remove OCR noise: "F#At", "FRA", "FAABMA!", "60t9!", "ES", "AO" etc.
   - Remove Chinese characters — keep ONLY English text
   - Join multi-line text (\\n) into one line with spaces
   - Empty/garbage → corrected=""

=== OUTPUT FORMAT ===
Return ONLY a JSON object (no markdown, no explanation):
{"blocks":[{"index":$firstIndex,"corrected":"..."},{"index":${firstIndex + 1},"corrected":"..."},...,{"index":$lastIndex,"corrected":"..."}]}

You MUST output exactly $count blocks with indices $firstIndex through $lastIndex.''';

    final response = await http.post(
      Uri.parse(AppConstants.zhipuApiEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': textModel,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('Step2 API Error: ${response.statusCode} - ${response.body}');
      debugPrint('批次$batchIndex Step2失败，回退原文');
      return {for (final b in batch) b.keys.first: b.values.first};
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    debugPrint('批次$batchIndex Step2文本模型原始返回:\n$content');

    try {
      return _parseBlocksJson(content);
    } catch (e) {
      debugPrint('批次$batchIndex Step2 JSON解析失败: $e，回退原文');
      return {for (final b in batch) b.keys.first: b.values.first};
    }
  }

  Map<int, String> _parseBlocksJson(String content) {
    String jsonStr = content;
    jsonStr = jsonStr.replaceAll(RegExp(r'```json\s*'), '');
    jsonStr = jsonStr.replaceAll(RegExp(r'```\s*'), '');
    jsonStr = jsonStr.trim();

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
        if (match == null) continue;
        index = int.parse(match.group(0)!);
      } else {
        continue;
      }
      final corrected = (block['corrected'] ?? '').toString();
      result[index] = corrected;
    }

    return result;
  }

  Map<int, String> _validateAndMerge(
    Map<int, String> corrected,
    List<Map<int, String>> original,
  ) {
    final result = <int, String>{};

    for (final b in original) {
      final originalIndex = b.keys.first;
      final originalText = b.values.first;

      if (corrected.containsKey(originalIndex)) {
        final correctedText = corrected[originalIndex]!;
        if (_isRelevant(originalText, correctedText)) {
          result[originalIndex] = correctedText;
        } else {
          result[originalIndex] = originalText;
          debugPrint('  内容校验不通过 index=$originalIndex: "$originalText" → "$correctedText", 回退原文');
        }
      } else {
        result[originalIndex] = originalText;
        debugPrint('  填充缺失index $originalIndex: "$originalText"');
      }
    }

    return result;
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

    final batches = <List<Map<int, String>>>[];
    for (int i = 0; i < blocksWithDraft.length; i += _maxBatchSize) {
      final end = (i + _maxBatchSize).clamp(0, blocksWithDraft.length);
      batches.add(blocksWithDraft.sublist(i, end));
    }

    if (batches.length > 1) {
      debugPrint('分${batches.length}批处理');
    }

    String visionResult;
    if (visionDescription != null) {
      visionResult = visionDescription;
      debugPrint('使用缓存的视觉描述');
    } else {
      onProgress?.call('AI正在理解图片内容...');
      visionResult = await _visionExtractText(imageFile, model, apiKey);
    }

    debugPrint('翻译用视觉模型描述:\n$visionResult');

    final mergedResult = <int, String>{};
    for (int i = 0; i < batches.length; i++) {
      debugPrint('处理翻译第${i + 1}/${batches.length}批 (${batches[i].length}块)');
      final batchLabel = batches.length > 1 ? ' (${i + 1}/${batches.length})' : '';
      onProgress?.call('AI正在优化翻译$batchLabel...');

      final batchResult = await _translationRefineBatch(
        visionResult, batches[i], getTextModel(), apiKey, batchIndex: i,
      );

      debugPrint('翻译批次$i 输出:');
      batchResult.forEach((key, value) {
        debugPrint('  result[$key]: "$value"');
      });

      mergedResult.addAll(batchResult);
    }

    onProgress?.call('AI翻译优化完成');
    return mergedResult;
  }

  Future<Map<int, String>> _translationRefineBatch(
    String visionContext,
    List<Map<int, String>> batch,
    String textModel,
    String apiKey, {
    int batchIndex = 0,
  }) async {
    final firstIndex = batch.first.keys.first;
    final lastIndex = batch.last.keys.first;
    final count = batch.length;

    final blocksInput = batch.map((b) {
      final parts = b.values.first.split('|||');
      final original = parts[0].replaceAll('\n', '\\n');
      final draft = parts.length > 1 ? parts[1] : '';
      return '{"index":${b.keys.first},"original":"$original","draft_translation":"$draft"}';
    }).join('\n');

    final escapedVisionContext = visionContext
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');

    final prompt = '''你是一个专业翻译校对助手。

=== 图片内容描述 ===
$escapedVisionContext

=== 待翻译文本块 ($count blocks, indices $firstIndex to $lastIndex) ===
每个块包含英文原文和机器翻译草稿。
$blocksInput

=== 任务 ===
根据图片内容理解文本的语境，对机器翻译草稿进行二次优化：

1. 结合图片理解文本的上下文和场景，翻译要符合图片中的语境
2. 纠正机器翻译中生硬、不准确或不自然的地方
3. 保持翻译简洁自然，通俗易懂
4. 如果草稿翻译已经很好，可以保留
5. 每个块独立翻译，不要合并或拆分

=== 输出格式 ===
返回JSON（不要markdown，不要解释）：
{"blocks":[{"index":$firstIndex,"translation":"优化后的中文翻译"},{"index":${firstIndex + 1},"translation":"..."},...,{"index":$lastIndex,"translation":"..."}]}

严格输出$count个块，索引从$firstIndex到$lastIndex。''';

    final response = await http.post(
      Uri.parse(AppConstants.zhipuApiEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': textModel,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('翻译批次$batchIndex API Error: ${response.statusCode} - ${response.body}');
      debugPrint('翻译批次$batchIndex失败，回退草稿');
      return _fallbackToDraft(batch);
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    debugPrint('翻译批次$batchIndex 原始返回:\n$content');

    try {
      return _parseTranslationJson(content, batch);
    } catch (e) {
      debugPrint('翻译批次$batchIndex JSON解析失败: $e，回退草稿');
      return _fallbackToDraft(batch);
    }
  }

  Map<int, String> _parseTranslationJson(String content, List<Map<int, String>> batch) {
    String jsonStr = content;
    jsonStr = jsonStr.replaceAll(RegExp(r'```json\s*'), '');
    jsonStr = jsonStr.replaceAll(RegExp(r'```\s*'), '');
    jsonStr = jsonStr.trim();

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
        if (match == null) continue;
        index = int.parse(match.group(0)!);
      } else {
        continue;
      }
      final translation = (block['translation'] ?? '').toString();
      result[index] = translation;
    }

    final fallback = _fallbackToDraft(batch);
    for (final b in batch) {
      final idx = b.keys.first;
      if (!result.containsKey(idx) || result[idx]!.trim().isEmpty) {
        result[idx] = fallback[idx]!;
      }
    }

    return result;
  }

  Map<int, String> _fallbackToDraft(List<Map<int, String>> batch) {
    final result = <int, String>{};
    for (final b in batch) {
      final parts = b.values.first.split('|||');
      result[b.keys.first] = parts.length > 1 ? parts[1] : '';
    }
    return result;
  }

  Future<String> _imageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Str = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64Str';
  }
}
