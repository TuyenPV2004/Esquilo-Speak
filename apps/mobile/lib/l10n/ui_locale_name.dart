import 'package:flutter/material.dart';

import 'app_localizations.dart';

class UiLocaleName extends StatelessWidget {
  const UiLocaleName(this.locale, {super.key});

  final Locale locale;

  @override
  Widget build(BuildContext context) => FutureBuilder<AppLocalizations>(
    future: AppLocalizations.delegate.load(locale),
    builder: (context, snapshot) => Text(
      snapshot.data?.interfaceLanguageSelfName ?? locale.toLanguageTag(),
    ),
  );
}
