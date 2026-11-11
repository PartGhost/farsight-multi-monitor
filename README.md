# Farsight Multi-Monitor

Keeps World of Warcraft on your main monitor and lets you drag your map, bags and other panels onto your other monitors. There's nothing to calibrate.

It has two parts:

- **The addon** handles the panels. It's on CurseForge as Farsight Multi-Monitor.
- **The app** resizes the game window, which addons can't do. It's a separate download.

## Install

1. Install the addon.
2. Close WoW.
3. Download [Farsight.exe](https://github.com/PartGhost/farsight-multi-monitor/releases/latest/download/Farsight.exe) and run it once. You can delete the download afterwards.
4. Start WoW as usual.

The app isn't code-signed, so Windows SmartScreen may warn you the first time. Choose **More info**, then **Run anyway**, or build it yourself from this source.

## What the app does

- Copies itself to `%LOCALAPPDATA%\Farsight`, starts with Windows from a shortcut in your Startup folder, and waits in the background for WoW to open.
- Finds WoW from the install location Battle.net saves in the Windows registry, and only touches game versions that have the addon.
- Sets the game's display mode to Windowed in `WTF\Config.wtf`, and clears the saved window size and monitor choice there.
- Resizes the game window across your monitors and removes the title bar.
- Writes your monitor layout to `Layout.lua` in the addon's folder, and again whenever your monitors change while WoW is open.
- Raises apps on your side monitors above the game when you click into WoW.

It doesn't read or change the game's memory, send key presses or mouse clicks, automate anything or use the internet.

## Use at your own risk

Blizzard hasn't reviewed or approved this app. Their terms restrict third-party software, and it does change the game's window, so there's a chance it could put your account at risk. Please decide for yourself whether you're comfortable with that.

## Commands

- `/fsm` shows the help window.
- `/fsmreset` clears your saved panel positions for your current monitor setup, and puts the map's size and position back to normal.
- `/fsmwide` turns Widescreen on or off, the same as the minimap panel.

The minimap button opens a panel with Widescreen and a choice of which monitor holds the game.

The panel's fonts are Cinzel and Figtree, under the SIL Open Font License (see `FarsightMultiMonitor/Fonts`).

## Uninstall

1. Close WoW.
2. End Farsight in Task Manager.
3. Delete the Farsight shortcut from your Startup folder. Press Win+R and enter `shell:startup` to open it.
4. Delete the `%LOCALAPPDATA%\Farsight` folder and uninstall the addon.
5. In WoW, go back to your preferred display mode in the graphics settings.

## Build

Needs Windows and the .NET Framework that ships with it. This copies the addon into your `AddOns` folder and builds the app to `dist\Farsight.exe`:

```powershell
.\build.ps1 -AddOns "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
```
