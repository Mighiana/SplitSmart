import 'package:flutter_test/flutter_test.dart';
import 'package:splitzee/services/cloud_doc_parser.dart';

void main() {
  group('CloudDocParser.expense', () {
    test('maps a well-formed doc', () {
      final e = CloudDocParser.expense({
        'desc': 'Dinner',
        'amount': 42,
        'cat': '🍽️',
        'paidBy': 'Ali',
        'paidById': 'm1',
        'date': '2026-10-06',
        'receipt': true,
        'splitIds': {'m1': 21, 'm2': 21.0},
        'addedBy': 'uid1',
      }, 7);
      expect(e.id, 7);
      expect(e.amount, 42);
      expect(e.receipt, isTrue);
      expect(e.splitIds, {'m1': 21.0, 'm2': 21.0});
      expect(e.paidById, 'm1');
    });

    test('wrong-typed fields from a tampered client do not throw', () {
      final e = CloudDocParser.expense({
        'desc': 123,
        'amount': 'lots',
        'cat': null,
        'paidBy': ['x'],
        'date': 99,
        'receipt': 'yes',
        'splits': {'Ali': 'ten', 'Sara': 5},
        'splitIds': 'not a map',
        'createdBy': {'a': 1},
      }, 1);
      expect(e.desc, '');
      expect(e.amount, 0);
      expect(e.cat, '💰');
      expect(e.date, '');
      expect(e.receipt, isFalse);
      expect(e.splits, {'Sara': 5.0});
      expect(e.splitIds, isNull);
      expect(e.createdBy, isNull);
    });

    test('negative and non-finite amounts are rejected', () {
      expect(CloudDocParser.expense({'amount': -5}, 1).amount, 0);
      expect(CloudDocParser.expense({'amount': double.infinity}, 1).amount, 0);
    });
  });

  group('CloudDocParser.safeReceiptPath', () {
    test('keeps Firebase Storage URLs and local paths', () {
      const fs =
          'https://firebasestorage.googleapis.com/v0/b/x.appspot.com/o/r.jpg';
      expect(CloudDocParser.safeReceiptPath(fs), fs);
      const app = 'https://splitsmart-3898.firebasestorage.app/o/r.jpg';
      expect(CloudDocParser.safeReceiptPath(app), app);
      expect(CloudDocParser.safeReceiptPath('/data/receipts/r.jpg'),
          '/data/receipts/r.jpg');
    });

    test('drops other remote URLs (tracking pixels, cleartext)', () {
      expect(CloudDocParser.safeReceiptPath('https://evil.example/p.png'),
          isNull);
      expect(
          CloudDocParser.safeReceiptPath(
              'https://firebasestorage.googleapis.com.evil.example/p.png'),
          isNull);
      expect(
          CloudDocParser.safeReceiptPath(
              'http://firebasestorage.googleapis.com/p.png'),
          isNull);
      expect(CloudDocParser.safeReceiptPath(42), isNull);
      expect(CloudDocParser.safeReceiptPath(''), isNull);
    });
  });

  test('settlement with wrong types falls back safely', () {
    final s = CloudDocParser.settlement(
        {'from': 1, 'to': 'Ali', 'amount': '5', 'method': 3, 'date': null});
    expect(s.from, '');
    expect(s.to, 'Ali');
    expect(s.amount, 0);
    expect(s.method, 'Cash');
  });
}
