import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_app/application/reading/translate_text_block_use_case.dart';
import 'package:book_app/data/models/text_block_model.dart';
import 'package:book_app/data/services/translation_service.dart';

void main() {
  // TranslationService has a private constructor, so the async translate()
  // path cannot be exercised without a real service instance. These tests
  // cover the pure cached-translation priority logic, which is the part most
  // likely to regress when block fields change. The real singleton is safe
  // here because cachedTranslation() never touches the service.
  final useCase = TranslateTextBlockUseCase(TranslationService.instance);

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

  group('TranslateTextBlockUseCase.cachedTranslation priority', () {
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
      expect(useCase.cachedTranslation(block(translatedText: '人工翻译')), '人工翻译');
    });

    test('returns null when no cache', () {
      expect(useCase.cachedTranslation(block()), isNull);
    });
  });
}
