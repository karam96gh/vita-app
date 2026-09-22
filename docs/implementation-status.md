# Implementation status

The user approved feature implementation after the architecture proposal. This report supersedes the proposal's statement that no app exists.

## Implemented in source

- Android and iOS Flutter projects; Material 3 navy/orange design system; Arabic RTL and English localization.
- Responsive sign-in/registration forms, secure token storage, session restoration, protected navigation and logout.
- Dio transport, strict response-envelope parsing, localized errors, serialized token rotation and storage, generation checks to prevent stale session resurrection. Mutations are not silently replayed.
- Home and typed appointments integration with local-time display.
- Profile, progress and bilingual notification inbox decode confirmed server fields directly. Sessions, exercises, chat and rating screens/repository methods are implemented, with remaining unknown response shapes gated by the contract adapter described below.
- Cancelled exercise action blocking, server-provided skip reasons, Other validation, completion note and confidential rating validation.
- Serial foreground/visible-route chat polling, message merging, conversation reconciliation and read acknowledgements.
- Image caching and streamed video with play/pause, seek, errors, and route/app lifecycle pause.
- FCM initialization, permission, token registration/rotation, inbox refresh, background handler and notification-open handling. Notification taps open the inbox because resource payloads are not documented.
- Android environment flavors, vector/adaptive app and notification icons, Internet/notification permissions, disabled backups and unsigned release configuration until owner signing is supplied.
- iOS entitlement and background-notification declarations. Native iOS flavor schemes and archive verification still require completion on macOS.

No patient data, login bypass, or mock backend is included in application code. Synthetic data exists only in tests.

## Integration limitation — read before testing

Auth, appointments, profile, sessions, progress and notification inbox wire shapes now decode directly. Profile/progress/inbox decoders were added from authenticated field/type observations on 2026-09-16; see [confirmed responses](confirmed-patient-responses.md). Other screens have their UI/actions implemented but still need confirmed response mappings. This is not a claim of completed end-to-end integration.

`PatientContract` consumes a build-time `PATIENT_SCHEMA` JSON string mapping internal model properties to JSON pointers relative to the decoded `data` object (or to individual list items for item fields). An empty pointer means the complete current object. No default field guesses are provided. Required unmapped properties raise `CONTRACT_REQUIRED` and display a localized service-unavailable state.

The mapping is an explicit integration boundary, not a proposed backend schema. If the real backend requires domain transformations rather than field extraction, replace that specific adapter with a typed decoder after obtaining the schema. Do not ask the backend to add internal model field names just to satisfy this implementation.

Required internal properties by feature:

| Feature | Mapping properties |
|---|---|
| Profile | No mapping required; typed ERP patient decoder |
| Sessions | No mapping required; typed `/me/sessions` decoder (backend handoff 2026-09-17) |
| Exercises | Display uses typed nested response with no mapping; action permissions still require confirmed `exercise.canStart`, `exercise.canComplete`, `exercise.canSkip` mappings |
| Skip | `skipReasons.items`, `skipReason.id`, `skipReason.label`, `skipReason.isOther` |
| Progress | No mapping required; typed assignment counters |
| Chat | `conversation.id`, `messages.items`, `message.id`, `message.text`, `message.at`, `message.mine` |
| Notifications | No mapping required; bilingual inbox and readAt decoder |

Sessions now use the patient-authorized `GET /me/sessions` endpoint and pass each returned `id` to the exercises endpoint. Rating history remains unknown. The staff session endpoint is never called. Appointment IDs are never substituted for session IDs.

Exercise action permissions, Other identification and message ownership require confirmed booleans or typed semantic conversion from documented states. These booleans are internal requirements, not documented server fields. Timer recovery remains pending documented execution start/duration/state semantics; the UI does not fabricate elapsed time.

## Required external inputs

1. HTTPS gateway and sanitized response schemas for the items in `api-contract-gaps.md`.
2. Rating eligibility, plus execution-state/timer semantics.
3. Authorized nonproduction account and test fixtures for real integration QA.
4. Firebase `vita-xir` client options for the final Android/iOS IDs; APNs setup and physical-device push verification.
5. Device deregistration/account-switch policy from the backend, and account deletion workflow.
6. Final signing credentials, iOS/macOS build environment, final iOS icon assets and store/legal content.

