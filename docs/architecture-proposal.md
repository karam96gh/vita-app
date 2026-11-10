# Vita patient app — architecture and implementation proposal

Status: approved by the user's instruction to implement the app. See [implementation status](implementation-status.md) for code delivered and remaining integration requirements. The proposal below records the original design.

Source: `C:/Users/karam/Downloads/MASTER_PROMPT_FLUTTER_CODEX_WITH_API.md`, backend contract dated 2026-09-12. The contract is authoritative for wire fields and endpoint behavior. Its statements about deployment are supplied claims, not independently verified integration results.

## 1. Scope and workspace

Build an Arabic-first, RTL Flutter app for Android and iOS with English localization support. Use centralized, replaceable branding and Material 3 with primary `#1D2452` and accent `#FE8C31`.

The workspace was empty at inspection. Flutter and Dart executables are available under `C:/androidd/flutter/bin`; versions, SDK health, Android tooling, and compatibility still need verification. iOS builds and archives require a macOS environment with Xcode.

Patient features:

| Feature | Intended behavior | Contract readiness |
|---|---|---|
| Authentication | Register through ERP phone match, login, restore, refresh, logout | Requests and login response documented; refresh response details need confirmation |
| Home | Entry points and summaries from appointments and progress | No separate home endpoint; progress fields missing |
| Profile | Display account and ERP patient information | Response schema missing; no editing endpoint |
| Appointments | Upcoming/recent appointment list in local time | Array and fields documented |
| Sessions | Select a patient's session and open its exercises | Patient session discovery endpoint missing |
| Exercises | Instructions, media, execution state, start/complete/skip | Endpoint paths documented; patient response schemas missing |
| Progress | Active/completed/skipped/in-progress totals | Exact field names missing |
| Chat | Text conversation with assigned therapist, visible-screen polling | Requests documented; conversation/message schemas missing |
| Rating | One confidential score 1–5 after confirmed session attendance | Submission documented; patient completion/previous-submission eligibility unavailable |
| Notifications | Latest 100, mark read, push delivery | Item and push payload schemas missing; Firebase app configs needed |

No staff administration, therapist selection, pain rating, appointment mutations, historical rating screen, or media upload in the patient app.

## 2. Architecture

Use feature-first modules. Within each feature, presentation widgets call Riverpod controllers, controllers call repository interfaces, and repository implementations use the shared API client and typed DTOs. Keep parsing, HTTP, token storage, and business validation out of widgets. Introduce domain use cases only when logic spans repositories or merits isolated tests.

Repositories own remote data access; Riverpod providers own in-memory state and dependency injection. Do not persist patient records, chat text, or rating notes by default. Dispose account-scoped providers on logout/account changes.

```text
lib/
  main.dart
  app/
    app.dart
    bootstrap.dart
    config/app_config.dart
    router/app_router.dart
    theme/{app_colors,app_typography,app_spacing,app_radius,app_shadows,app_theme}.dart
    localization/{app_ar,app_en}.arb
  core/
    network/{api_client,auth_interceptor,api_response_parser,token_refresh_coordinator}.dart
    errors/{api_failure,api_error_mapper}.dart
    storage/token_store.dart
    services/{notification_service,lifecycle_service}.dart
    utils/{date_time_formatter,media_uri_resolver}.dart
  shared/
    widgets/{app_button,app_text_field,app_card,app_app_bar,app_dialog}.dart
    widgets/{app_bottom_sheet,app_loading,app_skeleton,app_empty_state,app_error_state,app_badge}.dart
    widgets/async_content.dart
  features/
    auth/{data,domain,presentation}/
    home/presentation/
    profile/{data,domain,presentation}/
    appointments/{data,domain,presentation}/
    sessions/{data,domain,presentation}/
    exercises/{data,domain,presentation}/
    progress/{data,domain,presentation}/
    chat/{data,domain,presentation}/
    rating/{data,domain,presentation}/
    notifications/{data,domain,presentation}/
test/
  core/{network,errors,utils}/
  features/{auth,exercises,chat,rating}/
integration_test/
config/{development,staging,production}.example.json
docs/{architecture-proposal,api-contract-gaps,release-readiness}.md
android/
ios/
```

This is a proposed tree; files listed here have not been generated.

## 3. Packages and rationale

Resolve compatible stable versions after checking the installed Flutter SDK and current stable release. Commit the application lockfile; do not guess or pin unverified versions in this proposal.

