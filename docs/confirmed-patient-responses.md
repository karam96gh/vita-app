# Confirmed patient response fields

Observed through authenticated, read-only requests to the user-supplied gateway
`https://system.vitaxirpro.com/api/v1/patient-app` on 2026-09-16.
Only field names and types were retained; no account values or tokens are recorded.
These observations are not a complete OpenAPI contract.

All successful responses use `{ "success": true, "data": ... }`.

| Endpoint | Used fields inside data | Client conversion |
|---|---|---|
| `/me/profile` | `erpPatient.firstName`, `erpPatient.lastName`, `erpPatient.phone` | Join trimmed names; phone is nullable; ignore identity numbers and other unused account fields |
| `/me/progress` | `totalActiveAssignments`, `completed`, `skipped`, `inProgress` | Require nonnegative integer counts; do not assume categories form a partition |
| `/me/notifications` | List of `id`, `titleAr`, `titleEn`, `bodyAr`, `bodyEn`, `sentAt`, `readAt` | Localize text, sort by sentAt descending; explicit null readAt means unread, timestamp means read |

The current account's appointments list was empty. Chat returned the existing
`NO_RESPONSIBLE_THERAPIST` condition, so successful conversation/message schemas
could not be inspected.

Update 2026-09-17 (backend handoff): `GET /me/sessions` is now deployed with patient Bearer authentication. Its data is a list of `id`, `caseId`, `sessionNumber`, `sessionDate`, `attendanceConfirmed`, nullable `physiotherapistId` and nullable `appointmentId`. The client decodes sessions directly and passes `id` as `erpSessionId` to `/me/sessions/:erpSessionId/exercises`. Rating history is not included. This supersedes the earlier 404 observation; live verification of the new endpoint has not been performed.

Skip reasons expose `id`, `nameAr`, `nameEn`, `sortOrder`, `active`, `createdAt`,
and `updatedAt`, but no explicit Other marker was observed. This is not enough
to infer the server's free-text requirement from a translated display label.

Still required: populated session/exercise/chat fixtures and their schemas,
exercise transition/timer semantics, rating eligibility, Other identification,
notification payload routing, device deregistration/account deletion contracts,
Firebase client options, signing, and an iOS build environment.

## Exercise list observed 2026-09-17

Authenticated read-only inspection through the existing emulator app confirmed
`GET /me/sessions/:erpSessionId/exercises` returns a list. No tokens, identifiers,
patient values or response bodies were retained in this document.

Assignment fields used: `id`, `status`, `sortOrder`, `durationSeconds`, `sets`,
`reps`, `holdSeconds`, `restSeconds`, `customInstructionAr/En`, and
`frequencyTextAr/En`. The nested `exercise` object supplies `nameAr/En`,
`descriptionAr/En`, `executionMethodAr/En`, `warningsAr/En`,
`commonMistakesAr/En`, `mediaType`, and `mediaUrl`. IMAGE and VIDEO were observed.
The client sorts by sortOrder and uses the assignment ID for action endpoints.

The populated response contained ACTIVE assignments and `execution: null`.
It did not contain canStart/canComplete/canSkip. Rendering now requires no
PATIENT_SCHEMA. Action permissions remain configurable and disabled when
unconfirmed; no execution transitions or timers have been inferred, and no
patient exercise was started, completed or skipped during this verification.
Non-null execution shape and allowed transitions are still required for actions.