## Verification

Verified on 2026-09-14:

- `flutter analyze`: passed with no issues.
- `flutter test`: all 14 tests passed, including registration validation at 320px width and 1.6x text scaling, auth concurrency, logout race, parsing, skip/rating/cancelled validation, polling stop/serialization and localization.
- `dart format --set-exit-if-changed .`: passed; the subsequently corrected test was formatted again before handoff.
- `flutter build apk --debug --flavor development --dart-define-from-file=config/development.example.json`: passed. Installable development APK at `build/app/outputs/flutter-apk/app-development-debug.apk` (about 155 MiB).
- `flutter build appbundle --release --flavor production --dart-define-from-file=config/production.example.json`: passed. AAB at `build/app/outputs/bundle/productionRelease/app-production-release.aab` (about 44 MiB).

The APK uses the contract's example development HTTP gateway and requires a real clinic account. Firebase is disabled until configured. The AAB is unsigned and uses an empty production gateway, so it proves compilation only and is not a deployable production release. Neither artifact has been tested on a physical device. No real patient login or server mutation was performed. iOS archive and push delivery remain unverified.

The installed SDK is Flutter 3.41.9 / Dart 3.11.5 stable. This run has not upgraded the shared SDK or asserted that this installed version is the latest available stable release.

### LDPlayer verification — 2026-09-15

- Installed the existing development debug APK successfully on LDPlayer (`emulator-5554`, Android 9, 900×1600).
- Confirmed Arabic RTL login rendering, two required-field errors on empty login submission, navigation to registration, three required-field errors on empty registration submission, scrolling, and return to login.
- Confirmed switching to English with LTR layout and password visibility toggling using a synthetic local input; no credentials were submitted.
- Re-ran `flutter analyze` (no issues) and `flutter test` (all 14 passed).
- No fatal Android crash, unhandled Dart exception, or RenderFlex overflow was found in the inspected app process logs. Initial debug startup took about 20 seconds, exceeding the Android activity wait timeout before the screen appeared. This is an emulator observation, not a release performance measurement.
- Screenshots and UI hierarchy evidence are saved in `docs/qa/2026-09-15/`.

This verifies the unauthenticated UI on an emulator only. Real login, patient features, backend integration, push delivery and physical-device behavior still require the external inputs above. No account was created and no backend mutation was performed.

### Authorized account login attempt — 2026-09-15

- Attempted login in LDPlayer with the account supplied by the user. The app remained on login and displayed the localized generic request failure. Credentials are not recorded in this report or QA artifacts.
- Confirmed connectivity from LDPlayer to the configured development gateway `http://217.76.53.136:8000`.
- A separate credential-free POST to `/api/v1/patient-app/auth/login` returned HTTP 404 with `Cannot POST /api/v1/patient-app/auth/login`. A GET to `/api/v1/patient-app/me/profile` from the host also returned 404.
- The returned error envelope uses nested `error.code` rather than the top-level `code` expected by the current client; this also needs confirmation against the intended patient API contract.
- Account validity remains unverified. Authenticated QA is blocked pending the correct patient API gateway/base path or deployment of the documented routes. No patient actions or messages were submitted.

### Corrected gateway and rebuilt APK — 2026-09-15 / 2026-09-16

- The user supplied `https://system.vitaxirpro.com`. Updated development example/local configuration; the client appends `/api/v1/patient-app` automatically.
- A credential-free POST from LDPlayer to the new login endpoint returned HTTP 400 with username/password validation errors, confirming that the route exists and HTTPS connectivity works.
- Built the development debug APK successfully with `config/development.local.json` and installed it on LDPlayer successfully on September 15.
- On continuation on September 16, ADB listed no connected devices and LDPlayer was no longer running. Login with the supplied account on the corrected gateway remains unverified; resume emulator QA when LDPlayer is available.
- No credentials were saved in configuration or documentation. The earlier 404 observation applies to the old IP gateway only.

