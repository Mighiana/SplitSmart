import 'package:flutter_test/flutter_test.dart';
import 'package:splitzee/services/voice_input_service.dart';

/// Tests the real offline parser behind voice entry
/// (`VoiceInputService.parseSpokenText`), not a copy of its regexes.
void main() {
  final parser = VoiceInputService.instance;
  const members = ['You', 'Ali', 'Sara', 'Alina'];

  group('parseSpokenText', () {
    test('amount, description and payer from a typical phrase', () {
      final r = parser.parseSpokenText('42 euros dinner paid by Ali', members);
      expect(r.amount, 42);
      expect(r.paidBy, 'Ali');
      expect(r.description, 'Dinner');
    });

    test('decimal amount', () {
      final r = parser.parseSpokenText('taxi 8.5 dollars', members);
      expect(r.amount, 8.5);
      expect(r.description, 'Taxi');
    });

    test('two number words are read as units and cents', () {
      expect(parser.parseSpokenText('coffee three fifty', members).amount, 3.5);
    });

    test('single number word', () {
      expect(parser.parseSpokenText('lunch twenty', members).amount, 20);
    });

    test('number words only match whole words', () {
      // "money" contains "one" but must not be read as 1.
      expect(parser.parseSpokenText('money for lunch twenty', members).amount,
          20);
    });

    test('"paid by me" maps to the current user', () {
      expect(parser.parseSpokenText('groceries 30 paid by me', members).paidBy,
          'You');
    });

    test('exact member name wins over a prefix match', () {
      // "ali" is a prefix of "Alina" — the exact member must be chosen.
      expect(parser.parseSpokenText('snacks 5 by ali', members).paidBy, 'Ali');
    });

    test('prefix match is used when no exact match exists', () {
      expect(parser.parseSpokenText('fuel 60 paid by sar', members).paidBy,
          'Sara');
    });

    test('unknown payer is left empty', () {
      expect(parser.parseSpokenText('fuel 60 paid by bob', members).paidBy,
          isNull);
    });

    test('no recognisable data', () {
      final r = parser.parseSpokenText('', members);
      expect(r.hasData, isFalse);
    });
  });
}
