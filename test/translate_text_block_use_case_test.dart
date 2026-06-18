import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_app/application/reading/translate_text_block_use_case.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/translation_service.dart';

void main() {
  TextBlockModel block({
    String? aiTranslatedText,
    String? translatedText,
  }) {
    return TextBlockModel.fromData(
      boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
      text: 'hello',
      aiTranslatedText: aiTranslatedText,
      translatedText: translatedText,
    );
  }

  TranslateTextBlockUseCase useCaseWith(
      Future<TranslationResult> Function(String) fn) {
    return TranslateTextBlockUseCase(fn);
  }

  group('TranslateTextBlockUseCase.cachedTranslation priority', () {
    final useCase = useCaseWith(
        (_) async => const TranslationResult(status: TranslationStatus.idle));

    test('prefers aiTranslatedText over translatedText', () {
      expect(
        useCase.cachedTranslation(block(
          aiTranslatedText: 'AI 翻译',
          translatedText: '人工翻译',
        )),
        'AI 翻译',
      );
    });

    test('returns translatedText when no aiTranslatedText', () {
      expect(
        useCase.cachedTranslation(block(translatedText: '人工翻译')),
        '人工翻译',
      );
    });

    test('returns null when no cache', () {
      expect(useCase.cachedTranslation(block()), isNull);
    });
  });

  group('TranslateTextBlockUseCase.translate', () {
    test('returns translated with updated block on done', () async {
      final useCase = useCaseWith((_) async => const TranslationResult(
            status: TranslationStatus.done,
            translatedText: '你好',
          ));

      final result = await useCase.translate(block: block(), blockIndex: 2);

      expect(result.phase, TranslateTextBlockPhase.translated);
      expect(result.translatedText, '你好');
      expect(result.status, TranslationStatus.done);
      expect(result.shouldPersist, isTrue);
      expect(result.updatedBlock?.aiTranslatedText, '你好');
    });

    test('returns failed with null text on non-done status', () async {
      final useCase = useCaseWith((_) async => const TranslationResult(
            status: TranslationStatus.downloadingModel,
          ));

      final result = await useCase.translate(block: block(), blockIndex: 0);

      expect(result.phase, TranslateTextBlockPhase.failed);
      expect(result.translatedText, isNull);
      expect(result.status, TranslationStatus.downloadingModel);
      expect(result.shouldPersist, isFalse);
      expect(result.updatedBlock, isNull);
    });

    test('returns failed when status done but text is null', () async {
      final useCase = useCaseWith(
          (_) async => const TranslationResult(status: TranslationStatus.done));

      final result = await useCase.translate(block: block(), blockIndex: 0);

      expect(result.phase, TranslateTextBlockPhase.failed);
      expect(result.translatedText, isNull);
      expect(result.shouldPersist, isFalse);
      expect(result.updatedBlock, isNull);
    });
  });
}
