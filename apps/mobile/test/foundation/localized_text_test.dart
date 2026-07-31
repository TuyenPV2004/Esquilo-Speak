import 'package:esquilospeak_mobile/core/localization/app_locale_controller.dart';
import 'package:esquilospeak_mobile/core/localization/localized_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esquilospeak_mobile/core/storage/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('localized content resolution', () {
    const values = {'en': 'Hello', 'vi-VN': 'Xin chào'};

    test('matches a full BCP 47 tag before its language', () {
      expect(resolveLocalizedText(values, 'vi-VN'), 'Xin chào');
      expect(resolveLocalizedText(values, 'en-GB'), 'Hello');
    });

    test('uses the entity default locale instead of a global language', () {
      expect(
        resolveLocalizedText(values, 'ko-KR', defaultLocale: 'vi'),
        'Xin chào',
      );
    });
  });

  test('locale parser preserves language, script and region subtags', () {
    final locale = localeFromLanguageTag('zh-Hant-TW');
    expect(locale.languageCode, 'zh');
    expect(locale.scriptCode, 'Hant');
    expect(locale.countryCode, 'TW');
  });

  test('locale controller restores the persisted interface locale', () async {
    final database = AppDatabase(factory: databaseFactoryFfi);
    await database.open(path: inMemoryDatabasePath);
    addTearDown(database.close);

    final first = AppLocaleController(database);
    await first.setLanguageTag('vi-VN');
    final restored = AppLocaleController(database);
    await restored.initialize();

    expect(restored.locale?.toLanguageTag(), 'vi-VN');
  });
}
