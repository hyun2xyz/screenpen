# ScreenPen Design

## Goal

Build a personal macOS menu bar app for live online lectures. The app lets the presenter draw directly over the screen, use a translucent highlighter, dim everything except a focus area, and open an experimental cursor-following magnifier.

## Product Direction

ScreenPen should feel closer to DemoPro than to a full drawing app: fast hotkeys, minimal visible UI, and no lecture-disrupting panels. The first version is for one local user, so stability and speed matter more than preferences sync, App Store packaging, or polished onboarding.

## Competitive Notes

- Presentify combines annotation, cursor highlight, spotlight, zoom, colors, shapes, auto erase, and keyboard shortcuts.
- DemoPro emphasizes no-clutter presenter use, auto-fade annotations, whiteboard mode, and press-and-hold activation.
- Cursor Pro focuses on cursor highlight and a high-quality magnifier.

ScreenPen's first version should copy the workflow lesson, not the whole feature set: hotkey-driven annotation with a small menu bar control surface.

## MVP Scope

- Menu bar app with no Dock icon.
- Transparent always-on-top overlay on every visible screen.
- Pen and highlighter tools.
- Stroke undo and clear all.
- Spotlight mode that dims the screen except around the cursor.
- Experimental magnifier mode that follows the cursor and zooms the pixels under it.
- Global hotkeys when Accessibility permission is granted, plus menu items as fallback.

## Out Of Scope For First Version

- App Store distribution.
- Custom preferences window.
- Shape tools, text labels, arrows, whiteboard, recording, cloud sync.
- Multi-user collaboration.
- A polished icon set.

## Architecture

The project is a Swift Package with a small testable core library and an AppKit executable.

- `ScreenPenCore` owns drawing state, tools, strokes, colors, commands, and hotkey mapping.
- `ScreenPen` owns AppKit windows, menu bar status item, global key monitoring, and rendering.
- UI state changes flow through a single `AppState` object so menu items, hotkeys, and overlay views stay in sync.

## macOS Permissions

Global keyboard monitoring needs Accessibility trust. The app will request it with the system prompt and keep working through menu items if permission is not granted.

The magnifier needs screen capture access on modern macOS. The first version treats magnifier capture as best effort: if screen pixels cannot be captured, the magnifier frame still appears with a permission/status message instead of crashing.

## Testing

Automated tests cover the core model: stroke lifecycle, undo/clear, tool defaults, and hotkey mapping. AppKit overlay behavior is verified by building and running the app locally, because transparent system-level windows are difficult to test headlessly.
