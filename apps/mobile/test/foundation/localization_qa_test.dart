import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vietnamese and English localization files expose the same keys', () {
    final english = _messages('lib/l10n/app_en.arb');
    final vietnamese = _messages('lib/l10n/app_vi.arb');

    expect(vietnamese.keys, unorderedEquals(english.keys));
    expect(
      vietnamese.values,
      everyElement(isA<String>().having((value) => value, 'value', isNotEmpty)),
    );
  });
}

Map<String, dynamic> _messages(String path) {
  final values =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  values.removeWhere((key, value) => key.startsWith('@'));
  return values;
}
