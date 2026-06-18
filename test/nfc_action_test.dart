import 'package:flutter_test/flutter_test.dart';
import 'package:book_app/data/services/nfc_service.dart';

void main() {
  group('NfcAction.tryParse', () {
    test('parses standard URI', () {
      final action = NfcAction.tryParse('dianduya://play/book1/page1/block1');
      expect(action, isNotNull);
      expect(action!.bookId, 'book1');
      expect(action.pageId, 'page1');
      expect(action.blockId, 'block1');
    });

    test('parses URI with UUIDs (stripped dashes)', () {
      final action = NfcAction.tryParse(
        'dianduya://play/550e8400e29b41d4a716446655440000/'
        '660e8400e29b41d4a716446655440001/'
        '770e8400e29b41d4a716446655440002',
      );
      expect(action, isNotNull);
      expect(action!.bookId, '550e8400-e29b-41d4-a716-446655440000');
      expect(action.pageId, '660e8400-e29b-41d4-a716-446655440001');
      expect(action.blockId, '770e8400-e29b-41d4-a716-446655440002');
    });

    test('returns null for invalid URI', () {
      expect(NfcAction.tryParse('invalid'), isNull);
      expect(NfcAction.tryParse('dianduya://play/'), isNull);
      expect(NfcAction.tryParse('dianduya://play/a/b'), isNull);
      expect(NfcAction.tryParse(''), isNull);
    });

    test('returns null for wrong scheme', () {
      expect(
        NfcAction.tryParse('other://play/book1/page1/block1'),
        isNull,
      );
    });
  });

  group('NfcAction.toUri', () {
    test('generates correct URI', () {
      final action = NfcAction(
        bookId: 'book1',
        pageId: 'page1',
        blockId: 'block1',
      );
      expect(action.toUri(), 'dianduya://play/book1/page1/block1');
    });

    test('strips dashes from UUIDs in URI', () {
      final action = NfcAction(
        bookId: '550e8400-e29b-41d4-a716-446655440000',
        pageId: '660e8400-e29b-41d4-a716-446655440001',
        blockId: '770e8400-e29b-41d4-a716-446655440002',
      );
      expect(
        action.toUri(),
        'dianduya://play/550e8400e29b41d4a716446655440000/'
        '660e8400e29b41d4a716446655440001/'
        '770e8400e29b41d4a716446655440002',
      );
    });

    test('round-trips correctly', () {
      final original = NfcAction(
        bookId: '550e8400-e29b-41d4-a716-446655440000',
        pageId: '660e8400-e29b-41d4-a716-446655440001',
        blockId: '770e8400-e29b-41d4-a716-446655440002',
      );
      final uri = original.toUri();
      final parsed = NfcAction.tryParse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.bookId, original.bookId);
      expect(parsed.pageId, original.pageId);
      expect(parsed.blockId, original.blockId);
    });
  });

  group('NfcAction equality', () {
    test('identical actions are equal', () {
      final a = NfcAction(bookId: 'b1', pageId: 'p1', blockId: 'bl1');
      final b = NfcAction(bookId: 'b1', pageId: 'p1', blockId: 'bl1');
      expect(a.toString(), b.toString());
    });

    test('different actions are not equal', () {
      final a = NfcAction(bookId: 'b1', pageId: 'p1', blockId: 'bl1');
      final b = NfcAction(bookId: 'b1', pageId: 'p1', blockId: 'bl2');
      expect(a.toString(), isNot(b.toString()));
    });
  });
}
