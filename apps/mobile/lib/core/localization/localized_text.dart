typedef LocalizedText = Map<String, String>;

LocalizedText localizedText(Object? value) => (value as Map<String, dynamic>)
    .map((key, item) => MapEntry(key, item as String));

String resolveLocalizedText(
  LocalizedText values,
  String requestedLocale, {
  String? defaultLocale,
}) {
  if (values.isEmpty) return '';
  final requested = _normalized(requestedLocale);
  final exact = values[_matchingKey(values, requested)];
  if (exact != null) return exact;

  final requestedLanguage = requested.split('-').first;
  for (final entry in values.entries) {
    if (_normalized(entry.key).split('-').first == requestedLanguage) {
      return entry.value;
    }
  }

  if (defaultLocale != null) {
    final fallback = _normalized(defaultLocale);
    final exactFallback = values[_matchingKey(values, fallback)];
    if (exactFallback != null) return exactFallback;
    final fallbackLanguage = fallback.split('-').first;
    for (final entry in values.entries) {
      if (_normalized(entry.key).split('-').first == fallbackLanguage) {
        return entry.value;
      }
    }
  }
  return values.values.first;
}

String? _matchingKey(LocalizedText values, String locale) {
  for (final key in values.keys) {
    if (_normalized(key) == locale) return key;
  }
  return null;
}

String _normalized(String locale) => locale.replaceAll('_', '-').toLowerCase();
