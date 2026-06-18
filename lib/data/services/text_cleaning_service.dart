import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/constants/app_log.dart';
import '../../core/constants/constants.dart';
import '../../core/constants/app_prompts.dart';
import 'storage_service.dart';

class TextCleaningService {
  static final TextCleaningService _instance = TextCleaningService._internal();
  static TextCleaningService get instance => _instance;
  TextCleaningService._internal();

  static const int _maxBatchSize = 50;

  String getTextModel() {
    final settings = StorageService.instance.getAiSettings();
    if (settings?.selectedTextModel != null) {
      final exists = AppConstants.availableTextModels
          .any((m) => m['name'] == settings!.selectedTextModel);
      if (exists) return settings!.selectedTextModel;
    }
    return AppConstants.defaultTextModel;
  }

  Future<Map<int, String>> enhanceTextBlocks(
    String visionContext,
    List<Map<int, String>> blocks,
    String textModel, {
    void Function(String message)? onProgress,
  }) async {
    debugPrint('=== TextCleaningService.enhanceTextBlocks ===');
    debugPrint('输入blocks数: ${blocks.length}');

    final apiKey = await StorageService.instance.getApiKey();
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
      final batchLabel =
          batches.length > 1 ? ' (${i + 1}/${batches.length})' : '';
      onProgress?.call('AI正在清洗文本$batchLabel...');

      final batchResult = await _textCleanBatch(
        visionContext,
        batches[i],
        textModel,
        apiKey,
        batchIndex: i,
      );

      debugPrint('批次$i Step2文本模型输出:');
      batchResult.forEach((key, value) {
        AppLog.content('  result[$key]: "$value"');
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

  Future<Map<int, String>> enhanceTranslation(
    String visionContext,
    List<Map<int, String>> blocksWithDraft,
    String textModel, {
    void Function(String message)? onProgress,
  }) async {
    debugPrint('=== TextCleaningService.enhanceTranslation ===');
    debugPrint('输入blocks数: ${blocksWithDraft.length}');

    final apiKey = await StorageService.instance.getApiKey();
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

    final mergedResult = <int, String>{};
    for (int i = 0; i < batches.length; i++) {
      debugPrint('处理翻译第${i + 1}/${batches.length}批 (${batches[i].length}块)');
      final batchLabel =
          batches.length > 1 ? ' (${i + 1}/${batches.length})' : '';
      onProgress?.call('AI正在优化翻译$batchLabel...');

      final batchResult = await _translationRefineBatch(
        visionContext,
        batches[i],
        textModel,
        apiKey,
        batchIndex: i,
      );

      debugPrint('翻译批次$i 输出:');
      batchResult.forEach((key, value) {
        AppLog.content('  result[$key]: "$value"');
      });

      mergedResult.addAll(batchResult);
    }

    onProgress?.call('AI翻译优化完成');
    return mergedResult;
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
      return jsonEncode({'index': b.keys.first, 'text': b.values.first});
    }).join('\n');

    final escapedVisionContext = visionContext
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');

    final prompt = AppPrompts.textCleanBatch(
      escapedVisionContext: escapedVisionContext,
      count: count,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      blocksInput: blocksInput,
    );

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
      AppLog.content('Step2 API Error: ${response.statusCode} - ${response.body}');
      debugPrint('批次$batchIndex Step2失败，回退原文');
      return {for (final b in batch) b.keys.first: b.values.first};
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    AppLog.content('批次$batchIndex Step2文本模型原始返回:\n$content');

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
          debugPrint(
              '  内容校验不通过 index=$originalIndex, 回退原文');
        }
      } else {
        result[originalIndex] = originalText;
        debugPrint('  填充缺失index $originalIndex');
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
      final original = parts[0];
      final draft = parts.length > 1 ? parts[1] : '';
      return jsonEncode({
        'index': b.keys.first,
        'original': original,
        'draft_translation': draft,
      });
    }).join('\n');

    final escapedVisionContext = visionContext
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');

    final prompt = AppPrompts.translationRefineBatch(
      escapedVisionContext: escapedVisionContext,
      count: count,
      firstIndex: firstIndex,
      lastIndex: lastIndex,
      blocksInput: blocksInput,
    );

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
      debugPrint(
          '翻译批次$batchIndex API Error: ${response.statusCode}');
      debugPrint('翻译批次$batchIndex失败，回退草稿');
      return _fallbackToDraft(batch);
    }

    final responseBody = jsonDecode(response.body);
    final content = responseBody['choices'][0]['message']['content'] as String;

    AppLog.content('翻译批次$batchIndex 原始返回:\n$content');

    try {
      return _parseTranslationJson(content, batch);
    } catch (e) {
      debugPrint('翻译批次$batchIndex JSON解析失败: $e，回退草稿');
      return _fallbackToDraft(batch);
    }
  }

  Map<int, String> _parseTranslationJson(
      String content, List<Map<int, String>> batch) {
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
}
