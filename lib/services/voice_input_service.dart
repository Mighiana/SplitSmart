import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Parsed voice command result.
class VoiceResult {
  final double? amount;
  final String? description;
  final String? paidBy;

  VoiceResult({this.amount, this.description, this.paidBy});

  bool get hasData => amount != null || description != null || paidBy != null;
}

/// Zero-cost voice input using device's built-in speech engine.
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool get isAvailable => _initialized;

  /// Initialize speech recognition. Call once.
  Future<bool> init() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (e) => debugPrint('[Voice] Error: ${e.errorMsg}'),
      );
      return _initialized;
    } catch (e) {
      debugPrint('[Voice] Init failed: $e');
      return false;
    }
  }

  /// Start listening. Returns results via [onResult] callback.
  /// [onDone] is called when the user stops speaking.
  /// [localeId] optionally specifies the speech recognition language (e.g. 'ur_PK', 'ar_SA').
  Future<void> startListening({
    required void Function(String text) onResult,
    required VoidCallback onDone,
    String? localeId,
  }) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return;
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
      localeId: localeId ?? _defaultLocaleId(),
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(cancelOnError: true),
    );
  }

  /// Map app language code to speech locale ID.
  /// The device must have the language pack installed.
  static String? _defaultLocaleId() => null; // Uses device default

  /// Get the speech locale ID for a given app locale code.
  static String? localeIdFor(String langCode) {
    const map = {
      'en': 'en_US',
      'ur': 'ur_PK',
      'ar': 'ar_SA',
      'fr': 'fr_FR',
      'es': 'es_ES',
      'de': 'de_DE',
      'tr': 'tr_TR',
      'hi': 'hi_IN',
    };
    return map[langCode];
  }

  /// Get list of available locales on this device.
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_initialized) await init();
    return _speech.locales();
  }

  /// Stop listening immediately.
  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  /// Parse spoken text into structured expense data.
  /// Handles phrases like:
  ///   "42 euros dinner paid by Ali"
  ///   "Uber 8 dollars"
  ///   "coffee three fifty"
  VoiceResult parseSpokenText(String text, List<String> groupMembers) {
    final lower = text.toLowerCase().trim();

    final amount = _extractAmount(lower);
    final paidBy = _extractPaidBy(lower, groupMembers);
    final description = _extractDescription(lower, amount, paidBy);

    return VoiceResult(
      amount: amount,
      description: description,
      paidBy: paidBy,
    );
  }

  /// Extract amount from spoken text.
  double? _extractAmount(String text) {
    // Direct number: "42", "42.50", "8.5"
    final numMatch = RegExp(r'(\d+\.?\d*)').firstMatch(text);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!);
    }

    // Word numbers: "twenty", "fifty", "three fifty"
    final wordNumbers = <String, double>{
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
      'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
      'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
      'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
      'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
      'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
      'eighty': 80, 'ninety': 90, 'hundred': 100,
    };

    // "three fifty" → 3.50
    final twoWordMatch = RegExp(r'\b(\w+)\s+(\w+)\b').allMatches(text);
    for (final m in twoWordMatch) {
      final w1 = m.group(1)!;
      final w2 = m.group(2)!;
      if (wordNumbers.containsKey(w1) && wordNumbers.containsKey(w2)) {
        final v1 = wordNumbers[w1]!;
        final v2 = wordNumbers[w2]!;
        if (v1 < 100 && v2 < 100) {
          return v1 + v2 / 100; // "three fifty" → 3.50
        }
      }
    }

    // Single word: "twenty" → 20
    for (final entry in wordNumbers.entries) {
      if (text.contains(entry.key) && entry.value > 0) {
        return entry.value;
      }
    }

    return null;
  }

  /// Extract who paid from spoken text.
  /// SEC-M6: Prefer exact match over prefix match to prevent misattribution.
  String? _extractPaidBy(String text, List<String> members) {
    // "paid by Ali" or "by Ali"
    final paidByMatch = RegExp(r'(?:paid\s+by|by)\s+(\w+)').firstMatch(text);
    if (paidByMatch != null) {
      final name = paidByMatch.group(1)!;
      // "me" or "myself" → "You"
      if (name == 'me' || name == 'myself' || name == 'i') return 'You';
      // Exact match first (case-insensitive)
      for (final m in members) {
        if (m.toLowerCase() == name.toLowerCase()) return m;
      }
      // Prefix match only if no exact match found
      for (final m in members) {
        if (m.toLowerCase().startsWith(name.toLowerCase())) return m;
      }
    }

    // "i paid" or "my expense"
    if (text.contains('i paid') || text.contains('my ') || text.contains('myself')) {
      return 'You';
    }

    return null;
  }

  /// Extract the description by removing amount and paid-by parts.
  String? _extractDescription(String text, double? amount, String? paidBy) {
    var desc = text;

    // Remove currency words
    desc = desc.replaceAll(RegExp(r'\b(dollars?|euros?|pounds?|rupees?|bucks?)\b'), '');
    // Remove "paid by X"
    desc = desc.replaceAll(RegExp(r'paid\s+by\s+\w+'), '');
    desc = desc.replaceAll(RegExp(r'\bby\s+\w+$'), '');
    // Remove numbers
    desc = desc.replaceAll(RegExp(r'\d+\.?\d*'), '');
    // Remove filler words
    desc = desc.replaceAll(RegExp(r'\b(for|the|a|an|at|on|in|to|and|with|i|my|me|myself)\b'), '');
    // Clean up
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (desc.isEmpty) return null;

    // Capitalize first letter
    return desc[0].toUpperCase() + desc.substring(1);
  }
}
