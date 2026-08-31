# Floating Task Timer for macOS
## Product Requirement Document + Technical Specification + AI Engineering Execution Plan

**Product Type:** Native macOS productivity application  
**Primary Stack:** Swift, SwiftUI, AppKit  
**Primary Platform:** macOS  
**Core Use Case:** Track the real time spent on one or multiple work tasks using a minimal always-on-top floating timer.

---

# 1. Product Vision

Build a professional, native macOS task timer that helps users answer one simple question:

> “How much time did this task actually take me?”

This product is **not primarily a Pomodoro timer**.

It is a lightweight work stopwatch and task-time recorder.

The ideal workflow is:

1. Create or select a task.
2. Start timing.
3. Keep a small floating timer visible above other applications.
4. Pause, resume, switch tasks, or finish.
5. Save accurate task duration.
6. Review task history and daily statistics.

The product should feel fast, quiet, native, trustworthy, and invisible while the user works.

---

# 2. Product Principles

The product must follow these principles:

## 2.1 Fast

The user should be able to start tracking a task within seconds.

No account creation.

No onboarding wall.

No unnecessary project-management setup.

## 2.2 Accurate

The timer must use real timestamps rather than incrementing a counter every second.

Timing must remain accurate during:

- UI delays
- app backgrounding
- window hiding
- app restarts
- Mac sleep/wake cycles

## 2.3 Minimal

This is not a project management system.

Avoid:

- Kanban boards
- Gantt charts
- team collaboration
- chat
- complex project hierarchy
- enterprise workflow features

The core product is:

> Task + Timer + Floating Window + History

## 2.4 Native

The product should look and behave like a high-quality macOS application.

Prefer Apple-native frameworks.

Avoid unnecessary third-party dependencies.

## 2.5 Privacy-first

By default:

- no account
- no login
- no cloud dependency
- all data stays locally on the Mac
- no analytics that contains task names unless explicitly approved by the user

---

# 3. Core User Stories

## 3.1 Start a task

As a user, I can enter:

`Prepare client proposal`

and press Start.

The timer starts from:

`00:00:00`

## 3.2 Keep timer visible

As a user, I can enable the Pin button so the timer remains visible above:

- Safari
- Chrome
- Word
- Excel
- Notion
- Finder
- Xcode
- Slack

## 3.3 Disable floating mode

As a user, I can click the Pin button again.

The timer continues running but behaves like a normal window.

## 3.4 Pause and resume

I can pause my current task.

The accumulated time is preserved.

Later I can resume from the same duration.

## 3.5 Finish a task

When I click Finish, the application displays:

- Task name
- Start time
- Finish time
- Active duration
- Paused duration
- Total elapsed duration

I can Save or Discard.

## 3.6 Switch between tasks

I can keep several unfinished tasks.

Example:

- Write report — 42m
- Reply to email — 18m
- Data analysis — 1h 12m

By default, only one task runs at a time.

If I switch to another task:

- current running task pauses
- selected task resumes

## 3.7 View history

I can see completed tasks by date.

I can inspect how much time was spent on each task.

## 3.8 Restore after restart

If the app is quit or crashes, current task state must restore accurately.

---

# 4. Functional Requirements

# 4.1 Floating Timer Window

The app must provide a small floating timer window.

Requirements:

- draggable anywhere on screen
- compact size
- remembers last window position
- supports Light Mode
- supports Dark Mode
- supports System appearance
- does not unnecessarily steal focus
- can remain above other application windows
- can return to normal window level

Suggested implementation:

- SwiftUI content
- AppKit `NSPanel` or custom `NSWindow`

---

# 4.2 Pin / Always-on-Top Toggle

Place a small Pin button in the top-right of the timer.

Recommended SF Symbols:

- `pin`
- `pin.fill`

Behavior:

### Pin ON

Set:

`window.level = .floating`

The timer stays above normal application windows.

Tooltip:

`Disable Always on Top`

### Pin OFF

Set:

