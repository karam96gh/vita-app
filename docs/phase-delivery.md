# Phase delivery ledger

This records the actual delivered files and remaining gates. A phase containing an external integration gate is not marked complete merely because its UI compiles.

| Phase | Principal files delivered | Verification and remaining work |
|---|---|---|
| 1 — foundation | `lib/main.dart`, `lib/app/app.dart`, `lib/app/providers.dart`, `lib/app/config/*`, `lib/app/localization/app_strings.dart`, `lib/app/theme/app_theme.dart`, `lib/shared/widgets/app_widgets.dart`, native Android/iOS scaffold | Analyzer and RTL/English widget tests pass. Android flavors build. Final branding and iOS flavor schemes pending |
| 2 — transport | `lib/core/network/api_client.dart`, `patient_contract.dart`, `lib/core/errors/api_failure.dart`, `lib/core/storage/token_store.dart` | Parser, concurrent refresh, logout race, terminal rejection and mutation replay tests pass. Expiry defaults follow the documented 900 seconds; real refresh response verification pending |
| 3 — auth | `lib/features/auth/presentation/auth_screen.dart`, auth controller in `lib/app/providers.dart` | Credential serialization and form validation tests pass. No real account integration test |
| 4 — home/profile/appointments | `lib/features/home/presentation/home_screen.dart`, `profile/presentation/profile_screen.dart`, `appointments/presentation/appointments_screen.dart`, `lib/core/utils/date_time_formatter.dart` | Typed appointment decoder implemented. Profile schema missing |
| 5 — care plan | `lib/features/sessions/presentation/sessions_screen.dart`, `exercises/presentation/exercises_screen.dart`, `progress/presentation/progress_screen.dart`, `lib/features/patient/{data,domain}/*` | Cancelled/skip rules tested. Session discovery, response mapping, action-state semantics and server timer recovery blocked by incomplete contract |
| 6 — chat | `lib/features/chat/presentation/chat_screen.dart`, `lib/core/services/polling_loop.dart`, `lib/app/router/route_observer.dart` | Serial polling/stop/resume scheduler tested. Message/identity/cursor schemas and real lifecycle integration still needed |
| 7 — rating | `lib/features/rating/presentation/rating_screen.dart` | Score/completion validation tested. Authoritative patient-visible eligibility and duplicate status remain backend requirements |
| 8 — notifications | `lib/core/services/notification_service.dart`, `lib/app/config/firebase_config.dart`, `lib/features/notifications/presentation/notifications_screen.dart`, native permissions/entitlements | Compiles for Android. Firebase options, item/push schema, logout device policy and physical-device testing pending |
| 9 — media/UX | `lib/features/exercises/presentation/media_view.dart`, shared components and centralized translations | Android builds; narrow-screen form test passes. Real media playback, screen-reader QA and timer UI pending integration data |
| 10 — release | `test/*`, Android signing/flavor config, `config/*.example.json`, README and release/status docs | 14 tests and analyzer pass; development APK and unsigned AAB build. End-to-end patient QA, production configuration/signing, iOS archive and store requirements remain open |

No phase is claimed end-to-end complete where its missing external input prevents verification.