| Package | Purpose |
|---|---|
| `flutter_riverpod` | One state-management system, dependency injection, asynchronous state, disposal, test overrides |
| `dio` | Timeouts, interceptors, cancellation, shared transport |
| `go_router` | Declarative routes, authentication redirects, deep-link handling |
| `flutter_secure_storage` | Platform-backed storage of a single serialized token pair |
| `flutter_localizations` (SDK), `intl` | Generated Arabic/English strings, locale-aware UTC-to-local date display |
| `firebase_core`, `firebase_messaging` | Firebase initialization and push lifecycle |
| `video_player` | Network video playback and seek controls |
| `cached_network_image` | Educational image cache and error placeholders |
| `flutter_test`, `integration_test` (SDK), `flutter_lints` | Unit/widget/integration checks and analyzer rules |

Use handwritten immutable DTOs initially to keep tooling small. Add serialization generation only if confirmed schema volume justifies it. Test using repository fakes and a controlled Dio adapter; no runtime mock-data mode.

References checked during proposal preparation: [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations), [Flutter SDK archive](https://docs.flutter.dev/install/archive), [Riverpod AsyncNotifier API](https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/AsyncNotifierProvider-class.html), [go_router](https://pub.dev/packages/go_router), [Firebase Messaging](https://pub.dev/packages/firebase_messaging). Package selection is a design recommendation; compatibility is pending dependency resolution.

## 4. Models and DTOs limited to the supplied contract

Known wire shapes:

| DTO | Documented fields |
|---|---|
| API success envelope | `success`, `data`, `meta.timestamp` (examples omit meta, so tolerate absence) |
| API failure envelope | `success`, `code`, `message`, `details`, `timestamp`, `path` |
| Register request | `phone`, `username`, `password` |
| Login request | `username`, `password` |
| Refresh/logout request | `refreshToken` |
| Auth response | `account`, `accessToken`, `refreshToken`, `expiresIn` |
| Patient account | `id`, `erpPatientId`, `username`, `status` |
| Appointment | `id`, `appointmentType`, `startTime`, `endTime`, `status`, `physiotherapistId`, `practitionerId`, `notes` |
| Complete request | optional `completionNote` |
| Skip request | `skipReasonId`, `skipReasonText`, with presence rules enforced |
| Chat send request | `messageText` |
| Rating request | integer `score`, optional `privateNote` |
| Device request | `token`, `platform` (`ANDROID`, `IOS`, `WEB`; mobile uses the first two) |

The staff contract documents an ERP session shape (`id`, `caseId`, `sessionNumber`, `sessionDate`, `attendanceConfirmed`, `physiotherapistId`, `appointmentId`) and exercise/assignment write fields. These are useful evidence of domain concepts but do not establish a patient response shape or patient authorization. Do not reuse them as patient DTOs without confirmation.

Pending schemas: profile, patient sessions, assigned-exercise list and nested media, execution responses/latest execution state, skip-reason item including the semantic Other marker, progress counters, conversation, message including ID/time/sender, notification including read state, and push data payload. Do not invent JSON keys, arrays versus wrappers, nullability, enum members, pagination, or rating eligibility fields.

Use internal view models for presentation and internal session states for restoring/authenticated/unauthenticated; these are not backend fields. Treat unknown backend enum values safely instead of coercing them into a successful state.

## 5. Repositories

| Repository | Responsibility |
|---|---|
| AuthRepository | Register/login, token lifecycle, restore, logout |
| ProfileRepository | Read patient profile |
| AppointmentRepository | List appointments |
| SessionRepository | Patient session discovery, once a permitted source is confirmed |
| ExerciseRepository | Session exercises, skip reasons, start/complete/skip |
| ProgressRepository | Summary read |
| ChatRepository | Initial conversation, incremental messages, send, mark read |
| RatingRepository | Submit confidential rating; no history fetch |
| NotificationRepository | List/read notifications and register devices |

Home composes appointment/progress providers instead of introducing an invented API. NotificationService coordinates Firebase and NotificationRepository; media widgets consume resolved backend URLs.

## 6. State and routing

Use Riverpod `AsyncNotifier` for user-driven asynchronous features and family providers keyed by documented resource IDs. Shared async content renders initial/loading/success/empty/error with retry. Keep mutation state distinct from list loading so failed actions preserve displayed data. Disable duplicate submissions; refresh affected queries after acknowledged mutations.

Proposed routes: `/splash`, `/login`, `/register`, `/home`, `/profile`, `/appointments`, `/sessions`, `/sessions/:sessionId/exercises`, `/sessions/:sessionId/exercises/:assignmentId`, `/sessions/:sessionId/rating`, `/progress`, `/chat`, `/notifications`.

Router guards await secure session restoration before showing protected content. Logout clears navigation and account-scoped state. Validate route IDs, authenticate before resolving notification navigation, and fetch current resource authorization from the backend. A deep link must never itself establish rating eligibility. Session-related entry points remain blocked until patient session discovery is documented.

Arabic is the default locale. Use directional padding/alignment, SafeArea, constrained wide layouts, scrollable forms, accessible controls and semantics, text scaling, and localized user-facing errors. All UI copy resides in ARB resources. UTC parsing and local formatting are centralized.

## 7. API integration

All paths below are relative to `/api/v1/patient-app` on the configured gateway origin:

| Method | Paths |
|---|---|
| POST | `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout` |
| GET | `/me/profile`, `/me/appointments`, `/me/progress`, `/me/skip-reasons` |
| GET | `/me/sessions/:erpSessionId/exercises` |
| POST | `/me/exercises/:assignmentId/start`, `/me/exercises/:assignmentId/complete`, `/me/exercises/:assignmentId/skip` |
| GET | `/me/chat`, `/me/chat/messages?after=<ISO timestamp>` |
| POST | `/me/chat/messages`, `/me/chat/read` |
| POST | `/me/sessions/:erpSessionId/rating` |
| GET | `/me/notifications` |
| POST | `/me/notifications/:id/read`, `/me/devices` |

Base URL comes from environment configuration; never embed the example HTTP IP as a production default. Require HTTPS for production. Encode IDs as path segments and query values with Dio query parameters. Restrict authenticated API requests to the configured origin. Parse the success envelope before DTO decoding; handle malformed payloads as safe contract errors.

Map every listed backend error code to localized copy, including registration ambiguity, inactive accounts, invalid credentials, missing resources, cancelled assignments, skip validation, missing therapist, incomplete sessions, duplicate rating, and forbidden resources. Distinguish offline/timeouts from authentication failure. Do not log response bodies, credentials, tokens, chat text, rating notes, or patient information.

Use bounded timeouts and cancel obsolete reads. Do not automatically retry mutations on transport failures: the server may already have committed them. Authentication replay requires confirmation that rejected requests were not executed. No blind retry of login, refresh, logout, rating, or chat send.

## 8. Refresh concurrency and session safety

1. Store access/refresh tokens as one secure-storage record. Derive an in-memory expiry deadline from documented `expiresIn`; confirm refresh expiry metadata. Never treat client-decoded JWT data as authorization evidence.
2. Before authenticated traffic, refresh near expiry through a single shared future. While foregrounded, schedule refresh with a small expiry margin; cancel the timer in background and check immediately on resume.
3. Use a separate transport for refresh so the auth interceptor cannot recurse. All concurrent callers await the same refresh operation.
4. Associate requests with an auth generation and the access token used. If a late rejection used an older token and the generation is unchanged, use the current token without rotating again.
5. Persist the complete rotated pair before releasing waiting callers. Do not allow a stale refresh to overwrite a newer login or resurrect a logged-out account.
6. Bound a qualifying auth replay to one attempt. Confirm actual expired-token HTTP status/code semantics; never refresh on every error or on `403 FORBIDDEN`.
7. Terminal refresh rejection clears storage and triggers one logout transition. Transport uncertainty with rotating tokens is not blindly retried; expose a recoverable failure or require reauthentication if token state cannot be recovered safely.
8. Explicit logout cancels timers, polling and pending account work, attempts documented server revocation, and clears local session state even if the server is unavailable. Surface that server revocation could not be confirmed when applicable.

Test concurrent rejection bursts, late old-token failures, a failed rotation, storage failure, logout during refresh, and account switching.

## 9. Feature-specific behavior

Cancelled assignments stay visible in red with a textual status and disabled start/complete/skip. Other execution transitions and timer recovery need confirmed state/timestamp schemas. Skip reasons come from the server; require the selected reason and, when its confirmed semantic marker means Other, nonblank free text. Do not infer Other from display-label translations.

Chat polls every four seconds only while the route is visible and the app is resumed. Use an injectable scheduler and lifecycle source. Schedule the next poll after completion to avoid overlap; cancel on route cover, navigation, background, disposal and logout. Merge messages by confirmed IDs and advance the cursor using confirmed server timestamps, never device time. Confirm equal-timestamp behavior and conversation-switch semantics. Refetch the active conversation on resume; prevent old in-flight responses from crossing conversation or auth generations. Mark read only for the visible active conversation. Explain `NO_RESPONSIBLE_THERAPIST` in Arabic.

Rating requires authoritative `attendanceConfirmed` from a permitted patient source. Hide submission until eligibility is established. After success disable further submission in the current session; handle `RATING_ALREADY_EXISTS` safely after restart. A backend eligibility indication is needed to prevent showing already-submitted actions across devices without exposing private rating history. Display the exact confidentiality notice from the specification.

Resolve relative `mediaUrl` against the gateway origin, leaving permitted absolute media URLs intact. Send no patient bearer token to educational media or external hosts. Stream video with loading/error/retry, playback, pause and seek; pause when covered or backgrounded and dispose controllers. Cache only educational images, with placeholders. Treat invalid or missing media as unavailable.

## 10. Firebase and environments

Use the supplied Firebase project `vita-app-f54b5`. Obtain registered Android/iOS client configuration for the final application/bundle IDs. Configure native Firebase files or generated FlutterFire options per flavor; verify the selected project during setup. Do not fabricate Firebase keys or app identifiers.

Initialize Firebase during bootstrap, register a top-level background handler, request notification permission contextually after login, fetch/register the device token, and subscribe to token rotation. Re-register after authenticated session restoration when permission is already granted. Track registration failure and retry on safe lifecycle events. Foreground delivery shows an in-app notification and refreshes the inbox. Background handlers must not access widget context or log payloads.

Handle both notification-open streams and terminated-launch messages. Queue navigation until authentication/router initialization is complete. Until a payload schema exists, open the inbox; do not invent resource identifiers or trust arbitrary routes from data. Define logout device unregistration/reassignment with the backend before release because the supplied contract has registration only.

Configure development, staging and production using build-time configuration files and native flavors/schemes, with per-environment gateway, Firebase client configuration, app-name suffix, identifiers and diagnostics policy. Fail early on missing configuration. Keep secrets, signing credentials and private environment files out of source control. No backend requests with real credentials are needed for architecture preparation.

## 11. Contract gaps and release dependencies

See `api-contract-gaps.md` for the actionable handoff. The most significant blocker is patient session discovery: the only session-list endpoint is explicitly staff-authorized. Appointment `id` must not be substituted for ERP session ID. Completing the full definition of done requires these gaps to be resolved, representative sanitized responses, an authorized test environment/account, Firebase client setup, signing inputs and iOS build access.

## 12. Phased execution and verification

The source requests a proposal approval before features. After approval, complete each phase, report created/changed files, checks and open issues, and fix known failures before proceeding.

| Phase | Deliverable | Verification / exit conditions |
|---|---|---|
| 1 | SDK check, Android/iOS scaffold, Riverpod, theme/components, ARB localization, router, environment/flavor setup | Analyze; RTL, text-scaling and route smoke tests; dependency resolution recorded |
| 2 | Dio transport/parser/error mapper, secure store, interceptor, refresh coordinator | Envelope/error tests; refresh concurrency, storage and generation-race tests |
| 3 | Register/login/restore/logout screens and guards | Form tests; restore, expired/invalid session, logout tests; authorized staging auth smoke |
| 4 | Home/profile/appointments | Confirm profile/progress payloads; empty/error/retry and UTC rendering tests |
| 5 | Sessions/exercises/actions/progress | Resolve session and execution schemas; cancelled/skip/transition tests; staging action checks |
| 6 | Chat | Confirm message schemas/cursor; lifecycle, overlap, deduplication and conversation-switch tests |
| 7 | Confidential rating | Resolve eligibility; range, submission, duplicate and incomplete-session tests |
| 8 | Inbox and FCM | Confirm notification schemas/config; physical-device foreground/background/terminated tests; logout token behavior |
| 9 | Media and UX/accessibility polish | Media lifecycle/errors, long Arabic strings, large fonts, slow/offline network, physical-device review |
| 10 | Release verification and handoff | Format/analyze/test/AAB; signed Android setup; iOS archive on macOS; store checklist and unresolved issues recorded |

Required final commands: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `flutter build appbundle --release` with required environment/flavor/signing arguments. Run integration tests against an authorized nonproduction setup. No tests or release builds have been run at the proposal stage; no app exists yet.