`window.level = .normal`

The timer behaves like a normal window.

Tooltip:

`Keep Timer on Top`

Pin state should persist using:

`@AppStorage("isTimerPinned")`

Turning Pin on/off must not:

- pause timers
- reset timers
- delete tasks
- affect history

---

# 4.3 Timer Controls

Core controls:

- Start
- Pause
- Resume
- Reset
- Finish

## Start

Starts an idle task.

## Pause

Stops active duration accumulation.

## Resume

Continues a paused task.

## Reset

Returns current task timer to zero.

Reset should optionally require confirmation:

`Reset current timer?`

Buttons:

- Cancel
- Reset

## Finish

Finishes the task and shows a summary.

---

# 4.4 Task Naming

Before starting, the user may enter a task name.

Examples:

- Write report
- Reply to emails
- Prepare meeting
- Research competitors
- Review pull request

If empty:

`Untitled Task`

After the timer starts, the task-name field may become a simple label.

---

# 4.5 Multiple Tasks

The app must support multiple unfinished tasks.

Every task has independent state.

Recommended model:

```swift
struct TaskSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String?
    var status: TaskStatus

    var createdAt: Date
    var firstStartedAt: Date?
    var lastResumedAt: Date?
    var completedAt: Date?

    var accumulatedActiveDuration: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
}
```

Task states:

```swift
enum TaskStatus: String, Codable {
    case idle
    case running
    case paused
    case completed
}
```

---

# 4.6 Default Single-Running-Task Mode

Default behavior:

> Multiple tasks may exist, but only one may be running at a time.

Example:

```text
Write report       00:42:18   Running
Reply emails       00:18:32   Paused
Data analysis      01:12:05   Paused
```

If the user resumes `Reply emails`:

1. `Write report` pauses.
2. `Reply emails` resumes.

This avoids double-counting human focus time.

---

# 4.7 Optional Multi-Timer Mode

Settings option:

`Allow Multiple Timers to Run Simultaneously`

Default:

`Off`

If enabled, multiple tasks may run simultaneously.

Example use cases:

- background file export
- rendering
- data processing
- human work happening alongside machine processing

When enabled, analytics should distinguish:

- Recorded Task Time
- Unique Active Time

Do not simply sum overlapping sessions and call that focus time.

---

# 4.8 Timer Accuracy

Do **not** implement timing as:

```swift
seconds += 1
```

The UI may refresh every second, but time calculation must be timestamp-based.

For a running task:

```swift
displayDuration =
    accumulatedActiveDuration
    + Date().timeIntervalSince(lastResumedAt)
```

On Pause:

```swift
accumulatedActiveDuration +=
    Date().timeIntervalSince(lastResumedAt)
```

Then:

```swift
lastResumedAt = nil
```

This architecture prevents timer drift.

---

# 4.9 Compact Mode

Compact floating mode example:

```text
Prepare report               📌
00:42:18

Pause       Finish
```

Or multi-task compact mode:

```text
Prepare report      42:18   ⏸
Reply emails        18:32   ▶
Data analysis     1:12:05   ▶
```

---

# 4.10 Expanded Mode

Example:

```text
Prepare client report               📌

          00:42:18

Start     Pause     Reset

            Finish
```

The user can switch between Compact and Expanded.

---

# 4.11 Active Task

The application should have a concept called:

`Active Task`

This is the primary currently selected task.

Example:

```text
CURRENT

Prepare client report
00:42:18

Pause    Finish

OTHER TASKS

Reply emails        18:32
Data analysis     1:12:05
```

---

# 4.12 Quick Task Creation

Floating window includes:

`+`

When clicked:

```text
New Task
[________________]

Create
Create & Start
```

Recommended default action:

`Create & Start`

If another task is running and single-task mode is enabled:

- pause existing task
- start new task

---

# 4.13 Finish Task Flow

When Finish is clicked:

```text
Task
Prepare client report

Duration
01:23:42

Started
09:32

Finished
10:56

Paused
04:18
```

