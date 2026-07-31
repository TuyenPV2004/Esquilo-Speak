import 'api_problem.dart';

enum UserFacingFailure {
  offline,
  authenticationRequired,
  onboardingRequired,
  conflict,
  unavailable,
  unexpected,
}

UserFacingFailure mapUserFacingFailure(Object error) {
  if (error is NetworkUnavailable) return UserFacingFailure.offline;
  if (error is! ApiProblem) return UserFacingFailure.unexpected;
  if (error.status == 401) return UserFacingFailure.authenticationRequired;
  if (error.code == 'ONBOARDING_REQUIRED') {
    return UserFacingFailure.onboardingRequired;
  }
  if (error.status == 409) return UserFacingFailure.conflict;
  if (error.retryable || error.status >= 500) {
    return UserFacingFailure.unavailable;
  }
  return UserFacingFailure.unexpected;
}
