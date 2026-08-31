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

## 3.6 Work with multiple tasks

I can keep several unfinished tasks.

Example:

- Write report — 42m
- Reply to email — 18m
- Data analysis — 1h 12m

Multiple tasks may run simultaneously by default.

If I start or resume another task:

- existing running tasks continue running
- the selected task starts or resumes independently

## 3.7 View history

I can see completed tasks by date.

I can inspect how much time was spent on each task.

I can select completed records for Excel export and use native context-menu actions to continue tracking, rename, or delete a History record.

## 3.8 Restore after restart

If the app is quit or crashes, every task state must restore accurately. All tasks that were running continue independently from their stored timestamps, while paused tasks remain frozen.

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
- follows the user across macOS desktop Spaces while Pin is enabled
- remains available in supported full-screen application Spaces while Pin is enabled
- uses one retained window rather than creating a window for each Space

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

The timer stays above normal application windows and follows the currently active macOS Space.

Required Space behavior:

- switching between desktop Spaces keeps the timer visible
- entering or switching to a native full-screen Space for VS Code, Safari, or another normal macOS application keeps the timer visible above that application
- Space transitions must reuse the same panel and must not create duplicate windows
- following a Space must not activate the timer app or steal keyboard focus unnecessarily

Tooltip:

`Disable Always on Top`

### Pin OFF

Set:

`window.level = .normal`

The timer behaves like a normal window and no longer follows the user into other desktop or full-screen Spaces.

Tooltip:

`Keep Timer on Top`

Pin state should persist using:

`@AppStorage("isTimerPinned")`

Turning Pin on/off must not:

- pause timers
- reset timers
- delete tasks
- affect history

Switching Spaces while pinned must not:

- pause, resume, reset, finish, or otherwise mutate any task
- change any task duration or persistence state
- create another timer engine or another floating panel

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
    var continuedFromSessionID: UUID?
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

# 4.6 Simultaneous Running Tasks

Default behavior:

> Multiple unfinished tasks may run simultaneously by default.

Example:

```text
Write report       00:42:18   Running
File export        00:18:32   Running
Data analysis      01:12:05   Running
Reply emails       00:08:10   Paused
```

If the user resumes `Reply emails`:

1. `Reply emails` resumes from its own accumulated duration.
2. Every other running task continues without interruption.

Each task owns independent timing state and derives its duration from its own timestamps.

---

# 4.7 Overlapping Time Semantics

Simultaneous timers are standard product behavior, not an optional mode or future setting.

Future analytics must distinguish:

- **Recorded Task Time:** the sum of each task's active duration
- **Unique Active Time:** the wall-clock union of all active intervals, counting overlaps only once

Example simultaneous use cases:

- background file export
- rendering
- data processing
- human work happening alongside machine processing

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

If other tasks are already running:

- keep existing tasks running
- start the new task independently

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

## 4.14.1 History Selection and Excel Export

History must support selecting one or multiple completed task records.

Selection behavior:

- single click selects one History record
- Command-click adds or removes records from the selection
- Shift-click selects a range where appropriate
- selection uses native macOS visual treatment
- `Export Selected` is disabled when no History record is selected

The user can export only the selected History records.

Primary export format:

- Microsoft Excel `.xlsx`

Optional secondary export format:

- CSV `.csv`

Use the standard macOS save workflow so the user chooses the destination. Export data must remain local and must not be uploaded to a cloud service.

Exported columns:

- Task Name
- Date
- Start Time
- End Time
- Active Duration
- Paused Duration
- Total Elapsed Duration
- Category, if available
- Session ID
- Continued From Session ID, if available

The exported file must open directly in:

- Microsoft Excel
- Apple Numbers

For `.xlsx` export:

- create a real Excel workbook, not a CSV file renamed to `.xlsx`
- include a header row
- use sensible column widths where practical
- use human-readable date, time, and duration values
- preserve raw session identifiers for traceability

Large selections should be exported away from the main UI path where practical so export work does not unnecessarily block interaction.

---

## 4.14.2 History Context Menu

Every completed History record must provide a native macOS right-click context menu with:

- Continue Tracking
- Rename
- Delete

Double-clicking or using an explicit Open action should show History detail.

### Continue Tracking

Continue Tracking resumes the user's work conceptually without mutating historical evidence.

The original completed record is immutable with respect to timing and completion state. Do not convert it back into a running task.

Instead:

1. Keep the original completed History record unchanged.
2. Create a new active `TaskSession` with its own UUID.
3. Inherit the previous task name and category where available.
4. Set `continuedFromSessionID` to the original completed session ID.
5. Initialize the new session's accumulated active duration from the previous session's accumulated active duration.
6. Preserve the relationship for export, detail views, and future analytics.

Example:

```text
Original History
Prepare proposal
Active Duration: 01:20:00
Status: completed

Continued Session
Prepare proposal
Initial displayed active duration: 01:20:00
continuedFromSessionID: <original session ID>
```

Continue Tracking must not:

- pause other running tasks
- reset or modify other tasks
- mutate or delete the original completed record
- modify unrelated History records

Multiple continued sessions from the same completed record are allowed. Each continued session retains a unique UUID and the same lineage reference.

### Rename

Rename edits only the completed record's display name.

Requirements:

- persist the name change immediately
- support duplicate names
- do not modify timestamps, durations, status, session ID, or continuation lineage

### Delete

Delete requires confirmation.

Recommended dialog:

`Delete this history record?`

Actions:

- Cancel
- Delete

Deletion may be permanent in the MVP. A Trash system is not required.

Deleting a History record must:

- remove only the selected completed record
- persist immediately
- not affect active or running tasks
- not affect other completed records

