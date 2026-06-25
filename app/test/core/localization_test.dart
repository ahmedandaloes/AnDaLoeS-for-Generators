import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB localization parity', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> ar;

    setUpAll(() {
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      ar = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
          as Map<String, dynamic>;
      // Remove metadata keys (@@locale, @keyName descriptions)
      en.removeWhere((k, _) => k.startsWith('@'));
      ar.removeWhere((k, _) => k.startsWith('@'));
    });

    test('English ARB is non-empty after loading', () {
      expect(en, isNotEmpty);
    });

    test('Arabic ARB is non-empty after loading', () {
      expect(ar, isNotEmpty);
    });

    test('all English keys are present in Arabic', () {
      final missing = en.keys.where((k) => !ar.containsKey(k)).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: 'Missing Arabic translations for: $missing',
      );
    });

    test('no orphan Arabic keys missing from English', () {
      final orphan = ar.keys.where((k) => !en.containsKey(k)).toList()
        ..sort();
      expect(
        orphan,
        isEmpty,
        reason: 'Arabic has keys not in English: $orphan',
      );
    });

    test('all English values are non-null strings', () {
      for (final entry in en.entries) {
        expect(
          entry.value,
          isA<String>(),
          reason: 'Key "${entry.key}" has non-string value',
        );
      }
    });

    test('all Arabic values are non-null strings', () {
      for (final entry in ar.entries) {
        expect(
          entry.value,
          isA<String>(),
          reason: 'Key "${entry.key}" has non-string value in Arabic',
        );
      }
    });
  });
}
