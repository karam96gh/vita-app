class ApiFailure implements Exception {
  const ApiFailure(this.code);
  final String code;
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
      );
    }
    if (!body.containsKey('data')) throw const ApiFailure('INVALID_RESPONSE');
    return body['data'];
  }
}
