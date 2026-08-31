# FloatingTaskTimer Release QA Report

Date: 2026-08-31
Host: macOS 26.4, Apple silicon, built-in display only

## Completed checks

- All macOS AppIcon slots are populated from one 1024 × 1024 production master. Asset compilation produced `AppIcon.icns` without catalog errors.
- A copied legacy SwiftData store was opened twice with the current schema. Session IDs and migrated group IDs remained stable, and the original/copy checksums matched before the test.
- Debug and Release builds succeeded with a macOS 14.0 deployment target.
- The full unit-test suite succeeded, including export integrity, migration repair, timer recovery, window collection behavior, and disconnected-display frame repair.
- A Release archive was produced at `/tmp/FloatingTaskTimer-unsigned.xcarchive`.
- A retained two-sheet workbook was generated at `FloatingTaskTimer-QA.xlsx`; ZIP package integrity and export tests passed.
- UI test launches now use an in-memory SwiftData container and the isolated `whywhy.FloatingTaskTimer.UITests` preferences suite.

## Environment-blocked checks

- External-display disconnect cannot be physically tested because only the built-in display is connected. The deterministic disconnected-monitor repair test passes.
- Signed UI automation and production Archive are blocked: Xcode cannot find a `Mac Development` identity with a matching private key for team `J2558PVX8U`.
- Direct-distribution notarization/stapling is blocked because no `Developer ID Application` identity or `notarytool` keychain profile is installed.
- App Store Connect upload is blocked because no Mac App Distribution identity/upload credentials are available.
- Store metadata is incomplete: privacy-policy URL, support URL, description, screenshots, and age rating/privacy answers have not been supplied.
- This run did not certify real external-display disconnect, end-to-end VoiceOver narration, or full-screen behavior across VS Code/Safari/Xcode; these remain physical/manual release gates.
- The generated QA workbook passed structural tests, but successful visual opening in both Excel and Numbers remains a manual release gate.

## Confirmed identifiers

- Bundle ID: `whywhy.FloatingTaskTimer`
- Apple Developer team configured in the project: `J2558PVX8U`
- Marketing version: `1.0`
- Build number: `1`
- App category: Productivity (`public.app-category.productivity`)
- Minimum system version: macOS `14.0`

Version/build values are technically valid but must be deliberately incremented for an actual release candidate.
