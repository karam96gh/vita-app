import 'package:firebase_core/firebase_core.dart';

/// FlutterFire client configuration (not a service-account credential).
/// Supply the options for the native app's exact flavor/bundle ID at build time.
abstract final class FirebaseConfig {
  static FirebaseOptions? get options {
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (appId.isEmpty || apiKey.isEmpty || sender.isEmpty) return null;
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: sender,
      projectId: 'vita-xir',
      iosBundleId: String.fromEnvironment('IOS_BUNDLE_ID'),
    );
  }
}