Actions:

- Save
- Discard

Save:

- stores task in history
- marks task completed
- removes it from active task list

Discard:

- deletes the current session after confirmation

---

# 4.14 History

History view should include:

| Task | Date | Duration |
|---|---|---|
| Client report | Aug 31 | 1h 23m |
| Email replies | Aug 31 | 32m |
| Data analysis | Aug 30 | 2h 14m |

Opening a record shows:

- Task name
- Category
- Created time
- Start time
- Finish time
- Active time
- Paused time
- Total elapsed time

---

# 4.15 Daily Statistics

History page top section:

## Today

**Total Focus Time**

`04h 32m`

**Tasks Completed**

`7`

**Longest Task**

`01h 42m`

**Average Task**

`38m`

Future additions may include:

- 7-day totals
- weekly averages
- category totals
- hour-of-day heatmap

These should not be required for MVP.

---

# 4.16 Categories

Optional task categories:

- Work
- Study
- Admin
- Meeting
- Personal

Users can create custom categories later.

Categories must remain optional.

Creating a task should never require category selection.

---

# 4.17 Menu Bar

Provide a macOS menu-bar item.

Example:

`⏱ 32:18`

Clicking it opens:

```text
Prepare report
00:32:18

Pause
Finish
Open Timer
History
```

Menu-bar display preferences:

- icon only
- icon + duration
- hidden

---

# 4.18 Keyboard Shortcuts

Recommended defaults:

`⌥ + Space`

Start / Pause / Resume

`⌥ + Enter`

Finish Task

`⌥ + R`

Reset

`⌥ + N`

New Task

Shortcuts should be configurable.

---

# 4.19 Settings

## General

- Launch at Login
- Always on Top default
- Show Menu Bar Timer
- Show Seconds
- Confirm Before Reset
- Confirm Before Discard
- Allow Multiple Timers Simultaneously

## Appearance

- System
- Light
- Dark

## Timer Display

- HH:MM:SS
- MM:SS

## Keyboard Shortcuts

Editable shortcut mapping.

---

# 4.20 Local Persistence

All user data should remain local by default.

Recommended options:

### MVP

SwiftData

or

Core Data

SwiftData is preferred for modern macOS if deployment target permits.

Persist:

- tasks
- completed sessions
- settings
- active task ID
- window position
- Pin state

---

# 4.21 Crash and Restart Recovery

The application must store timestamps frequently enough that state is recoverable.

For running tasks, save:

- `lastResumedAt`
- `accumulatedActiveDuration`
- current status

On relaunch:

If a task was running:

```text
current duration =
stored active duration
+
now - stored lastResumedAt
```

Do not rely on restoring an in-memory Timer.

---

# 4.22 Sleep / Wake Behavior

Define product behavior clearly.

Recommended default:

If timer is running and Mac sleeps:

**Elapsed clock time continues.**

Why:

The task remained active unless explicitly paused.

Later, add a setting:

`Pause timers when Mac sleeps`

If enabled:

- listen for system sleep event
- pause running tasks
- save state

---

# 4.23 CSV Export

History page action:

`Export CSV`

Columns:

```text
Date
Task
Category
Start Time
End Time
Active Duration
Paused Duration
Elapsed Duration
```

Make the output compatible with:

- Excel
- Numbers
- Google Sheets

---

# 5. UX Requirements

The product should feel:

- calm
- focused
- minimal
- premium
- native

Avoid:

- bright gamification
- unnecessary gradients
- excessive cards
- oversized controls
- distracting animations
- productivity guilt messaging

Time should be the main visual element.

Use monospaced digits where practical.

---

# 6. Accessibility Requirements

Support:

- VoiceOver
- keyboard navigation
- visible focus states
- accessible labels for icon-only buttons
- sufficient text contrast
- Dynamic Type-compatible sizing where possible
- Reduce Motion

Pin icon must include an accessibility label.

Example:

`Keep Timer on Top`

---

