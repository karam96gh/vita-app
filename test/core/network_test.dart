import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vita_patient/core/network/api_client.dart';
import 'package:vita_patient/core/errors/api_failure.dart';
import 'package:vita_patient/core/storage/token_store.dart';

class MemoryTokens implements TokenStore {
  TokenPair? pair;
  int writes = 0, clears = 0;
  @override
  Future<TokenPair?> read() async => pair;
  @override
  Future<void> write(TokenPair value) async {
    pair = value;
    writes++;
  }

  @override
  Future<void> clear() async {
    pair = null;
    clears++;
  }
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody success(Object? data) => ResponseBody.fromString(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
ResponseBody rejected(String code) => ResponseBody.fromString(
  jsonEncode({'success': false, 'code': code}),
  401,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
TokenPair pair({bool expired = false}) => TokenPair(
  'old-access',
  'old-refresh',
  DateTime.now().toUtc().add(Duration(minutes: expired ? -1 : 15)),
);
final rotated = {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'expiresIn': 900,
};

void main() {
  test(
    'success parser rejects malformed envelopes and preserves error code',
    () {
      expect(ApiResponseParser.parse({'success': true, 'data': []}), isEmpty);
      expect(
        () => ApiResponseParser.parse({'data': []}),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => ApiResponseParser.parse({'success': false, 'code': 'FORBIDDEN'}),
        throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'FORBIDDEN')),
      );
    },
  );
  test(
    'concurrent expired reads rotate once and release only after storing pair',
    () async {
      final store = MemoryTokens()..pair = pair(expired: true);
      final gate = Completer<void>();
      var refreshes = 0;
      final dio = Dio(
        BaseOptions(baseUrl: 'https://clinic.test/api/v1/patient-app'),
      );
      dio.httpClientAdapter = TestAdapter((request) async {
        if (request.path == '/auth/refresh') {
          refreshes++;
          await gate.future;
          return success(rotated);
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        expect(store.pair!.refreshToken, 'new-refresh');
        expect(request.uri.path, '/api/v1/patient-app/me/profile');
        return success({'ok': true});
      });
      final api = ApiClient(baseUrl: '', store: store, transport: dio)
        ..tokens = store.pair;
      final requests = List.generate(12, (_) => api.get('/me/profile'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      gate.complete();
      await Future.wait(requests);
      expect(refreshes, 1);
      expect(store.writes, 1);
    },
  );
  test('logout during refresh cannot resurrect the session', () async {
    final store = MemoryTokens()..pair = pair();
    final gate = Completer<void>();
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((request) async {
      await gate.future;
      return success(rotated);
    });
    final api = ApiClient(baseUrl: '', store: store, transport: dio)
      ..tokens = store.pair;
    final refresh = api.refresh();
    final assertion = expectLater(refresh, throwsA(isA<ApiFailure>()));
    await api.clearSession();
    gate.complete();
    await assertion;
    expect(api.tokens, isNull);
    expect(store.pair, isNull);
    expect(store.writes, 0);
  });
  test('refresh rejection logs out concurrent waiters exactly once', () async {
    final store = MemoryTokens()..pair = pair();
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter(
      (_) async => rejected('AUTH_TOKEN_INVALID'),
    );
    final api = ApiClient(baseUrl: '', store: store, transport: dio)
      ..tokens = store.pair;
    var expired = 0;
    api.onExpired = () => expired++;
    await Future.wait(
      List.generate(
        8,
        (_) => expectLater(api.refresh(), throwsA(isA<ApiFailure>())),
      ),
    );
    expect(expired, 1);
    expect(store.clears, 1);
    expect(api.tokens, isNull);
  });
  test(
    'a mutation is not automatically replayed after authentication failure',
    () async {
      final store = MemoryTokens()..pair = pair();
      final dio = Dio();
      var mutations = 0;
      dio.httpClientAdapter = TestAdapter((request) async {
        if (request.path == '/auth/refresh') return success(rotated);
        mutations++;
        return rejected('AUTH_TOKEN_INVALID');
      });
      final api = ApiClient(baseUrl: '', store: store, transport: dio)
        ..tokens = store.pair;
      await expectLater(
        api.post('/me/chat/messages', body: {'messageText': 'test'}),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'RETRY_ACTION'),
        ),
      );
      expect(mutations, 1);
    },
  );
  test(
    'login sends only patient credentials and saves rotated tokens',
    () async {
      final store = MemoryTokens();
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter((request) async {
        expect(request.path, '/auth/login');
        expect(request.headers['Authorization'], isNull);
        expect(request.data, {'username': 'patient', 'password': 'secret'});
        return success(rotated);
      });
      final api = ApiClient(baseUrl: '', store: store, transport: dio);
      await api.authenticate('login', {
        'username': 'patient',
        'password': 'secret',
      });
      expect(store.pair!.accessToken, 'new-access');
    },
  );
}
