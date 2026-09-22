# Backend and configuration handoff

Provide an OpenAPI document or sanitized request/response examples; do not send patient records, passwords, refresh tokens or signing secrets in these documents.

Update 2026-09-16: profile, progress and notification inbox decoding now use
[observed response fields](confirmed-patient-responses.md). Their previous
`PATIENT_SCHEMA` requirements have been removed. Update 2026-09-17: the backend confirmed deployed `GET /me/sessions`; session discovery now uses its typed patient-authorized response. The remaining
rows below should be read with this update.

| Priority | Missing information | Why it matters |
|---|---|---|
| Blocking rating UX | Patient-visible attendance and already-rated eligibility | `attendanceConfirmed` is now provided by `/me/sessions`; already-rated state remains unavailable |
| Blocking models | Exact profile, assigned exercises/latest execution, progress, skip reasons, conversation/messages and notifications schemas | Prevents invented keys, wrappers, enum values, nullability and relationships |
| Blocking skip validation | Stable Other marker on skip-reason items | Must require free text without hardcoding translated display labels |
| Blocking execution UX | Allowed execution transitions and server timing fields | Must distinguish assignment cancellation from execution state and recover timers safely |
| Auth verification | Exact refresh response including expiry metadata; expired-token status/code; logout auth requirements | Correct pre-expiry rotation, interceptor behavior and terminal error handling |
| Auth verification | Whether auth-rejected mutations are guaranteed not to execute | Determines safe bounded replay after refresh |
| Chat verification | Message ID/time/sender fields; ordering; equal-timestamp cursor semantics; conversation change behavior | Avoid duplicates, dropped messages and mixed conversations |
| Push verification | Notification item and FCM data payload schemas | Read-state rendering and resource navigation |
| Push privacy | Device unregister or reassignment semantics on logout/account switching | Registration-only contract does not establish how to stop old-account push delivery |
| Environment | HTTPS gateway for production; development/staging endpoints | Provided IP example uses HTTP; production must use HTTPS |
| Firebase | Android/iOS client configs for `vita-xir`, final IDs, APNs setup | Required for real device push delivery |
| Integration | Authorized test account and nonproduction fixture workflow | Needed to verify behavior without manipulating production patient data |
| Validation | Server username/password/phone rules and message/note limits | Avoid inventing client restrictions inconsistent with the server |
| Release | Account deletion capability or documented supported workflow | Backend support required: no deletion endpoint in the contract |

Implementation can begin with the shell, design system, transport and documented auth/appointment shapes after proposal review. Features dependent on missing schemas must wait for their contracts; staff endpoints cannot serve as a workaround.