# 7. Recommended Technical Architecture

Use a modular architecture.

Example project structure:

```text
FloatingTaskTimer/
│
├── App/
│   ├── FloatingTaskTimerApp.swift
│   ├── AppDelegate.swift
│   └── AppEnvironment.swift
│
├── Models/
│   ├── TaskSession.swift
│   ├── TaskStatus.swift
│   └── AppSettings.swift
│
├── Services/
│   ├── TimerEngine.swift
│   ├── TaskStore.swift
│   ├── WindowManager.swift
│   ├── ShortcutManager.swift
│   ├── ExportService.swift
│   └── SleepWakeMonitor.swift
│
├── ViewModels/
│   ├── TimerViewModel.swift
│   ├── TaskListViewModel.swift
│   ├── HistoryViewModel.swift
│   └── SettingsViewModel.swift
│
├── Views/
│   ├── Floating/
│   │   ├── FloatingTimerView.swift
│   │   ├── CompactTimerView.swift
│   │   └── ExpandedTimerView.swift
│   │
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   └── NewTaskView.swift
│   │
│   ├── History/
│   │   ├── HistoryView.swift
│   │   └── SessionDetailView.swift
│   │
│   ├── Settings/
│   │   └── SettingsView.swift
│   │
│   └── MenuBar/
│       └── MenuBarView.swift
│
├── Persistence/
│   ├── PersistenceController.swift
│   └── Migrations/
│
├── Utilities/
│   ├── DurationFormatter.swift
│   ├── DateFormatter+Extensions.swift
│   └── Logger.swift
│
└── Tests/
    ├── TimerEngineTests.swift
    ├── TaskStoreTests.swift
    └── DurationFormatterTests.swift
```

---

# 8. Timer Engine

The `TimerEngine` should contain business logic independent of SwiftUI.

Example responsibilities:

- start
- pause
- resume
- reset
- finish
- calculate duration
- switch active task
- guarantee only one running task when configured

The view layer should not own timing logic.

---

# 9. State Machine

Recommended transitions:

```text
idle
 ↓ start
running
 ↓ pause
paused
 ↓ resume
running
 ↓ finish
completed
```

Reset:

```text
idle / running / paused
        ↓
       idle
```

Invalid transitions should be ignored or safely rejected.

Examples:

- cannot pause idle task
- cannot resume running task
- cannot start completed task
- cannot finish completed task twice

---

# 10. Window Architecture

Recommended:

SwiftUI View inside an AppKit `NSPanel`.

Desired panel characteristics:

- floating capable
- borderless or compact title bar
- movable
- remembers position
- joins all Spaces if desired
- behaves correctly when app is not active

Investigate:

```swift
NSPanel
NSWindow.Level.floating
NSWindow.Level.normal
collectionBehavior
hidesOnDeactivate
becomesKeyOnlyIfNeeded
```

Do not assume all flags should be enabled.

Test actual behavior on macOS.

---

# 11. Menu Bar Architecture

Use:

`MenuBarExtra`

where deployment target supports it.

Menu bar should use shared timer state from the same application model.

Do not create an independent timer.

---

# 12. Persistence Model

Recommended persisted entities:

## TaskSession

- id
- name
- category
- status
- createdAt
- firstStartedAt
- lastResumedAt
- completedAt
- accumulatedActiveDuration
- accumulatedPausedDuration
- pauseStartedAt

## Settings

Prefer UserDefaults / `@AppStorage` for small preferences.

Examples:

- pin state
- display format
- confirmation settings
- multi-timer preference

---

# 13. Logging

Use Apple's unified logging:

```swift
import OSLog
```

Log:

- app startup
- timer transitions
- persistence failures
- migration failures
- export failures
- unexpected invalid state

Do not log sensitive task names by default.

Use task IDs where possible.

---

# 14. Error Handling

The product should not crash because:

- local database cannot write once
- CSV export fails
- a corrupted preference exists
- window location is invalid
- a shortcut conflicts

