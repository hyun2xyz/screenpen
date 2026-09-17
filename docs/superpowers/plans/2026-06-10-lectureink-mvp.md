# ScreenPen MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable macOS menu bar app for live screen annotation.

**Architecture:** A Swift Package contains a testable `ScreenPenCore` library and an AppKit executable. Core state is tested with `swift test`; AppKit behavior is verified with `swift build` and manual launch.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, CoreGraphics, ApplicationServices.

---

### Task 1: Package And Core Model

**Files:**
- Create: `Package.swift`
- Create: `Sources/ScreenPenCore/DrawingModels.swift`
- Create: `Tests/ScreenPenCoreTests/DrawingStoreTests.swift`

- [ ] Write failing tests for stroke lifecycle, undo, clear, tool defaults, and hotkey mapping.
- [ ] Run `swift test` and confirm the tests fail because the core model does not exist.
- [ ] Implement the minimal model in `ScreenPenCore`.
- [ ] Run `swift test` and confirm the model tests pass.

### Task 2: AppKit Shell

**Files:**
- Create: `Sources/ScreenPen/main.swift`
- Create: `Sources/ScreenPen/AppDelegate.swift`
- Create: `Sources/ScreenPen/AppState.swift`

- [ ] Add a no-Dock menu bar app shell.
- [ ] Add status menu items for pen, highlighter, spotlight, magnifier, undo, clear, and quit.
- [ ] Run `swift build` and confirm the executable compiles.

### Task 3: Overlay Rendering

**Files:**
- Create: `Sources/ScreenPen/OverlayWindow.swift`
- Create: `Sources/ScreenPen/OverlayView.swift`
- Modify: `Sources/ScreenPen/AppDelegate.swift`

- [ ] Create one transparent overlay window per screen.
- [ ] Render stored pen and highlighter strokes.
- [ ] Toggle mouse passthrough depending on whether a drawing tool is active.
- [ ] Run `swift build` and launch `swift run ScreenPen`.

### Task 4: Hotkeys And Focus Tools

**Files:**
- Create: `Sources/ScreenPen/GlobalHotKeyMonitor.swift`
- Create: `Sources/ScreenPen/MagnifierSupport.swift`
- Modify: `Sources/ScreenPen/AppState.swift`
- Modify: `Sources/ScreenPen/OverlayView.swift`

- [ ] Add global/local key monitoring for core commands.
- [ ] Add spotlight rendering around the cursor.
- [ ] Add experimental magnifier capture and render fallback text if capture is unavailable.
- [ ] Run `swift test` and `swift build`.

### Task 5: Local Run Notes

**Files:**
- Create: `README.md`

- [ ] Document launch command, hotkeys, and macOS permissions.
- [ ] Run final verification commands.
