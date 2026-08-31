# FloatingTaskTimer

[English](#english) · [简体中文](#简体中文)

## English

A native macOS floating task timer for tracking how long real work actually takes.

FloatingTaskTimer provides a lightweight way to start tasks, measure real elapsed work time, keep timers visible above other apps, run multiple timers simultaneously, review completed history, continue earlier tasks without losing session logs, and export selected history to Excel.

Built with **Swift, SwiftUI, AppKit, and SwiftData**.

> Start a task, see how long it really takes, and remember the result.

### Features

#### Floating timer

- Pin or unpin the timer with Always on Top behavior
- Drag the floating window and remember its position
- Follow the active macOS Space while pinned
- Participate in native full-screen Spaces using auxiliary-window behavior
- Remain available over full-screen apps such as VS Code where macOS window rules permit
- Automatically support Light Mode and Dark Mode

#### Multiple simultaneous timers

Any number of unfinished tasks can run at the same time. Starting or resuming one task never pauses another task. Every task owns independent timestamps, status, active duration, and paused duration.

```text
Write report        00:42:18   Running
Data processing     01:12:05   Running
File export         00:18:32   Running
Reply emails        00:08:10   Paused
```

#### Accurate timestamp-based timing

The timer does not increment a counter once per second. Elapsed time is derived from real timestamps, preserving accuracy through UI delays, app backgrounding, hidden windows, relaunches, force quits, and Mac sleep/wake cycles.

Each task supports **Start**, **Pause**, **Resume**, **Reset**, and **Finish**. Finishing or resetting one task does not affect other running tasks.

#### Window display modes

- **Mini Mode** provides a compact floating timer with essential controls and minimal switching between running tasks.
- **Expanded Mode** shows the full task list, controls, History, and navigation.
- **Native Full Screen** uses the standard macOS full-screen transition.

Mode changes preserve timers and Pin state. Mini Mode remembers its manually moved position, defaults near the active screen’s top-right corner, and repairs invalid off-screen positions.

#### History and continued tracking

Completed sessions are stored locally and grouped by a stable `taskGroupID`, not merely by task name. History shows the task name, last activity, total active duration, total paused duration, and session count.

A completed task can be continued later. Continued work creates a new underlying session while the grouped History row displays the combined total. Raw sessions and continuation lineage remain preserved.

History supports:

- Continue Tracking
- Rename
- View Log
- Delete
- Multiple selection and bulk deletion

The session log includes dates, start and finish times, active and paused duration, session IDs, and continuation lineage when available.

#### Excel export

Selected History groups can be exported to a real `.xlsx` workbook containing two worksheets:

- **Tasks** — one row per logical task group, including totals, session count, last activity, and Task Group ID.
- **Sessions** — one row per underlying session, including Session ID, continuation ID, timestamps, active duration, and paused duration.

Exports remain local and are written only to a location selected by the user. The resulting workbook is designed for Microsoft Excel and Apple Numbers.

#### Menu Bar and Settings

The native menu bar interface can display the current duration and provides task controls, quick creation, and shortcuts to the floating timer, History, and Settings. It shares the same `TaskStore` and timer state as the floating window.

Settings include Always on Top defaults, reset and History deletion confirmations, System/Light/Dark appearance, seconds and timer formatting, and menu bar display modes. All settings are stored locally.

### Privacy

- No account or login
- No cloud backend or CloudKit
- No analytics SDK or hidden telemetry
- No task or History uploads
- Local SwiftData persistence
- User-selected local destinations for Excel exports

### Tech stack

- Swift, SwiftUI, AppKit, and SwiftData
- XCTest / Swift Testing
- OSLog and native macOS frameworks
- No third-party runtime dependency in the core application

### Architecture

Timing, task coordination, persistence, window management, settings, export, and UI are separated:

```text
FloatingTaskTimer/
├── Models/
├── Persistence/
├── Services/
│   ├── TimerEngine.swift
│   ├── TaskStore.swift
│   ├── TaskSessionStore.swift
│   ├── WindowManager.swift
│   ├── SettingsStore.swift
│   └── ExportService.swift
├── Views/
│   ├── Floating/
│   ├── History/
│   ├── MenuBar/
│   └── Settings/
├── Utilities/
└── Tests/
```

`TimerEngine` operates on individual `TaskSession` values. `TaskStore` coordinates the task collection without enforcing a single-running-task rule. SwiftUI may refresh periodically, but it never owns elapsed-time calculations.

### Requirements and build

- macOS 14.0 or later
- Xcode and its bundled Swift toolchain

The deployment target is macOS 14.0.

```bash
git clone git@github.com:ScarlettWang88/TaskTimer.git
cd TaskTimer
open FloatingTaskTimer/FloatingTaskTimer.xcodeproj
```

Select the `FloatingTaskTimer` scheme and your Mac, then press `Command + R`.

### Tests

The suite covers timer transitions, simultaneous timers, persistence and restart recovery, migration, grouped History, continued tracking, Excel generation, settings, and window management. Run it in Xcode with `Command + U`.

UI tests use an isolated in-memory database and isolated preferences, so they do not access the user’s production data.

### Project status

The core app is functional and under active development. Release hardening, production signing, notarization, accessibility QA, and distribution preparation remain in progress.

Potential future work includes Launch at Login, global keyboard shortcuts, richer analytics, weekly summaries, task templates, optional iCloud sync, and companion apps. These are not part of the current core release.

### Contributing

Issues and non-commercial contributions are welcome. Please open an issue before proposing large architectural changes. Contributions are governed by the repository license.

### License

Copyright (c) 2026 whywhy.

This project is source-available for personal, educational, academic, research, evaluation, and other non-commercial use. Commercial use—including sale, paid redistribution, paid SaaS or hosting, integration into commercial products, and monetized derivative products—requires prior written permission.

See [LICENSE](LICENSE) for the complete **Non-Commercial Software License v1.0**.

The software is provided “as is,” without warranty. See the license for the complete warranty disclaimer and limitation of liability.

---

## 简体中文

一款原生 macOS 悬浮任务计时器，用来记录实际工作究竟花了多长时间。

FloatingTaskTimer 提供轻量、直观的计时方式：创建任务、记录真实工作时长、让计时器悬浮在其他应用上方、同时运行多个计时器、查看已完成历史、继续跟踪过去的任务并保留每次会话记录，以及把选中的历史数据导出到 Excel。

项目使用 **Swift、SwiftUI、AppKit 和 SwiftData** 构建。

> 开始一项任务，看清它实际花了多久，并把结果保存下来。

### 功能

#### 悬浮计时器

- 通过 Pin 开关启用或关闭“始终置顶”
- 窗口可拖动，并记住上次位置
- Pin 开启时跟随当前 macOS Space
- 通过辅助窗口行为进入原生全屏 Space
- 在 macOS 窗口规则允许的情况下，显示在 VS Code 等全屏应用上方
- 自动支持浅色和深色模式

#### 多任务同时计时

任意数量的未完成任务都可以同时处于运行状态。开始或恢复一个任务不会暂停其他任务。每个任务都独立保存时间戳、状态、活动时长和暂停时长。

```text
撰写报告            00:42:18   运行中
数据处理            01:12:05   运行中
文件导出            00:18:32   运行中
回复邮件            00:08:10   已暂停
```

#### 基于时间戳的精确计时

计时器不会简单地每秒执行一次计数加一。实际时长由真实时间戳计算，因此在界面延迟、应用进入后台、窗口隐藏、应用重启、强制退出以及 Mac 睡眠/唤醒后仍能保持准确。

每个任务都支持 **开始、暂停、恢复、重置和完成**。完成或重置一个任务不会影响其他正在运行的任务。

#### 窗口显示模式

- **Mini 模式**：尽可能紧凑的悬浮计时器，保留必要控制，并可在运行中的任务之间快速切换。
- **Expanded 模式**：显示完整任务列表、控制按钮、历史和导航。
- **原生全屏**：使用标准 macOS 全屏切换。

切换模式不会暂停或重置计时器，也不会改变 Pin 状态。Mini 模式会记住手动移动后的位置，首次进入时默认靠近当前屏幕右上角，并能修复断开显示器后无效或位于屏幕外的位置。

#### 历史与继续跟踪

已完成会话保存在本机，并通过稳定的 `taskGroupID` 进行逻辑分组，而不是仅根据任务名称合并。历史页面显示任务名称、最后活动时间、总活动时长、总暂停时长和会话数量。

已完成的任务可以稍后继续跟踪。继续跟踪会创建新的底层会话，历史分组行显示合并后的总计，同时保留所有原始会话和继续关系。

历史支持：

- 继续跟踪
- 重命名
- 查看日志
- 删除
- 多选和批量删除

会话日志可显示日期、开始和完成时间、活动与暂停时长、会话 ID，以及可用的继续关系。

#### Excel 导出

可以把选中的历史任务组导出为真正的 `.xlsx` 工作簿，其中包含两个工作表：

- **Tasks**：每个逻辑任务组一行，包含总时长、会话数量、最后活动时间和 Task Group ID。
- **Sessions**：每个底层会话一行，包含 Session ID、来源会话 ID、时间戳、活动时长和暂停时长。

导出完全在本机完成，并且只写入用户选择的位置。生成的工作簿面向 Microsoft Excel 和 Apple Numbers。

#### 菜单栏与设置

原生菜单栏界面可以显示当前计时时长，并提供任务控制、快速创建，以及打开悬浮窗口、历史和设置的入口。菜单栏与悬浮窗口共享同一个 `TaskStore` 和计时状态，不会创建第二套计时器。

设置包括默认始终置顶、重置与删除历史前确认、跟随系统/浅色/深色外观、秒数与时间格式，以及菜单栏显示模式。所有设置都保存在本机。

### 隐私

- 无需账号或登录
- 没有云端后台或 CloudKit
- 没有分析 SDK 或隐藏遥测
- 不上传任务或历史数据
- 使用本地 SwiftData 持久化
- Excel 只导出到用户主动选择的本机位置

### 技术栈

- Swift、SwiftUI、AppKit 和 SwiftData
- XCTest / Swift Testing
- OSLog 和原生 macOS 框架
- 核心应用不依赖第三方运行时库

### 架构

项目把计时、任务协调、持久化、窗口管理、设置、导出和界面职责分开。目录结构参见上方英文部分。

`TimerEngine` 负责单个 `TaskSession` 的计时操作；`TaskStore` 协调整个任务集合，但不会强制只允许一个任务运行。SwiftUI 可以周期性刷新显示，但不负责计算实际经过时间。

### 环境要求与构建

- macOS 14.0 或更高版本
- Xcode 及其自带的 Swift 工具链

当前最低系统版本为 macOS 14.0。

```bash
git clone git@github.com:ScarlettWang88/TaskTimer.git
cd TaskTimer
open FloatingTaskTimer/FloatingTaskTimer.xcodeproj
```

在 Xcode 中选择 `FloatingTaskTimer` Scheme 和本机运行目标，然后按 `Command + R`。

### 测试

测试覆盖计时器状态转换、多任务同时运行、持久化与重启恢复、数据库迁移、历史分组、继续跟踪、Excel 生成、设置和窗口管理。可在 Xcode 中按 `Command + U` 运行。

UI 测试使用隔离的内存数据库和独立偏好设置，不会访问用户的正式数据。

### 项目状态

核心应用功能已经可用，项目仍在持续开发中。发布加固、正式签名、公证、辅助功能人工验收和分发准备仍在进行。

未来可能加入登录时启动、全局快捷键、更丰富的分析、每周汇总、任务模板、可选 iCloud 同步和配套设备应用。这些功能不属于当前核心版本。

### 参与贡献

欢迎提交问题和非商业贡献。较大的架构调整请先创建 Issue。所有贡献均受仓库许可证约束。

### 许可证

Copyright (c) 2026 whywhy.

本项目以源代码可见方式提供，允许个人、教育、学术、研究、评估和其他非商业用途。商业用途——包括销售、付费再分发、付费 SaaS 或托管服务、集成到商业产品，以及商业化衍生产品——必须事先获得书面许可。

完整条款请参阅 [LICENSE](LICENSE) 中的 **Non-Commercial Software License v1.0**。

本软件按“现状”提供，不附带任何保证。完整的免责声明和责任限制以许可证为准。
