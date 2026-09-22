import 'package:flutter/foundation.dart';

enum Environment { development, staging, production }

class AppConfig {
  const AppConfig({required this.gateway, required this.environment});
  final String gateway;
  final Environment environment;
  static const brand = String.fromEnvironment('APP_NAME', defaultValue: 'Vita');
  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');

  factory AppConfig.fromEnvironment() => AppConfig(
    gateway: const String.fromEnvironment('GATEWAY_BASE_URL'),
    environment: Environment.values.byName(
      const String.fromEnvironment('ENVIRONMENT', defaultValue: 'development'),
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
