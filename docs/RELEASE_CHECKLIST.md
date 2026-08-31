# FloatingTaskTimer Release Checklist

Never test migration by deleting or modifying the only copy of real user data. Record the build number, macOS version, hardware, and result for every release candidate.

## A. Pre-release engineering

- [ ] Debug and Release configurations build with zero errors.
- [ ] Unit tests pass without `sleep()` or real-time assumptions.
- [ ] UI tests run with `FTT_UI_TESTING=1`, in-memory SwiftData, and isolated preferences; confirm they never open the real user database.
- [ ] Review compiler, deprecation, Swift concurrency, signing, and entitlement warnings.
- [ ] `git diff --check` passes and the release commit is reproducible.
- [ ] Version and build numbers are incremented; release notes are prepared.
- [ ] No task names, exported content, or private notes appear in logs.
- [ ] No debug-only UI, analytics SDK, crash SDK, network client, or third-party dependency is present.

## B. Manual QA

- [ ] Start, Pause, Resume, Reset, and Finish behave correctly.
- [ ] Run three tasks simultaneously; pausing/finishing one does not change the others.
- [ ] Relaunch with multiple running tasks, a paused task, and completed History.
- [ ] Test Pin ON/OFF over Safari, VS Code full screen, Xcode full screen, and desktop Spaces.
- [ ] Exercise Mini ↔ Expanded ↔ native full screen in several sequences; confirm one window and unchanged timers/Pin.
- [ ] From a different desktop and from VS Code/Safari/Xcode full-screen Spaces, cold-launch and reopen the app with Pin ON and OFF; confirm it appears in the current Space without returning to its previous desktop.
- [ ] Move Mini to each display and verify its saved position.
- [ ] Continue, Rename, View Log, select, bulk delete, and verify grouped History totals.
- [ ] Export one and many selected groups; open both worksheets in Excel and Numbers.
- [ ] Pause/resume/finish from Menu Bar and verify the floating UI updates immediately.
- [ ] Test System, Light, Dark, Show Seconds, menu-bar modes, and confirmation settings.
- [ ] Run VoiceOver and keyboard navigation through Mini, Expanded, History, export, Menu Bar, and Settings.

## C. Clean install

- [ ] Use a clean macOS user account or isolated test container; do not remove real user data.
- [ ] Confirm first launch creates the local database and a visible on-screen window.
- [ ] Verify task timing, Pin, Mini, History, export, Settings, and Menu Bar.
- [ ] Quit and relaunch to confirm persistence.

## D. Upgrade install

- [ ] Back up Application Support/container data and test only a copy of an older database.
- [ ] Verify idle, running, paused, and completed sessions after upgrade.
- [ ] Verify all `taskGroupID` values are stable and lineage chains are preserved or safely repaired.
- [ ] Verify unrelated same-name records remain separate.
- [ ] Verify Settings and Mini/Expanded positions restore safely.
- [ ] Relaunch twice to prove migration is idempotent.

## E. App Sandbox

- [ ] App Sandbox and Hardened Runtime remain enabled.
- [ ] User-selected file read/write is the only filesystem entitlement required for export.
- [ ] No Contacts, Calendar, Camera, Microphone, Screen Recording, Accessibility, or network entitlement is present.
- [ ] Export succeeds to a user-selected location and nowhere else is accessed broadly.

## F. Signing

- [ ] Confirm the production Bundle ID and Apple Developer Team.
- [ ] Install valid Mac Development, Developer ID Application, and/or Mac App Distribution certificates as appropriate.
- [ ] Confirm signing identity and provisioning profile for the chosen channel.
- [ ] Verify the signed app with `codesign --verify --deep --strict --verbose=2`.

## G. Archive

- [ ] Supply every required macOS AppIcon representation.
- [ ] Product Archive succeeds using Release.
- [ ] Validate the archive in Xcode Organizer.
- [ ] Inspect the archived entitlements and embedded provisioning profile.
- [ ] Smoke-test the exported archived app on another compatible Mac.

## H. Notarization

- [ ] For direct distribution, sign with Developer ID Application and enable Hardened Runtime.
- [ ] Submit with `notarytool`, wait for Accepted, and retain the submission ID/log.
- [ ] Staple and validate the ticket.
- [ ] Verify Gatekeeper acceptance on a clean Mac.

## I. Mac App Store

- [ ] Create the matching App Store Connect record and Bundle ID.
- [ ] Provide screenshots, description, category, support URL, privacy policy, age rating, and privacy answers.
- [ ] Upload and validate the archive; resolve every App Store validation warning.
- [ ] Complete TestFlight/internal testing before review submission.

## J. Direct distribution

- [ ] Package the notarized/stapled app in a signed DMG or ZIP.
- [ ] Publish checksum, release notes, system requirements, support contact, and privacy policy.
- [ ] Test download, quarantine, first launch, and replacement upgrade from the real delivery URL.

## K. Privacy

- [ ] SwiftData, History, settings, and task names remain local.
- [ ] XLSX data leaves the container only through explicit user export.
- [ ] Confirm no CloudKit, hidden networking, account system, telemetry, or analytics exists.
- [ ] Review Unified Logging to ensure it contains IDs/counts/states, not task names or workbook content.

## L. Final acceptance

- [ ] No known crash, data-loss, timer-integrity, export-freeze, duplicate-window, or off-screen-window defect remains.
- [ ] Clean install, upgrade, force-quit recovery, multi-display, accessibility, and both distribution-channel checks pass.
- [ ] Product owner approves the final diff, manual QA record, archive, privacy review, and release notes.
