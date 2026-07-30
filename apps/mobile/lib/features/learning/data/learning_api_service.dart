import '../../../core/network/api_client.dart';
import '../../../core/network/api_problem.dart';

class LearningApiService {
  LearningApiService(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
  }) => _api.get(path, query: query, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    bool authenticated = false,
    String? idempotencyKey,
  }) => _api.post(
    path,
    body: body,
    authenticated: authenticated,
    idempotencyKey: idempotencyKey,
  );
}

typedef LearningApiException = ApiProblem;
