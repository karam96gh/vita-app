# Release readiness tracking

Status: not release-ready. This is a planning checklist, not a certification of store compliance. Recheck current official store requirements during release preparation.

- [ ] Confirm final brand, Android application ID and iOS bundle ID.
- [ ] Verify current stable Flutter/Dart and compatible dependency lockfile.
- [ ] Configure and test development/staging/production flavors and HTTPS production gateway.
- [ ] Resolve patient API gaps and verify every feature against authorized backend fixtures.
- [ ] Confirm no runtime mock data, credential logging or unintended patient-data persistence.
- [ ] Test secure token rotation, account switching, session expiry and logout.
- [ ] Configure `vita-xir` Firebase clients, Android notification icon and iOS push/APNs capabilities.
- [ ] Verify notification behavior including logged-out devices and account changes.
- [ ] Supply final adaptive/app icons, launch screens, screenshots and store copy.
- [ ] Configure Android signing outside source control; set version name/code.
- [ ] Build and test the release AAB using the production flavor/configuration.
- [ ] Configure iOS signing outside source control; set version/build number.
- [ ] Review iOS capabilities, privacy declarations and plugin-required platform configuration.
- [ ] Build/archive and validate on macOS with Xcode.
- [ ] Run format, analyzer, critical tests, integration tests and physical-device QA.
- [ ] Publish owner-approved privacy policy and support URL.
- [ ] Complete Google Play Data Safety and Apple App Privacy from the actual data inventory.
- [ ] Review permissions, retention, account deletion and age rating against current store rules.
- [ ] Backend support required: confirm account deletion workflow; no endpoint is documented.
- [ ] Record test evidence, known issues and release owner sign-off.
