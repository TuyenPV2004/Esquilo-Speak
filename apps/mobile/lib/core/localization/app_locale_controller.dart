import 'package:flutter/material.dart';

import '../storage/app_database.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController(this._database);

  static const _cacheKey = 'app.ui-locale';

  final AppDatabase _database;
  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> initialize() async {
    final cached = await _database.cachedJson(_cacheKey);
    final languageTag = cached?['languageTag'] as String?;
    if (languageTag != null) _locale = localeFromLanguageTag(languageTag);
  }

  Future<void> setLanguageTag(String? languageTag) async {
    final next = languageTag == null
        ? null
        : localeFromLanguageTag(languageTag);
    if (_locale?.toLanguageTag() == next?.toLanguageTag()) return;
    _locale = next;
    if (languageTag != null) {
      await _database.cacheJson(_cacheKey, {'languageTag': languageTag});
    }
    notifyListeners();
  }
}

Locale localeFromLanguageTag(String languageTag) {
  final parts = languageTag.replaceAll('_', '-').split('-');
  if (parts.isEmpty || parts.first.isEmpty) return const Locale('und');

  String? scriptCode;
  String? countryCode;
  for (final part in parts.skip(1)) {
    if (part.length == 4 && scriptCode == null) {
      scriptCode = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
    } else if ((part.length == 2 || part.length == 3) && countryCode == null) {
      countryCode = part.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first.toLowerCase(),
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}
