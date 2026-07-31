import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all localization files expose the template keys and non-empty text',
    () {
      final template = _messages('lib/l10n/app_en.arb');
      final files = Directory('lib/l10n').listSync().whereType<File>().where(
        (file) => RegExp(r'app_[A-Za-z0-9_-]+\.arb$').hasMatch(file.path),
      );

      expect(files, isNotEmpty);
      for (final file in files) {
        final messages = _messages(file.path);
        expect(
          messages.keys,
          unorderedEquals(template.keys),
          reason: '${file.path} must match the template localization keys.',
        );
        expect(
          messages.values,
          everyElement(
            isA<String>().having((value) => value, 'value', isNotEmpty),
          ),
          reason: '${file.path} contains an empty localized value.',
        );
      }
    },
  );
}

Map<String, dynamic> _messages(String path) {
  final values =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  values.removeWhere((key, value) => key.startsWith('@'));
  return values;
}
