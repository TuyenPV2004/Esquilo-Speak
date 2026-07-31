import 'app_localizations.dart';

String localizedSupportStatus(AppLocalizations strings, String status) =>
    switch (status) {
      'open' => strings.statusOpen,
      'triaged' => strings.statusTriaged,
      'resolved' => strings.statusResolved,
      'dismissed' => strings.statusDismissed,
      _ => strings.statusUnknown,
    };

String localizedPrivacyState(AppLocalizations strings, String state) =>
    switch (state) {
      'requested' => strings.stateRequested,
      'processing' => strings.stateProcessing,
      'completed' => strings.stateCompleted,
      'failed' => strings.stateFailed,
      _ => strings.statusUnknown,
    };