### Authenticated LDPlayer QA — 2026-09-16

The user restarted LDPlayer and testing resumed against `https://system.vitaxirpro.com` using the supplied account. This supersedes the earlier login-blocked status.

| Check | Observed result |
|---|---|
| Login | Passed; authenticated navigation became available |
| Home | Rendered normally with empty upcoming appointments |
| Appointments | Loaded the empty state: no current appointments |
| Chat | Displayed the localized no-assigned-therapist state; no message sent |
| Sessions | Previously displayed service unavailable; superseded on 2026-09-17 by the confirmed `/me/sessions` integration |
| Profile | Displayed service unavailable |
| Progress | Displayed service unavailable |
| Notifications | Displayed service unavailable; push remains disabled in the build |
| Session restoration | Passed after force-stop/relaunch; returned to home without re-entering credentials |
| Runtime logs | No fatal exception, unhandled Dart exception, Flutter exception banner, or RenderFlex overflow matched the inspected process logs |

`PATIENT_SCHEMA` is still empty. The unavailable profile/progress/notification screens are consistent with the known integration boundary; UI observations alone do not verify their raw backend response shapes. Exercises and ratings could not be reached through a working session list. Token refresh/expiry, logout, populated appointments, push delivery, and successful therapist chat remain unverified in this device run.

No clinical actions, ratings, or messages were submitted. Credentials and tokens were not copied into project files. The app was left signed in on the home screen. Non-sensitive home/session-restoration evidence is in `docs/qa/2026-09-16/`.

### Remaining-feature implementation pass — 2026-09-16

Completed from read-only observations of the authorized account:

- Profile now decodes ERP first/last name and phone directly, and supports pull-to-refresh.
- Progress now decodes the four actual server counters directly.
- Inbox now decodes bilingual titles/bodies, sentAt and readAt, sorts newest first, switches language without refetching, and preserves the existing mark-read action. A push-enable button is shown only in Firebase-enabled builds.
- Strict decoding tests cover malformed patient data, invalid counters, explicit unread state, invalid dates, language fallback and repository integration with an empty PATIENT_SCHEMA.
- `flutter test`: all 17 tests passed. `flutter analyze`: no issues. Modified Dart files formatted. Development debug APK built and installed successfully on LDPlayer.
- Emulator verification: profile rendered without its previous error; progress counters rendered; inbox displayed unread notifications in Arabic and English without its previous error. Inspected process logs had no matched fatal/Dart/RenderFlex exceptions. Personal field values and notification contents were not saved as QA artifacts.
- A separate authorized test session successfully called login, refresh and logout. Refresh returned access/refresh tokens and integer expiresIn. This is a live API check, not evidence of every expiry/account-switch race on device.

Still blocked by external inputs: populated exercises and permitted execution/timer states, rating eligibility, a therapist-linked chat fixture and response contract, stable Other reason semantics, Firebase client/APNs configuration and device deregistration policy, account deletion workflow, release signing and macOS/iOS validation. No staff endpoints, fabricated records, or guessed session IDs were used. This pass does not complete all remaining features.


Update 2026-09-17: exercises now decode the observed nested patient response directly, with localized instructions, prescription counts, warnings and media. Execution permissions remain unconfirmed; see confirmed-patient-responses.md.

Update 2026-09-21: the backend confirmed that start/complete/skip are live and that only `CANCELLED` assignments are rejected (`ASSIGNMENT_CANCELLED`). Action availability is now derived from `execution`: `null` allows start/skip; a non-terminal execution allows complete/skip; `COMPLETED`, `SKIPPED`, or a `completedAt`/`skippedAt` timestamp allows nothing and shows a state badge. Explicit `exercise.canStart/canComplete/canSkip` mappings in `PATIENT_SCHEMA` still override this if the server ever provides them. The full set of `execution.status` values is still unconfirmed; unknown non-terminal values are treated as in progress, and the server remains the authority (`INVALID_ACTION`).
