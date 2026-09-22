import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/patient_contract.dart';
import '../core/storage/token_store.dart';
import '../features/patient/data/patient_repository.dart';
import '../features/patient/domain/models.dart';
import 'config/app_config.dart';

final configProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
final apiProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(configProvider);
  final api = ApiClient(
    baseUrl: config.apiUrl,
    store: const SecureTokenStore(),
  );
  ref.onDispose(api.dispose);
  return api;
});

enum AuthStatus { restoring, signedOut, signedIn }

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final api = ref.read(apiProvider);
    api.onExpired = () {
      state = AuthStatus.signedOut;
    };
    ref.onDispose(() => api.onExpired = null);
    return AuthStatus.restoring;
  }

  Future<void> restore() async {
    if (!ref.read(configProvider).isConfigured) {
      state = AuthStatus.signedOut;
      return;
    }
    try {
      state = await ref.read(apiProvider).restore()
          ? AuthStatus.signedIn
          : AuthStatus.signedOut;
    } on Object {
      state = AuthStatus.signedOut;
    }
  }

  Future<void> submit({
    required bool register,
    required String username,
    required String password,
    String? phone,
  }) async {
    await ref.read(apiProvider).authenticate(register ? 'register' : 'login', {
      'username': username.trim(),
      'password': password,
      if (register) 'phone': phone!.trim(),
    });
    state = AuthStatus.signedIn;
  }

  Future<void> logout() async {
    try {
      await ref.read(apiProvider).logout();
    } finally {
      state = AuthStatus.signedOut;
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');
  void toggle() => state = Locale(state.languageCode == 'ar' ? 'en' : 'ar');
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
final repositoryProvider = Provider<PatientRepository>((ref) {
  ref.watch(authProvider);
  return PatientRepository(
    ref.watch(apiProvider),
    PatientContract.fromEnvironment(),
  );
});
final appointmentsProvider = FutureProvider.autoDispose<List<Appointment>>(
  (ref) => ref.watch(repositoryProvider).appointments(),
);
final profileProvider = FutureProvider.autoDispose<PatientProfile>(
  (ref) => ref.watch(repositoryProvider).profile(),
);
final sessionsProvider = FutureProvider.autoDispose<List<PatientSession>>(
  (ref) => ref.watch(repositoryProvider).sessions(),
);
final progressProvider = FutureProvider.autoDispose<ProgressSummary>(
  (ref) => ref.watch(repositoryProvider).progress(),
);
final exercisesProvider = FutureProvider.autoDispose
    .family<List<AssignedExercise>, String>(
      (ref, session) => ref.watch(repositoryProvider).exercises(session),
    );
final programProvider = FutureProvider.autoDispose<List<AssignedExercise>>(
  (ref) => ref.watch(repositoryProvider).program(),
);

/// Latest therapist-authored message for the Today preview; null when none.
final therapistMessageProvider = FutureProvider.autoDispose<ChatMessage?>((
  ref,
) async {
  final conversation = await ref.watch(repositoryProvider).conversation();
  final received = conversation.messages.where((message) => !message.mine);
  if (received.isEmpty) return null;
  return received.reduce((a, b) => a.at.isAfter(b.at) ? a : b);
});
final skipReasonsProvider = FutureProvider.autoDispose<List<SkipReason>>(
  (ref) => ref.watch(repositoryProvider).skipReasons(),
);
final notificationsProvider =
    FutureProvider.autoDispose<List<PatientNotification>>(
      (ref) => ref.watch(repositoryProvider).notifications(),
    );
