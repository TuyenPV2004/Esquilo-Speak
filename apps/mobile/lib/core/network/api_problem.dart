import 'package:flutter/foundation.dart';

@immutable
class ApiProblem implements Exception {
  const ApiProblem({
    required this.status,
    required this.code,
    required this.message,
    required this.retryable,
    this.traceId,
  });

  factory ApiProblem.fromJson(
    Map<String, dynamic> json, {
    required int status,
    String? traceId,
  }) => ApiProblem(
    status: status,
    code: json['code'] as String? ?? 'HTTP_$status',
    message:
        json['detail'] as String? ??
        json['title'] as String? ??
        'The service is unavailable.',
    traceId: json['traceId'] as String? ?? traceId,
    retryable: json['retryable'] as bool? ?? _retryableStatus(status),
  );

  final int status;
  final String code;
  final String message;
  final String? traceId;
  final bool retryable;

  static bool _retryableStatus(int status) =>
      status == 408 ||
      status == 429 ||
      status == 500 ||
      status == 502 ||
      status == 503 ||
      status == 504;

  @override
  String toString() => message;
}

class NetworkUnavailable implements Exception {
  const NetworkUnavailable();

  @override
  String toString() => 'The network is unavailable. Please try again.';
}