---

## 4.14.3 Continued Task Data Model

Add the following optional field to `TaskSession` and its persisted representation:

```swift
var continuedFromSessionID: UUID?
```

Every session keeps its own unique `id`. Continuing a task must never replace or reuse the original completed session ID.

The lineage field supports traceability, export, History detail, and future analytics without changing the original History record.

---

## 4.14.4 History UX

Recommended native macOS interactions:

- single click: select one History record
- Command-click: multi-select
- Shift-click: range select where appropriate
- right-click: open the History context menu
- double-click or Open: show History detail

History selection should use native macOS list or table behavior and remain visually distinct in Light and Dark Mode.

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
- continuation lineage between sessions
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

For every task that was running:

```text
current duration =
stored active duration
+
now - stored lastResumedAt
```

Do not rely on restoring an in-memory Timer.

All running tasks must restore as running and calculate elapsed time independently. Paused tasks must restore as paused without accruing active duration.

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

# 4.23 History Export Formats

History page primary action:

`Export Selected`

Primary format:

- Excel `.xlsx`

Optional secondary format:

- CSV `.csv`

Only selected completed History records are exported. Follow the selection, workbook, columns, privacy, performance, and standard macOS save requirements in section 4.14.1.

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

`ExportService` should own workbook/CSV generation and file-writing coordination. History views should provide selected session IDs and user intent rather than constructing export files directly.

`TaskStore` or a dedicated History service should own Continue Tracking, Rename, Delete, and completed-record persistence coordination.

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
- operate independently on any `TaskSession` value

The view layer should not own timing logic.

The `TimerEngine` must not contain one global timer shared by all tasks. Collection-level coordination belongs in `TaskStore`, and operations on one session must not mutate another session.

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
- follows the active desktop or full-screen Space only when Pin is enabled
- restores normal managed Space behavior when Pin is disabled
- remains a single retained panel across all Space transitions

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
- continuedFromSessionID

## Settings

Prefer UserDefaults / `@AppStorage` for small preferences.

Examples:

- pin state
- display format
- confirmation settings

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
- Excel or CSV export fails
- a History rename or deletion cannot be persisted
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
- two and three tasks running simultaneously
- pausing, resetting, or finishing one task while others continue
- relaunch recovery with multiple running tasks
- relaunch recovery with mixed running and paused tasks
- overlapping active intervals
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
- History multi-selection and selected-record export
- Continue Tracking preserves the original completed record
- History rename changes only the name
- History delete affects only the chosen completed record
- `.xlsx` output is a valid workbook readable by Excel and Numbers

---

# 15.3 UI Tests

Core flows:

1. Create task.
2. Start timer.
3. Pause.
4. Resume.
5. Finish.
6. Verify history item.
7. Multi-select History records and export the selection.
8. Continue Tracking from History and verify the original remains completed.
9. Rename and delete History records through the context menu.
10. Toggle Pin.
11. Open menu bar.
12. Switch active task.

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
9. Multiple simultaneously running tasks
10. Independent task controls and active task selection
11. History
12. History selection, context actions, and Excel export
13. Menu-bar timer
14. local persistence
15. accurate restart recovery
16. settings basics

Optional for 1.1:

- categories
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
- switching repeatedly between desktop Spaces
- switching between desktop and native full-screen Spaces
- confirming no duplicate timer windows are created
- confirming Space changes do not affect any task timer state

Pin ON:
1. Open Visual Studio Code.
2. Enter native macOS full-screen mode.
3. Switch into the VS Code full-screen Space.
4. FloatingTaskTimer must remain visible above VS Code.
5. Timer controls must remain clickable.
6. The timer must not steal keyboard focus from the VS Code editor unnecessarily.

This behavior must not be implemented as a VS Code-specific hack.
It should come from correct NSPanel / NSWindow configuration and work across normal macOS full-screen applications.

General Space acceptance criteria:

1. Pin ON: switching to any desktop Space keeps the timer visible.
2. Pin ON: entering or switching to a supported full-screen application Space keeps the timer above that application.
3. Pin OFF: the timer returns to normal managed-window behavior and does not follow into other Spaces.
4. Space transitions reuse one panel and never create duplicates.
5. Space transitions never pause, reset, finish, or otherwise alter any task timer.

Commit:

`feat: add floating timer panel`

---

# Phase 6 — Multiple Tasks

Add task list and task switching.

Support:

- any number of unfinished tasks running simultaneously
- independent timing state and controls for every task
- restoration of every running and paused task after relaunch

Commit:

`feat: support multiple task sessions`

---

# Phase 7 — History

Implement:

- basic History persistence
- History list
- History detail

Commit:

`feat: add task history`

---

# Phase 7.1 — History Actions and Export

Implement:

- native History multi-selection
- Continue Tracking with immutable original records and session lineage
- Rename
- confirmed permanent Delete
- selected-record Excel `.xlsx` export
- optional selected-record CSV export

Commit:

`feat: add history actions and excel export`

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

For Excel or CSV export, use user-selected file access via standard save panels rather than broad filesystem permissions.

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
- selected History export produces a valid `.xlsx` workbook
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
- `1.1.0`: categories and other validated productivity improvements
- `1.2.0`: keyboard shortcuts
- `2.0.0`: major sync or platform expansion

---

# 36. Future Roadmap

After product-market validation:

## 1.1

- Categories
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
- multiple tasks can run simultaneously and independently
- all running tasks recover accurately after relaunch
- completed sessions appear in history
- History supports native multi-selection and selection-only Excel export
- History supports Continue Tracking without mutating the original completed record
- History supports persisted Rename and confirmed Delete actions
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
