import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_app/data/models/text_block_model.dart';

void main() {
  group('TextBlockModel.copyWith', () {
    late TextBlockModel block;

    setUp(() {
      block = TextBlockModel(
        left: 10,
        top: 20,
        right: 100,
        bottom: 50,
        text: 'Hello',
        translatedText: '你好',
        aiTranslatedText: 'AI你好',
        originalText: 'Hola',
        aiEnhancedText: 'Hello!',
      );
    });

    test('keeps original values when no args', () {
      final copy = block.copyWith();
      expect(copy.left, 10);
      expect(copy.top, 20);
      expect(copy.text, 'Hello');
      expect(copy.translatedText, '你好');
      expect(copy.aiTranslatedText, 'AI你好');
    });

    test('overrides text', () {
      final copy = block.copyWith(text: 'World');
      expect(copy.text, 'World');
      expect(copy.translatedText, '你好');
    });

    test('overrides nullable fields', () {
      final copy = block.copyWith(translatedText: '新翻译');
      expect(copy.translatedText, '新翻译');
    });

    test('sets nullable to null via clear flag', () {
      final copy = block.copyWith(clearTranslatedText: true);
      expect(copy.translatedText, isNull);
    });

    test('partial null override without clear flag keeps original', () {
      final copy = block.copyWith(translatedText: null);
      expect(copy.translatedText, '你好');
    });

    test('clear flag overrides null arg for translatedText', () {
      final copy = block.copyWith(
        translatedText: null,
        clearTranslatedText: true,
      );
      expect(copy.translatedText, isNull);
    });

    test('clearAiTranslatedText clears aiTranslatedText', () {
      final copy = block.copyWith(clearAiTranslatedText: true);
      expect(copy.aiTranslatedText, isNull);
    });

    test('clearOriginalText clears originalText', () {
      final copy = block.copyWith(clearOriginalText: true);
      expect(copy.originalText, isNull);
    });

    test('clearAiEnhancedText clears aiEnhancedText', () {
      final copy = block.copyWith(clearAiEnhancedText: true);
      expect(copy.aiEnhancedText, isNull);
    });

    test('multiple clear flags work together', () {
      final copy = block.copyWith(
        clearTranslatedText: true,
        clearAiTranslatedText: true,
      );
      expect(copy.translatedText, isNull);
      expect(copy.aiTranslatedText, isNull);
      expect(copy.text, 'Hello');
    });

    test('fromData creates equivalent model', () {
      final fromData = TextBlockModel.fromData(
        boundingBox: Rect.fromLTRB(10, 20, 100, 50),
        text: 'Hello',
        translatedText: '你好',
        aiTranslatedText: 'AI你好',
        originalText: 'Hola',
        aiEnhancedText: 'Hello!',
      );
      expect(fromData.left, block.left);
      expect(fromData.top, block.top);
      expect(fromData.right, block.right);
      expect(fromData.bottom, block.bottom);
      expect(fromData.text, block.text);
    });
  });
}