Display user-friendly errors where action is needed.

Log technical details separately.

---

# 15. Testing Strategy

# 15.1 Unit Tests

Test TimerEngine heavily.

Required cases:

- start from idle
- pause running timer
- resume paused timer
- reset running task
- reset paused task
- finish running task
- finish paused task
- app restart while running
- app restart while paused
- timer across simulated sleep period
- switch active task
- single-running-task enforcement
- overlapping multi-timer mode
- duration formatting

Use injectable clocks where possible.

Avoid unit tests that depend on real wall-clock waiting.

---

# 15.2 Persistence Tests

Test:

- saving new task
- updating running state
- app relaunch restoration
- completing a task
- deleting a task
- schema migration

---

# 15.3 UI Tests

Core flows:

1. Create task.
2. Start timer.
3. Pause.
4. Resume.
5. Finish.
6. Verify history item.
7. Toggle Pin.
8. Open menu bar.
9. Switch active task.

---

# 15.4 Manual QA

Test on:

- external monitor
- multiple Spaces
- Stage Manager
- full-screen apps
- Dark Mode
- Light Mode
- Mac sleep/wake
- app force quit
- logout/relogin
- screen scaling changes

---

# 16. MVP Scope

Version 1.0 MVP should contain only:

1. Create task
2. Start timer
3. Pause / Resume
4. Reset
5. Finish
6. Floating window
7. Pin toggle
8. Multiple task storage
9. One active running task by default
10. Task switching
11. History
12. Menu-bar timer
13. local persistence
14. accurate restart recovery
15. settings basics

Optional for 1.1:

- categories
- CSV export
- global shortcuts
- launch at login
- richer analytics
- multi-running-task mode

---

# 17. Non-Goals for MVP

Do not implement:

- user accounts
- cloud backend
- subscription billing
- team collaboration
- web dashboard
- iPhone sync
- project management
- AI task classification
- calendar integration

Those can be considered later.

---

# 18. AI Coding Workflow

When using Cursor, Claude Code, Codex, or another AI coding agent:

Do not request:

> “Build the whole app.”

Instead build in controlled stages.

Every stage should:

1. define goal
2. list files affected
3. implement
4. compile
5. run tests
6. review diff
7. commit

---

# 19. Recommended Development Phases

# Phase 0 — Product Setup

Create:

- Git repository
- README
- `/docs`
- `.gitignore`
- issue tracker
- semantic versioning strategy

Suggested branches:

```text
main
develop
feature/*
fix/*
release/*
```

For a solo developer, trunk-based development with short-lived feature branches is also acceptable.

---

# Phase 1 — Xcode Skeleton

Create a native macOS SwiftUI application.

Confirm:

- launches successfully
- builds cleanly
- minimum macOS version selected
- bundle identifier configured
- app icon placeholder exists

Commit:

`chore: initialize macOS application`

---

# Phase 2 — Domain Model

Implement:

- TaskSession
- TaskStatus
- TimerEngine

No UI complexity yet.

Write unit tests before continuing.

Commit:

`feat: add task timer domain model`

---

# Phase 3 — Single Timer UI

Create one timer.

Support:

- task name
- Start
- Pause
- Resume
- Reset
- Finish

Do not add multiple tasks yet.

Commit:

`feat: implement single task timer`

---

# Phase 4 — Accurate Persistence

Add SwiftData/Core Data.

Confirm:

- running task survives app restart
- paused task survives restart
- completed tasks persist

Commit:

`feat: persist timer sessions`

---

# Phase 5 — Floating NSPanel

Implement floating window.

Test:

- Pin ON
- Pin OFF
- window drag
- app switching
- multi-monitor behavior

Commit:

`feat: add floating timer panel`

---

# Phase 6 — Multiple Tasks

Add task list and task switching.

Enforce:

`maximumRunningTasks = 1`

unless multi-timer mode is enabled later.

Commit:

`feat: support multiple task sessions`

---

# Phase 7 — History

Create history list and detail page.

