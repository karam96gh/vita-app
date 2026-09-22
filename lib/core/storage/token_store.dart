import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../errors/api_failure.dart';

class TokenPair {
  const TokenPair(this.accessToken, this.refreshToken, this.expiresAt);
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  factory TokenPair.fromApi(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['accessToken'] is! String ||
        value['refreshToken'] is! String ||
        (value['accessToken'] as String).isEmpty ||
        (value['refreshToken'] as String).isEmpty) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    final expiry = value['expiresIn'];
    if (expiry != null && (expiry is! num || expiry <= 0)) {
      throw const ApiFailure('INVALID_RESPONSE');
    }
    return TokenPair(
      value['accessToken'] as String,
      value['refreshToken'] as String,
      DateTime.now().toUtc().add(
        Duration(seconds: (expiry as num? ?? 900).toInt()),
      ),
    );
  }

  bool get needsRefresh => !DateTime.now().toUtc().isBefore(
    expiresAt.subtract(const Duration(seconds: 60)),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

abstract interface class TokenStore {
  Future<TokenPair?> read();
  Future<void> write(TokenPair pair);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'vita.patient.session.v1';

  @override
  Future<TokenPair?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TokenPair(
        json['accessToken'] as String,
        json['refreshToken'] as String,
        DateTime.parse(json['expiresAt'] as String).toUtc(),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(TokenPair pair) =>
      _storage.write(key: _key, value: jsonEncode(pair.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
