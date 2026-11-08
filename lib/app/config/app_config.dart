import 'package:flutter/foundation.dart';

enum Environment { development, staging, production }

class AppConfig {
  const AppConfig({required this.gateway, required this.environment});
  final String gateway;
  final Environment environment;
  static const brand = String.fromEnvironment('APP_NAME', defaultValue: 'Vita');
  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');

  factory AppConfig.fromEnvironment() => AppConfig(
    // Defaults are the production values, so a plain build needs no defines.
    // Local runs can still override them with --dart-define-from-file.
    gateway: const String.fromEnvironment(
      'GATEWAY_BASE_URL',
      defaultValue: 'https://system.vitaxirpro.com',
    ),
    environment: Environment.values.byName(
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'production'),
    ),
  );

  bool get isConfigured {
    final uri = Uri.tryParse(gateway);
    return uri != null &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/') &&
        (uri.scheme == 'https' ||
            (!kReleaseMode &&
                environment == Environment.development &&
                uri.scheme == 'http'));
  }

  String get apiUrl =>
      '${gateway.replaceFirst(RegExp(r'/$'), '')}/api/v1/patient-app';
}