Commit:

`feat: add task history`

---

# Phase 8 — Menu Bar

Add menu-bar timer.

Commit:

`feat: add menu bar controls`

---

# Phase 9 — Settings

Add:

- Pin default
- Show seconds
- display mode
- confirmations

Commit:

`feat: add application settings`

---

# Phase 10 — Hardening

Add:

- error handling
- logging
- accessibility
- crash-state recovery
- schema migrations

Commit:

`chore: harden application reliability`

---

# 20. Professional Git Workflow

Use meaningful commits.

Good:

```text
feat: add pause and resume timer transitions
fix: restore active duration after app relaunch
test: cover timer reset state transitions
refactor: extract timer logic from view model
```

Avoid:

```text
update
fix stuff
working
final
final2
```

Use pull requests even as a solo developer when possible.

They create useful checkpoints for AI-generated changes.

---

# 21. Code Review Checklist

Before accepting AI-generated code, check:

- Does it compile?
- Are there warnings?
- Is business logic inside the View?
- Are timers duplicated?
- Is state persisted?
- Are force unwraps used unnecessarily?
- Is error handling present?
- Is the code testable?
- Are APIs deprecated?
- Are accessibility labels present?
- Are there unnecessary dependencies?
- Did the AI modify unrelated files?

Never merge AI-generated code only because it “looks correct.”

---

# 22. AI Prompting Template

Use this structure with coding agents:

```text
You are working on a native macOS SwiftUI application.

Goal:
[one narrowly defined feature]

Current architecture:
[relevant architecture]

Requirements:
[list]

Constraints:
- Swift + SwiftUI
- use AppKit only where needed
- no unnecessary third-party packages
- preserve existing architecture
- do not modify unrelated files

Before editing:
1. inspect relevant files
2. explain proposed changes briefly
3. identify edge cases

Then:
1. implement
2. compile
3. run relevant tests
4. report files changed
5. report any remaining risks
```

---

# 23. Definition of Done

A feature is not complete until:

- code builds
- automated tests pass
- manual test performed
- no critical warnings
- UI works in Light and Dark mode
- failure paths considered
- commit created
- documentation updated when necessary

---

# 24. Security and Privacy

For MVP:

Do not request:

- Contacts
- Calendar
- Microphone
- Camera
- Accessibility permission
- Screen recording permission

unless the product genuinely needs them.

Global keyboard shortcuts may require a specific implementation strategy; avoid asking for broader permissions than necessary.

Data should remain inside the application container unless the user explicitly exports it.

---

# 25. App Sandbox

Enable App Sandbox.

Grant only required entitlements.

For CSV export, use user-selected file access via standard save panels rather than broad filesystem permissions.

---

# 26. Release Build Preparation

Before release:

- remove debug-only UI
- check logs
- test fresh install
- test upgrade install
- test database migration
- archive Release build
- validate bundle identifier
- confirm version/build numbers
- confirm icons
- confirm copyright metadata
- confirm privacy text

---

# 27. Apple Developer Setup

To distribute professionally:

1. Join the Apple Developer Program.
2. Configure Developer ID / App Store certificates.
3. Set correct Bundle ID.
4. Configure signing in Xcode.
5. Enable Hardened Runtime where required.
6. Archive using Release configuration.

---

# 28. Distribution Options

There are two main routes.

## Option A — Mac App Store

Advantages:

- trusted installation
- native updates
- Apple storefront
- simpler user trust model

Requires:

- App Sandbox
- App Store review
- App Store metadata
- privacy disclosures

## Option B — Direct Distribution

Distribute from your own website.

Requires:

- Developer ID signing
- Hardened Runtime
- notarization
- stapling
- your own update mechanism if desired

For an early commercial product, many developers support both eventually.

---

# 29. Notarization

For direct distribution:

1. Archive app.
2. Sign with Developer ID Application certificate.
3. Submit to Apple notarization service.
4. Wait for successful notarization result.
5. Staple notarization ticket.
6. Test installation on another Mac.

