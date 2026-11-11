# Changelog

Each entry says whether it changed the addon, the app, or both. When only the app changes, the addon download is the same as the version before.

## 1.1.2 (addon and app)

- Drag the grip in the map's bottom-right corner to make it bigger or smaller. The size is saved.
- Drag the fullscreen map by its top bar to slide it left or right on its monitor, so bags and other windows fit beside it. It opens there next time.
- `/fsmreset` also puts the map's size and position back to normal.
- If you plug in, unplug or rearrange a screen, or change your main display, while WoW is running, the app moves WoW to the new layout without a restart. In the world it asks you to type `/reload` so the addon picks up the change.
- To play on another screen, like a TV from the couch, make it your main display in Windows. Screens with different scaling, such as 100% and 150%, no longer stop WoW from stretching.
- Picking a different monitor in WoW's own graphics options no longer throws off the layout. Farsight decides where WoW goes, so the app clears that setting while WoW is closed.

## 1.1.1 (addon and app)

- Item tooltips in bags on a side monitor open on the side with room, so the item and its comparison no longer cover each other.
- Windows that other addons let you drag, like Zygor's minimap icon and guide window, stay where you drop them and snap onto a monitor, instead of drifting after logouts and restarts.
- Damage numbers no longer get smaller after a crash or with two WoWs open. If yours already look too small, type `/console WorldTextScale_v2 1` and reload.
- If WoW resets its window after a graphics hiccup, the app stretches it again right away.
- If WoW is running as administrator, the app tells you instead of doing nothing.

## 1.1.0 (addon only)

- The map stays solid on side monitors while you move. WoW still fades it on your main monitor, where it covers the game.

## 1.0.9 (app only)

- The app starts with Windows from a shortcut in your Startup folder. Windows could skip the startup entry it used before, so WoW opened as a normal window after a restart. Run the new app once and it switches over.

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
