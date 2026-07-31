import '../core/network/user_facing_failure.dart';
import 'app_localizations.dart';

extension UserFacingFailureLocalization on UserFacingFailure {
  String localized(AppLocalizations strings) => switch (this) {
    UserFacingFailure.offline => strings.errorOffline,
    UserFacingFailure.authenticationRequired => strings.errorAuthentication,
    UserFacingFailure.onboardingRequired => strings.errorOnboarding,
    UserFacingFailure.conflict => strings.errorConflict,
    UserFacingFailure.unavailable => strings.errorUnavailable,
    UserFacingFailure.unexpected => strings.errorUnexpected,
  };
}