Never ship an unsigned downloadable `.app` as a professional release.

---

# 30. Release QA Checklist

Test on a clean Mac user account.

Verify:

- application launches
- Gatekeeper accepts application
- Pin works
- timer starts
- timer survives relaunch
- menu bar works
- history persists
- dark mode works
- CSV export works if included
- sleep/wake behavior is correct
- no debug logs expose task names
- app icon displays correctly

---

# 31. Beta Program

Before public launch, recruit 10–30 users.

Ask them specifically:

- Did you understand Start immediately?
- Did Pin behave as expected?
- Did you trust the time recorded?
- Did you ever accidentally reset a task?
- Was the floating window distracting?
- Did you want one timer or multiple timers?
- Which history information was useful?
- Was menu-bar mode enough without floating mode?

Observe behavior, not only opinions.

---

# 32. Crash Monitoring

For a commercial product, add privacy-respecting crash monitoring.

Options include:

- Apple crash reports
- Xcode Organizer diagnostics
- third-party crash reporting later if needed

Avoid collecting task names in crash metadata.

---

# 33. Analytics

For MVP, analytics may be omitted.

If analytics are added, measure only useful product events, such as:

- app launched
- timer started
- timer completed
- pin enabled
- compact mode used
- menu-bar mode used

Do not send:

- task titles
- personal notes
- exported data

unless explicitly consented.

---

# 34. Product Metrics

Useful business/product metrics:

- weekly active users
- task completion sessions per user
- percentage of users using Pin
- percentage using menu bar
- average sessions per active day
- 7-day retention
- 30-day retention

Do not optimize for time spent inside the app.

The application should help users work outside the app.

---

# 35. Versioning

Use semantic versioning conceptually:

```text
1.0.0
1.1.0
1.1.1
2.0.0
```

Examples:

- `1.0.0`: first stable release
- `1.1.0`: categories + CSV
- `1.2.0`: keyboard shortcuts
- `2.0.0`: major sync or platform expansion

---

# 36. Future Roadmap

After product-market validation:

## 1.1

- Categories
- CSV export
- keyboard shortcuts
- Launch at Login

## 1.2

- weekly analytics
- task templates
- better menu-bar experience

## 1.3

- idle detection
- optional pause-on-sleep
- reminders for very long-running tasks

## 2.0

Possible:

- iCloud sync
- iPhone companion
- Apple Watch control
- calendar association

Only build these after validating demand.

---

# 37. AI Features — Optional Future Direction

Do not put AI into v1 merely because the product is being built with AI.

Potential future AI features:

- automatically categorize completed tasks
- summarize weekly work patterns
- estimate expected task duration
- detect recurring task types
- compare estimated vs actual duration

Any AI feature involving task names should be opt-in and privacy-aware.

---

# 38. MVP Acceptance Criteria

The product is ready for beta when all of the following are true:

- user can create a task
- user can start it
- user can pause/resume it
- user can reset it
- user can finish and save it
- timer remains accurate across relaunch
- floating mode can be toggled with Pin
- multiple unfinished tasks are supported
- task switching works
- only one task runs by default
- completed sessions appear in history
- menu bar shows current timer
- no known data-loss bug exists
- basic unit tests pass
- application builds in Release configuration

---

# 39. Launch Acceptance Criteria

The product is ready for public launch when:

- beta users have tested it
- no critical crashes remain
- migration strategy exists
- privacy policy is published
- support contact exists
- app is signed
- app is notarized or App Store approved
- clean-install QA passes
- upgrade QA passes
- release notes are prepared

---

# 40. Final Product Philosophy

This application should not attempt to manage the user's life.

Its job is simply to make one behavior effortless:

> Start a task, see how long it really takes, and remember the result.

The floating timer should disappear into the user's workflow while remaining available at exactly the right moment.

If the user notices the application constantly, the UI is probably too complicated.

If the user finishes a week and understands where their work time actually went, the product succeeded.
