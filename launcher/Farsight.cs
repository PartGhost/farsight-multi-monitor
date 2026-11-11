using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

static class Farsight
{
	const string Title = "Farsight";
	const string AddonFolder = @"Interface\AddOns\FarsightMultiMonitor";
	const string LayoutFile = AddonFolder + @"\Layout.lua";
	const string InstallKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft";
	const string InstallLocationValue = "InstallLocation";
	const string GamePattern = "Wow*.exe";
	const string ConfigFile = @"WTF\Config.wtf";
	const string EnterWorldMarker = @"WTF\SavedVariables\Blizzard_GlueSavedVariables.lua";
	const string AccountsFolder = @"WTF\Account";
	const string CharacterListFile = "character-list-order.txt";
	const string WindowedSetting = "SET GxMaximize \"0\"";
	const string StartupKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
	const int MaxWindowSize = 16384;
	const int MaxPathLength = 32767;
	const double SplitMinAspect = 3.0;
	const int GameAspectWidth = 16;
	const int GameAspectHeight = 9;

	static readonly string InstalledPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), Title, Title + ".exe");
	static readonly string StartupShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), Title + ".lnk");
	static readonly Regex MaximizeSetting = new Regex("^SET GxMaximize \"\\d\"", RegexOptions.Multiline | RegexOptions.IgnoreCase);
	static readonly Regex PlacementSettings = new Regex("^SET Gx(WindowedResolution|Monitor) \"[^\"]*\"\\r?\\n?", RegexOptions.Multiline | RegexOptions.IgnoreCase);

	static readonly TimeSpan SettleTimeout = TimeSpan.FromSeconds(20);
	static readonly TimeSpan SettledAfter = TimeSpan.FromSeconds(3);
	static readonly TimeSpan PollInterval = TimeSpan.FromMilliseconds(500);
	static readonly TimeSpan IdleInterval = TimeSpan.FromSeconds(2);

	const int GWL_STYLE = -16;
	const long WS_MAXIMIZE = 0x01000000;
	const long WS_CAPTION = 0x00C00000;
	const long WS_THICKFRAME = 0x00040000;
	const long Decorations = WS_MAXIMIZE | WS_CAPTION | WS_THICKFRAME;
	const int GWL_EXSTYLE = -20;
	const long WS_EX_TOOLWINDOW = 0x00000080;
	const long WS_EX_TOPMOST = 0x00000008;
	const uint SWP_NOSIZE = 0x0001;
	const uint SWP_NOMOVE = 0x0002;
	const uint SWP_NOZORDER = 0x0004;
	const uint SWP_NOACTIVATE = 0x0010;
	const uint SWP_FRAMECHANGED = 0x0020;
	const uint SWP_NOSENDCHANGING = 0x0400;
	const uint GW_OWNER = 4;
	const uint EVENT_SYSTEM_FOREGROUND = 3;
	const uint WINEVENT_OUTOFCONTEXT = 0;
	const int DWMWA_CLOAKED = 14;
	const uint MONITOR_DEFAULTTOPRIMARY = 1;
	const uint MONITOR_DEFAULTTONEAREST = 2;
	const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
	static readonly IntPtr PerMonitorAwareV2 = new IntPtr(-4);
	static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
	static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
	static readonly string[] DesktopClasses = { "Progman", "WorkerW" };

	delegate void ForegroundCallback(IntPtr hook, uint eventType, IntPtr window, int objectId, int childId, uint thread, uint time);
	delegate bool WindowCallback(IntPtr window, IntPtr parameter);
	delegate bool MonitorCallback(IntPtr monitor, IntPtr dc, ref RECT bounds, IntPtr parameter);

	static readonly ForegroundCallback OnForeground = HandleForeground;
	static IntPtr spannedWindow;

	[StructLayout(LayoutKind.Sequential)]
	struct RECT
	{
		public int Left, Top, Right, Bottom;
	}

	[StructLayout(LayoutKind.Sequential)]
	struct MONITORINFO
	{
		public int Size;
		public RECT Monitor, Work;
		public uint Flags;
	}

	[DllImport("user32.dll")]
	static extern bool SetProcessDpiAwarenessContext(IntPtr context);

	[DllImport("user32.dll")]
	static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

	[DllImport("user32.dll")]
	static extern IntPtr SetWindowLongPtr(IntPtr window, int index, IntPtr value);

	[DllImport("user32.dll")]
	static extern bool GetWindowRect(IntPtr window, out RECT rect);

	[DllImport("user32.dll")]
	static extern bool SetWindowPos(IntPtr window, IntPtr insertAfter, int x, int y, int width, int height, uint flags);

	[DllImport("user32.dll")]
	static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr module, ForegroundCallback callback, uint process, uint thread, uint flags);

	[DllImport("user32.dll")]
	static extern bool EnumWindows(WindowCallback callback, IntPtr parameter);

	[DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
	static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder name, ref int length);

	[DllImport("kernel32.dll")]
	static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

	[DllImport("kernel32.dll")]
	static extern bool CloseHandle(IntPtr handle);

	[DllImport("user32.dll")]
	static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorCallback callback, IntPtr parameter);

	[DllImport("user32.dll")]
	static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

	[DllImport("user32.dll")]
	static extern IntPtr MonitorFromPoint(Point point, uint flags);

	[DllImport("user32.dll")]
	static extern IntPtr MonitorFromRect(ref RECT rect, uint flags);

	[DllImport("user32.dll")]
	static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);

	[DllImport("user32.dll")]
	static extern bool IsWindowVisible(IntPtr window);

	[DllImport("user32.dll")]
	static extern bool IsIconic(IntPtr window);

	[DllImport("user32.dll")]
	static extern IntPtr GetWindow(IntPtr window, uint command);

	[DllImport("user32.dll", CharSet = CharSet.Unicode)]
	static extern int GetClassName(IntPtr window, StringBuilder name, int capacity);

	[DllImport("dwmapi.dll")]
	static extern int DwmGetWindowAttribute(IntPtr window, int attribute, out int value, int size);

	[STAThread]
	static void Main()
	{
		SetProcessDpiAwarenessContext(PerMonitorAwareV2);

		if (!string.Equals(Application.ExecutablePath, InstalledPath, StringComparison.OrdinalIgnoreCase))
		{
			Install();
			return;
		}

		bool firstInstance;
		using (new Mutex(true, Title, out firstInstance))
		{
			if (!firstInstance)
				return;
			AddToStartup();
			new Thread(WatchForeground) { IsBackground = true }.Start();
			if (RunningGames().Any())
				new Thread(() => Tell("Close WoW and start it again so Farsight can set it up.")) { IsBackground = true }.Start();
			while (true)
				RunSession();
		}
	}

	static void Install()
	{
		var self = Process.GetCurrentProcess().Id;
		foreach (var running in Process.GetProcessesByName(Title).Where(process => process.Id != self))
		{
			running.Kill();
			running.WaitForExit();
		}
		Directory.CreateDirectory(Path.GetDirectoryName(InstalledPath));
		File.WriteAllBytes(InstalledPath, File.ReadAllBytes(Application.ExecutablePath));
		Process.Start(InstalledPath);
		Tell(GameDirs().Any()
			? "Farsight is set up. Start WoW as usual. You can delete this download."
			: "Farsight is set up, but it can't find WoW with the Farsight Multi-Monitor addon installed. Install the addon and it will pick it up.");
	}

	static void AddToStartup()
	{
		using (var key = Registry.CurrentUser.OpenSubKey(StartupKey, true))
			key.DeleteValue(Title, false);
		dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
		var shortcut = shell.CreateShortcut(StartupShortcut);
		shortcut.TargetPath = InstalledPath;
		shortcut.Save();
	}

	static string[] GameDirs()
	{
		using (var machine = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry32))
		using (var install = machine.OpenSubKey(InstallKey))
		{
			var root = install == null ? null : install.GetValue(InstallLocationValue) as string;
			if (!Directory.Exists(root))
				return new string[0];
			return Directory.GetDirectories(root).Where(dir => Directory.Exists(Path.Combine(dir, AddonFolder))).ToArray();
		}
	}

	static void WatchForeground()
	{
		SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, OnForeground, 0, 0, WINEVENT_OUTOFCONTEXT);
		Application.Run();
	}

	static void HandleForeground(IntPtr hook, uint eventType, IntPtr window, int objectId, int childId, uint thread, uint time)
	{
		if (window == Volatile.Read(ref spannedWindow))
			RaiseSideWindows(window);
	}

	static void RaiseSideWindows(IntPtr game)
	{
		var primary = MonitorFromPoint(Point.Empty, MONITOR_DEFAULTTOPRIMARY);
		var sideWindows = new System.Collections.Generic.List<IntPtr>();
		EnumWindows((window, parameter) =>
		{
			if (window != game && IsAppWindow(window) && MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST) != primary)
				sideWindows.Add(window);
			return true;
		}, IntPtr.Zero);
		sideWindows.Reverse();
		foreach (var window in sideWindows)
		{
			SetWindowPos(window, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
			SetWindowPos(window, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
		}
	}

	static Rectangle[] MonitorBounds()
	{
		var monitors = new System.Collections.Generic.List<Rectangle>();
		EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr monitor, IntPtr dc, ref RECT bounds, IntPtr parameter) =>
		{
			monitors.Add(Rectangle.FromLTRB(bounds.Left, bounds.Top, bounds.Right, bounds.Bottom));
			return true;
		}, IntPtr.Zero);
		return monitors.ToArray();
	}

	static Rectangle PrimaryBounds(Rectangle[] monitors)
	{
		return monitors.First(monitor => monitor.Location == Point.Empty);
	}

	static bool IsAppWindow(IntPtr window)
	{
		if (!IsWindowVisible(window) || IsIconic(window) || GetWindow(window, GW_OWNER) != IntPtr.Zero)
			return false;
		var exStyle = GetWindowLongPtr(window, GWL_EXSTYLE).ToInt64();
		if ((exStyle & (WS_EX_TOOLWINDOW | WS_EX_TOPMOST)) != 0)
			return false;
		int cloaked;
		if (DwmGetWindowAttribute(window, DWMWA_CLOAKED, out cloaked, sizeof(int)) == 0 && cloaked != 0)
			return false;
		var className = new StringBuilder(64);
		GetClassName(window, className, className.Capacity);
		return !DesktopClasses.Contains(className.ToString());
	}

	static void HoldUntilLogout(Process game, string gameDir, string account, Rectangle[] monitors, Rectangle span)
	{
		Volatile.Write(ref spannedWindow, game.MainWindowHandle);
		RaiseSideWindows(game.MainWindowHandle);
		var characterList = CharacterListWritten(gameDir, account);
		while (!game.HasExited && CharacterListWritten(gameDir, account) == characterList)
		{
			if (MonitorsChanged(ref monitors))
			{
				span = WriteLayout(gameDir, monitors);
				new Thread(() => Tell("Your screens changed, so Farsight stretched WoW over the new layout. Type /reload in WoW to finish.")) { IsBackground = true }.Start();
			}
			if (!IsPlaced(game.MainWindowHandle, span) && !Settle(game, span))
				TellResizing();
			Thread.Sleep(PollInterval);
		}
		Volatile.Write(ref spannedWindow, IntPtr.Zero);
	}

	static bool MonitorsChanged(ref Rectangle[] monitors)
	{
		var current = MonitorBounds();
		if (current.SequenceEqual(monitors))
			return false;
		Thread.Sleep(SettledAfter);
		if (!MonitorBounds().SequenceEqual(current))
			return false;
		monitors = current;
		return true;
	}

	static DateTime CharacterListWritten(string gameDir, string account)
	{
		return File.GetLastWriteTimeUtc(Path.Combine(gameDir, AccountsFolder, account, CharacterListFile));
	}

	static string EnteredAccount(string gameDir, string account, DateTime since)
	{
		if (File.GetLastWriteTimeUtc(Path.Combine(gameDir, EnterWorldMarker)) <= since)
			return null;
		return Directory.GetDirectories(Path.Combine(gameDir, AccountsFolder))
			.Select(Path.GetFileName)
			.Where(name => account == null || name == account)
			.FirstOrDefault(name => CharacterListWritten(gameDir, name) > since);
	}

	static void RunSession()
	{
		foreach (var running in RunningGames())
			running.WaitForExit();
		string gameDir;
		var game = FindGame(out gameDir);
		while (game == null)
		{
			foreach (var dir in GameDirs())
				SetWindowed(dir);
			Thread.Sleep(IdleInterval);
			game = FindGame(out gameDir);
		}
		if (!CanControl(game))
		{
			Tell("WoW is running as administrator, so Farsight can't move its window. Close WoW and start it again without administrator rights.");
			game.WaitForExit();
			return;
		}
		string account = null;
		while (!game.HasExited)
			account = PlayOnce(game, gameDir, account);
	}

	static string WithWindowedSetting(string config)
	{
		var boxed = PlacementSettings.Replace(config, "");
		return MaximizeSetting.IsMatch(boxed) ? MaximizeSetting.Replace(boxed, WindowedSetting) : boxed + WindowedSetting + "\n";
	}

	static void SetWindowed(string gameDir)
	{
		var configPath = Path.Combine(gameDir, ConfigFile);
		if (!File.Exists(configPath))
			return;
		try
		{
			var config = File.ReadAllText(configPath);
			var windowed = WithWindowedSetting(config);
			if (windowed != config)
				File.WriteAllText(configPath, windowed);
		}
		catch (IOException)
		{
			return;
		}
	}

	static string PlayOnce(Process game, string gameDir, string account)
	{
		var monitors = MonitorBounds();
		var span = WriteLayout(gameDir, monitors);
		var since = DateTime.UtcNow;

		if (!Settle(game, PrimaryBounds(monitors)))
			TellResizing();

		string entered = null;
		while (!game.HasExited && entered == null)
		{
			Thread.Sleep(PollInterval);
			if (MonitorsChanged(ref monitors))
			{
				span = WriteLayout(gameDir, monitors);
				if (!Settle(game, PrimaryBounds(monitors)))
					TellResizing();
			}
			entered = EnteredAccount(gameDir, account, since);
		}
		if (entered == null)
			return account;

		if (!Settle(game, span))
			TellResizing();
		HoldUntilLogout(game, gameDir, entered, monitors, span);
		return entered;
	}

	static void TellResizing()
	{
		Tell("WoW keeps resizing its window. Set Display Mode to Windowed in the graphics options.");
	}

	static void Tell(string message)
	{
		MessageBox.Show(message, Title, MessageBoxButtons.OK, MessageBoxIcon.Information, MessageBoxDefaultButton.Button1, MessageBoxOptions.DefaultDesktopOnly);
	}

	static Rectangle WriteLayout(string gameDir, Rectangle[] monitors)
	{
		Rectangle window;
		var text = BuildLayout(monitors, PrimaryBounds(monitors), out window);
		File.WriteAllText(Path.Combine(gameDir, LayoutFile), text);
		return window;
	}

	static string BuildLayout(Rectangle[] screens, Rectangle primary, out Rectangle window)
	{
		var monitors = CoveredMonitors(screens, primary);
		var main = primary;
		var split = monitors.Length == 1 && (double)primary.Width / primary.Height >= SplitMinAspect;
		if (split)
		{
			var gameWidth = primary.Height * GameAspectWidth / GameAspectHeight;
			var sideWidth = (primary.Width - gameWidth) / 2;
			main = new Rectangle(primary.X + sideWidth, primary.Y, gameWidth, primary.Height);
			monitors = new[]
			{
				new Rectangle(primary.X, primary.Y, sideWidth, primary.Height),
				main,
				Rectangle.FromLTRB(main.Right, primary.Top, primary.Right, primary.Bottom),
			};
		}
		window = WindowBounds(monitors, main);

		var ordered = monitors.OrderBy(monitor => monitor.X).ThenBy(monitor => monitor.Y).ToArray();
		var text = new StringBuilder();
		text.Append("local _, ns = ...\n\n");
		text.Append("ns.layout = {\n");
		text.AppendFormat("\twidth = {0},\n", window.Width);
		text.AppendFormat("\theight = {0},\n", window.Height);
		text.AppendFormat("\tmain = {0},\n", Array.IndexOf(ordered, main) + 1);
		if (split)
			text.Append("\tsplit = true,\n");
		text.Append("\tmonitors = {\n");
		foreach (var monitor in ordered)
			text.AppendFormat("\t\t{{ x = {0}, y = {1}, width = {2}, height = {3} }},\n", monitor.X - window.X, monitor.Y - window.Y, monitor.Width, monitor.Height);
		text.Append("\t},\n");
		text.Append("}\n");
		return text.ToString();
	}

	static Rectangle[] CoveredMonitors(Rectangle[] screens, Rectangle main)
	{
		var covered = main;
		var result = new System.Collections.Generic.List<Rectangle> { main };
		foreach (var screen in screens.Where(screen => screen != main).OrderBy(screen => DistanceSquared(screen, main)))
		{
			var grown = Rectangle.Union(covered, screen);
			if (grown.Width > MaxWindowSize || grown.Height > MaxWindowSize)
				continue;
			covered = grown;
			result.Add(screen);
		}
		return result.ToArray();
	}

	static long DistanceSquared(Rectangle a, Rectangle b)
	{
		long deltaX = a.X + a.Width / 2 - (b.X + b.Width / 2);
		long deltaY = a.Y + a.Height / 2 - (b.Y + b.Height / 2);
		return deltaX * deltaX + deltaY * deltaY;
	}

	static Rectangle WindowBounds(Rectangle[] monitors, Rectangle main)
	{
		var union = monitors.Aggregate(Rectangle.Union);
		var centerX = main.X + main.Width / 2;
		var centerY = main.Y + main.Height / 2;
		var halfWidth = Math.Max(centerX - union.Left, union.Right - centerX);
		var halfHeight = Math.Max(centerY - union.Top, union.Bottom - centerY);
		if (halfWidth * 2 > MaxWindowSize || halfHeight * 2 > MaxWindowSize)
			return union;
		return new Rectangle(centerX - halfWidth, centerY - halfHeight, halfWidth * 2, halfHeight * 2);
	}

	static Process[] GamesIn(string dir)
	{
		return Directory.GetFiles(dir, GamePattern)
			.SelectMany(path => Process.GetProcessesByName(Path.GetFileNameWithoutExtension(path)).Where(process => RunsFrom(process, path)))
			.Where(process => process.MainWindowHandle != IntPtr.Zero)
			.ToArray();
	}

	static Process[] RunningGames()
	{
		return GameDirs().SelectMany(GamesIn).ToArray();
	}

	static Process FindGame(out string gameDir)
	{
		foreach (var dir in GameDirs())
		{
			var game = GamesIn(dir).FirstOrDefault();
			if (game != null)
			{
				gameDir = dir;
				return game;
			}
		}
		gameDir = null;
		return null;
	}

	static bool RunsFrom(Process process, string path)
	{
		var handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, process.Id);
		if (handle == IntPtr.Zero)
			return false;
		var image = new StringBuilder(MaxPathLength);
		var length = image.Capacity;
		var matches = QueryFullProcessImageName(handle, 0, image, ref length) && string.Equals(image.ToString(), path, StringComparison.OrdinalIgnoreCase);
		CloseHandle(handle);
		return matches;
	}

	static bool CanControl(Process game)
	{
		try
		{
			return game.Handle != IntPtr.Zero;
		}
		catch (Win32Exception)
		{
			return false;
		}
	}

	static bool Settle(Process game, Rectangle bounds)
	{
		var window = game.MainWindowHandle;
		var total = Stopwatch.StartNew();
		var settled = Stopwatch.StartNew();
		while (total.Elapsed < SettleTimeout)
		{
			if (game.HasExited)
				return true;
			if (!IsPlaced(window, bounds))
			{
				Place(window, bounds);
				settled.Restart();
			}
			else if (settled.Elapsed >= SettledAfter)
			{
				return true;
			}
			Thread.Sleep(PollInterval);
		}
		return false;
	}

	static bool IsPlaced(IntPtr window, Rectangle bounds)
	{
		RECT rect;
		GetWindowRect(window, out rect);
		var style = GetWindowLongPtr(window, GWL_STYLE).ToInt64();
		return (style & Decorations) == 0 && Rectangle.FromLTRB(rect.Left, rect.Top, rect.Right, rect.Bottom) == bounds;
	}

	static void Place(IntPtr window, Rectangle bounds)
	{
		var style = GetWindowLongPtr(window, GWL_STYLE).ToInt64();
		SetWindowLongPtr(window, GWL_STYLE, new IntPtr(style & ~Decorations));
		var rect = new RECT { Left = bounds.Left, Top = bounds.Top, Right = bounds.Right, Bottom = bounds.Bottom };
		var owner = MonitorFromRect(ref rect, MONITOR_DEFAULTTONEAREST);
		if (MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST) != owner)
		{
			var info = new MONITORINFO { Size = Marshal.SizeOf(typeof(MONITORINFO)) };
			GetMonitorInfo(owner, ref info);
			rect = info.Monitor;
		}
		SetWindowPos(window, IntPtr.Zero, rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top, SWP_NOZORDER | SWP_FRAMECHANGED | SWP_NOSENDCHANGING);
	}
}
