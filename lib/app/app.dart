import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/notification_service.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/appointments/presentation/appointments_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/exercises/presentation/exercise_player_screen.dart';
import '../features/exercises/presentation/exercises_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/patient/domain/models.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/program/presentation/exercise_detail_screen.dart';
import '../features/program/presentation/program_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/rating/presentation/rating_screen.dart';
import '../features/sessions/presentation/sessions_screen.dart';
import '../shared/widgets/app_widgets.dart';
import 'config/app_config.dart';
import 'localization/app_strings.dart';
import 'providers.dart';
import 'router/route_observer.dart';
import 'theme/app_theme.dart';

class VitaApp extends ConsumerStatefulWidget {
  const VitaApp({super.key});
  @override
  ConsumerState<VitaApp> createState() => _VitaAppState();
}

class _VitaAppState extends ConsumerState<VitaApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final NotificationService _notifications;
  late final ProviderSubscription<AuthStatus> _authListener;
  final _routerRefresh = ValueNotifier<int>(0);
  Timer? _refreshTimer;
  bool _pendingNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifications = NotificationService(
      repository: () => ref.read(repositoryProvider),
      onOpen: () {
        if (!mounted) return;
        if (ref.read(authProvider) == AuthStatus.signedIn) {
          _router.push('/notifications');
        } else {
          _pendingNotification = true;
        }
      },
      onForeground: () {
        if (mounted) ref.invalidate(notificationsProvider);
      },
    );
    _router = GoRouter(
      initialLocation: '/splash',
      observers: [appRouteObserver],
      refreshListenable: _routerRefresh,
      redirect: (context, state) {
        final auth = ref.read(authProvider);
        final path = state.uri.path;
        if (auth == AuthStatus.restoring) {
          return path == '/splash' ? null : '/splash';
        }
        final public = path == '/login' || path == '/register';
        if (auth == AuthStatus.signedOut) return public ? null : '/login';
        if (public || path == '/splash') return '/home';
        return null;
      },
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => _router.go('/home'),
            child: Text(context.t('home')),
          ),
        ),
      ),
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => const Scaffold(body: Center(child: AppLoading())),
        ),
        GoRoute(path: '/login', builder: (_, _) => const AuthScreen()),
        GoRoute(
          path: '/register',
          builder: (_, _) => const AuthScreen(register: true),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) =>
              const _MainNavigation(index: 0, child: HomeScreen()),
        ),
        GoRoute(
          path: '/program',
          builder: (_, _) =>
              const _MainNavigation(index: 1, child: ProgramScreen()),
        ),
        GoRoute(
          path: '/progress',
          builder: (_, _) =>
              const _MainNavigation(index: 2, child: ProgressScreen()),
        ),
        GoRoute(
          path: '/chat',
          builder: (_, _) =>
              const _MainNavigation(index: 3, child: ChatScreen()),
        ),
        GoRoute(
          path: '/program/:id',
          builder: (_, state) => ExerciseDetailScreen(
            id: state.pathParameters['id']!,
            initial: state.extra is AssignedExercise
                ? state.extra! as AssignedExercise
                : null,
          ),
        ),
        GoRoute(
          path: '/play',
          builder: (_, state) => ExercisePlayerScreen(
            startId: state.uri.queryParameters['start'],
            sessionId: state.uri.queryParameters['session'],
          ),
        ),
        GoRoute(
          path: '/appointments',
          builder: (_, _) => const AppointmentsScreen(),
        ),
        GoRoute(path: '/sessions', builder: (_, _) => const SessionsScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/notifications',
          builder: (_, _) =>
              NotificationsScreen(enablePush: _notifications.enable),
        ),
        GoRoute(
          path: '/sessions/:id/exercises',
          builder: (_, state) =>
              ExercisesScreen(sessionId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/sessions/:id/rating',
          builder: (_, state) =>
              RatingScreen(sessionId: state.pathParameters['id']!),
        ),
      ],
    );
    _authListener = ref.listenManual(authProvider, (previous, next) {
      _routerRefresh.value++;
      _notifications.setAuthenticated(next == AuthStatus.signedIn);
      _scheduleRefresh();
      if (next == AuthStatus.signedIn && _pendingNotification) {
        _pendingNotification = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _router.push('/notifications');
        });
      }
    });
    Future.microtask(() async {
      await ref.read(authProvider.notifier).restore();
      await _notifications.initialize();
      if (mounted) {
        await _notifications.setAuthenticated(
          ref.read(authProvider) == AuthStatus.signedIn,
        );
      }
    });
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (ref.read(authProvider) != AuthStatus.signedIn) return;
    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final tokens = ref.read(apiProvider).tokens;
    if (tokens == null) return;
    final remaining = tokens.expiresAt
        .subtract(const Duration(seconds: 60))
        .difference(DateTime.now().toUtc());
    _refreshTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () async {
        try {
          await ref.read(apiProvider).refresh();
        } on Object {
          /* Auth state invalidation routes to login. */
        }
        if (mounted) _scheduleRefresh();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _refreshTimer?.cancel();
      return;
    }
    _scheduleRefresh();
    if (ref.read(authProvider) == AuthStatus.signedIn) {
      ref.invalidate(appointmentsProvider);
      ref.invalidate(sessionsProvider);
      ref.invalidate(programProvider);
      ref.invalidate(dailyProvider);
      _notifications.setAuthenticated(true);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authListener.close();
    _notifications.dispose();
    _router.dispose();
    _routerRefresh.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConfig.brand,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: ref.watch(localeProvider),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router,
  );
}

class _MainNavigation extends StatelessWidget {
  const _MainNavigation({required this.index, required this.child});
  final int index;
  final Widget child;
  static const _tabs = [
    ('/home', 'today', Icons.today_outlined, Icons.today_rounded),
    (
      '/program',
      'program',
      Icons.self_improvement_outlined,
      Icons.self_improvement_rounded,
    ),
    ('/progress', 'progress', Icons.insights_outlined, Icons.insights_rounded),
    ('/chat', 'messages', Icons.forum_outlined, Icons.forum_rounded),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => context.go(_tabs[value].$1),
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.$3),
            selectedIcon: Icon(tab.$4),
            label: context.t(tab.$2),
          ),
      ],
    ),
  );
}
