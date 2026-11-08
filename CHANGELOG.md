# Changelog

Each entry says whether it changed the addon, the app, or both. When only the app changes, the addon download is the same as the version before.

## 1.0.8 (app only)

- Multiboxing: Farsight only stretches the first WoW you start. Any WoW you start after it stays a normal window, and your first one stays stretched while the others enter the world or log out. Enter the world on your first WoW before the others.
- WoW windows no longer open as a thin, wide strip. The app clears the stretched window size WoW saves when it closes.

## 1.0.7 (addon only)

- Fixed Farsight tainting Blizzard's code when the map went fullscreen, which could cause errors and blocked actions in combat. The fullscreen map now scales to fit its monitor, so its text and buttons look larger on a monitor bigger than your main one.
- The fullscreen map no longer blacks out your main monitor when you close and reopen it on a side monitor.
- Tooltips stay on the monitor your cursor is on.
- Reagent bags and other single bags can be dragged. If you tried dragging one before and your bags act strangely, run `/fsmreset`.
- Fixed a Lua error when clicking some protected Blizzard frames.

## 1.0.6 (addon only)

- Right-click menus, like the friends list, unit frames and chat names, open at the mouse instead of on another monitor.

## 1.0.5 (addon only)

- Damage and XP numbers are no longer huge. Farsight lowers WoW's `WorldTextScale_v2` setting to match the stretched window while you play, and puts your own value back when you log out or reload.

## 1.0.4 (addon only)

- Dragging no longer picks up hotbars, unit frames or anything else Edit Mode controls. If a hotbar already moved, run `/fsmreset`.

## 1.0.3 (app only)

- Logging out no longer leaves character select stretched across your monitors, so switching characters works properly.
- The app checks your monitors again each time you reach character select.

## 1.0.2 (addon and app)

- Fixed the app crashing while WoW started or closed, which left the game as a plain window on the next launch.
- The app reads your current monitor positions every time.

## 1.0.1 (addon and app)

- The UI is the right size when the game window is taller than it is wide, such as with a monitor stacked above your main one, and when a side monitor is taller than the main one.
- If WoW is already open when the app starts, the app asks you to close WoW and start it again, instead of changing the window.

## 1.0.0

- First release.
