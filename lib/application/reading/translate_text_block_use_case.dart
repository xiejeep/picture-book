import '../../data/models/text_block_model.dart';
import '../../data/services/translation_service.dart';

enum TranslateTextBlockPhase {
  translated,
  failed,
}

class TranslateTextBlockResult {
  final TranslateTextBlockPhase phase;
  final int blockIndex;
  final String translatedText;
  final TranslationStatus status;
  final TextBlockModel? updatedBlock;

  const TranslateTextBlockResult({
    required this.phase,
    required this.blockIndex,
    required this.translatedText,
    required this.status,
    this.updatedBlock,
  });

  bool get shouldPersist => phase == TranslateTextBlockPhase.translated;
}

class TranslateTextBlockUseCase {
  TranslateTextBlockUseCase(this._translationService);

  final TranslationService _translationService;

  String? cachedTranslation(TextBlockModel block) {
    return block.aiTranslatedText ?? block.translatedText;
  }

  Future<TranslateTextBlockResult> translate({
    required TextBlockModel block,
    required int blockIndex,
  }) async {
    final result = await _translationService.translateWithStatus(block.text);

    if (result.status == TranslationStatus.done &&
        result.translatedText != null) {
      return TranslateTextBlockResult(
        phase: TranslateTextBlockPhase.translated,
        blockIndex: blockIndex,
        translatedText: result.translatedText!,
        status: result.status,
        updatedBlock: block.copyWith(aiTranslatedText: result.translatedText),
      );
    }

    return TranslateTextBlockResult(
      phase: TranslateTextBlockPhase.failed,
      blockIndex: blockIndex,
      translatedText: result.translatedText ?? '',
      status: result.status,
    );
  }
}
