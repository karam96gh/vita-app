import 'dart:async';
import 'package:dio/dio.dart';
import '../errors/api_failure.dart';
import '../storage/token_store.dart';

class TokenRefreshCoordinator {
  Future<void>? _pending;
  Future<void> run(Future<void> Function() action) => _pending ??=
      Future<void>.sync(action).whenComplete(() => _pending = null);
}

class ApiClient {
  ApiClient({required String baseUrl, required this.store, Dio? transport})
    : dio =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              followRedirects: false,
            ),
          );
  final Dio dio;
  final TokenStore store;
  final _refresh = TokenRefreshCoordinator();
  TokenPair? tokens;
  int _generation = 0;
  Future<void> _storageQueue = Future.value();
  void Function()? onExpired;

  Future<void> _serializeStorage(Future<void> Function() operation) {
    final next = _storageQueue.then((_) => operation());
    _storageQueue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<bool> restore() async {
    final generation = _generation;
    final saved = await store.read();
    if (generation != _generation) return false;
    tokens = saved;
    if (saved == null) return false;
    if (saved.needsRefresh) await refresh();
    return tokens != null;
  }

  Future<void> authenticate(String action, Map<String, dynamic> body) async {
    final generation = ++_generation;
    final data = await _request('POST', '/auth/$action', body: body);
    final pair = TokenPair.fromApi(data);
    await _serializeStorage(() async {
      if (generation != _generation) throw const ApiFailure('SESSION_CHANGED');
      await store.write(pair);
      if (generation == _generation) tokens = pair;
    });
  }

  Future<void> refresh() => _refresh.run(() async {
    final previous = tokens;
    final generation = _generation;
    if (previous == null) throw const ApiFailure('AUTH_TOKEN_INVALID');
    try {
      final result = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': previous.refreshToken},
      );
      final pair = TokenPair.fromApi(result);
      await _serializeStorage(() async {
        if (generation != _generation) {
          throw const ApiFailure('SESSION_CHANGED');
        }
        await store.write(pair);
        if (generation == _generation) tokens = pair;
      });
    } on Object {
      // Rotation may have committed even when its response was lost. Never replay
      // the old refresh token; require a fresh login and invalidate exactly once.
      if (generation == _generation) await clearSession();
      rethrow;
    }
  });

  Future<void> clearSession() async {
    _generation++;
    tokens = null;
    onExpired?.call();
    await _serializeStorage(store.clear);
  }

  Future<void> logout() async {
    final old = tokens;
    await clearSession();
    if (old != null) {
      await _request(
        'POST',
        '/auth/logout',
        body: {'refreshToken': old.refreshToken},
        bearer: old.accessToken,
      );
    }
  }

  Future<Object?> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) => request('GET', path, query: query, cancelToken: cancelToken);
  Future<Object?> post(String path, {Map<String, dynamic>? body}) =>
      request('POST', path, body: body);

  Future<Object?> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final generation = _generation;
    if (tokens == null) throw const ApiFailure('AUTH_TOKEN_INVALID');
    if (tokens!.needsRefresh) await refresh();
    if (generation != _generation || tokens == null) {
      throw const ApiFailure('SESSION_CHANGED');
    }
    final bearer = tokens!.accessToken;
    try {
      final result = await _request(
        method,
        path,
        body: body,
        query: query,
        bearer: bearer,
        cancelToken: cancelToken,
      );
      if (generation != _generation) throw const ApiFailure('SESSION_CHANGED');
      return result;
    } on ApiFailure catch (error) {
      if (error.code != 'AUTH_TOKEN_INVALID' || generation != _generation) {
        rethrow;
      }
      if (tokens?.accessToken == bearer) await refresh();
      if (generation != _generation || tokens == null) {
        throw const ApiFailure('SESSION_CHANGED');
      }
      // Only reads are replayed: mutation rejection atomicity is undocumented.
      if (method != 'GET') throw const ApiFailure('RETRY_ACTION');
      final result = await _request(
        method,
        path,
        query: query,
        bearer: tokens!.accessToken,
        cancelToken: cancelToken,
      );
      if (generation != _generation) throw const ApiFailure('SESSION_CHANGED');
      return result;
    }
  }

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? bearer,
    CancelToken? cancelToken,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://')) {
      throw const ApiFailure('INVALID_REQUEST');
    }
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'},
        ),
      );
      return ApiResponseParser.parse(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['code'] is String) {
        throw ApiFailure(data['code'] as String);
      }
      throw ApiFailure(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => 'TIMEOUT',
        DioExceptionType.cancel => 'CANCELLED',
        DioExceptionType.connectionError => 'OFFLINE',
        _ => 'NETWORK_ERROR',
      });
    }
  }

  void dispose() => dio.close(force: true);
}
