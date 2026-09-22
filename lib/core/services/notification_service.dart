import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../app/config/app_config.dart';
import '../../app/config/firebase_config.dart';
import '../../features/patient/data/patient_repository.dart';
import '../errors/api_failure.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfig.options);
  // OS handles notification display; the inbox is fetched after authentication.
}

class NotificationService {
  NotificationService({
    required this.repository,
    required this.onOpen,
    required this.onForeground,
  });
  final PatientRepository Function() repository;
  final void Function() onOpen, onForeground;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _ready = false, _authenticated = false;
  int _generation = 0;

  Future<void> initialize() async {
    if (!AppConfig.firebaseEnabled ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final app = await Firebase.initializeApp(options: FirebaseConfig.options);
      if (app.options.projectId != 'vita-xir') return;
      _ready = true;
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((_) {
          if (_authenticated) onForeground();
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpen()),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
          if (_authenticated) {
            try {
              await _register(token);
            } on Object {
              /* Retried on resume/permission action. */
            }
          }
        }),
      );
      if (await FirebaseMessaging.instance.getInitialMessage() != null) {
        onOpen();
      }
    } on Object {
      _ready = false;
    }
  }

  Future<void> setAuthenticated(bool value) async {
    _authenticated = value;
    _generation++;
    if (!value || !_ready) return;
    try {
      await enable(requestPermission: false);
    } on Object {
      /* Inbox remains available; explicit enable reports failures. */
    }
  }

  Future<void> enable({bool requestPermission = true}) async {
    if (!_ready || !_authenticated) throw const ApiFailure('PUSH_UNAVAILABLE');
    final generation = _generation;
    final settings = requestPermission
        ? await FirebaseMessaging.instance.requestPermission()
        : await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw const ApiFailure('PUSH_DENIED');
    }
    if (generation != _generation || !_authenticated) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) throw const ApiFailure('PUSH_UNAVAILABLE');
    if (generation == _generation && _authenticated) await _register(token);
  }

  Future<void> _register(String token) => repository().registerDevice(
    token,
    defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
  );

  Future<void> dispose() async {
    _authenticated = false;
    _generation++;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
