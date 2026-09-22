class ApiFailure implements Exception {
  const ApiFailure(this.code, [this.details = const {}]);
  final String code;

  /// Extra fields sent with the error (e.g. requiredSeconds/elapsedSeconds).
  final Map<String, dynamic> details;

  int? intDetail(String key) {
    final value = details[key];
    return value is int ? value : null;
  }

  @override
  String toString() => 'ApiFailure($code)';
}

class ApiResponseParser {
  static Object? parse(Object? body) {
    if (body is! Map<String, dynamic> || body['success'] is! bool) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    if (body['success'] == false) {
      throw ApiFailure(
        body['code'] is String ? body['code'] as String : 'UNKNOWN',
        body,
      );
    }
    if (!body.containsKey('data')) throw const ApiFailure('INVALID_RESPONSE');
    return body['data'];
  }
}
