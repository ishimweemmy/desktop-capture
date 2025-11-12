using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace DesktopCapture
{
    class ClickEvent
    {
        public DateTime Timestamp { get; set; }
        public int X { get; set; }
        public int Y { get; set; }
        public string App { get; set; } = "";
        public string WindowTitle { get; set; } = "";
        public string Role { get; set; } = "";
        public string Text { get; set; } = "";
        public string BrowserUrl { get; set; } = "";
        public string DocPath { get; set; } = "";
        public int DisplayId { get; set; }
        public string Source { get; set; } = ""; // "ext" or "os"
    }

    class ClickMonitor
    {
        private readonly UIAutomationHelper uiAutomationHelper;
        private readonly NativeMessaging nativeMessaging;
        private readonly OutputManager outputManager;

        private IntPtr hookId = IntPtr.Zero;
        private LowLevelMouseProc? mouseProc;

        private Dictionary<string, PendingClick> pendingClicks = new Dictionary<string, PendingClick>();

        // Windows API imports
        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

        private const int WH_MOUSE_LL = 14;
        private const int WM_LBUTTONDOWN = 0x0201;

        private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int x;
            public int y;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSLLHOOKSTRUCT
        {
            public POINT pt;
            public uint mouseData;
            public uint flags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        private class PendingClick
        {
            public Point Location { get; set; }
            public DateTime Timestamp { get; set; }
            public string AppName { get; set; } = "";
            public string WindowTitle { get; set; } = "";
            public int DisplayId { get; set; }
        }

        public ClickMonitor(UIAutomationHelper uiAutomationHelper, NativeMessaging nativeMessaging, OutputManager outputManager)
        {
            this.uiAutomationHelper = uiAutomationHelper;
            this.nativeMessaging = nativeMessaging;
            this.outputManager = outputManager;

            // Set callback for native messaging
            nativeMessaging.OnMessageReceived = HandleExtensionMessage;
        }

        public void Start()
        {
            mouseProc = HookCallback;
            hookId = SetHook(mouseProc);

            if (hookId == IntPtr.Zero)
            {
                Console.Error.WriteLine("Failed to set mouse hook. Try running as Administrator.");
            }
        }

        public void Stop()
        {
            if (hookId != IntPtr.Zero)
            {
                UnhookWindowsHookEx(hookId);
            }
        }

        private IntPtr SetHook(LowLevelMouseProc proc)
        {
            using (Process curProcess = Process.GetCurrentProcess())
            using (ProcessModule? curModule = curProcess.MainModule)
            {
                if (curModule != null)
                {
                    return SetWindowsHookEx(WH_MOUSE_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
                }
            }
            return IntPtr.Zero;
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0 && wParam == (IntPtr)WM_LBUTTONDOWN)
            {
                MSLLHOOKSTRUCT hookStruct = Marshal.PtrToStructure<MSLLHOOKSTRUCT>(lParam);
                Point clickPoint = new Point(hookStruct.pt.x, hookStruct.pt.y);

                // Handle click on a background thread to avoid blocking the hook
                ThreadPool.QueueUserWorkItem(_ => HandleClick(clickPoint));
            }

            return CallNextHookEx(hookId, nCode, wParam, lParam);
        }

        private void HandleClick(Point clickPoint)
        {
            DateTime timestamp = DateTime.UtcNow;

            // Get active window and process
            IntPtr hwnd = GetForegroundWindow();
            string appName = GetProcessName(hwnd);
            string windowTitle = GetWindowTitle(hwnd);
            int displayId = GetDisplayId(clickPoint);

            // Check if this is Chrome
            bool isChromeApp = appName.Contains("chrome", StringComparison.OrdinalIgnoreCase);

            if (isChromeApp)
            {
                // Wait for extension response (up to 250ms)
                string clickId = Guid.NewGuid().ToString();
                pendingClicks[clickId] = new PendingClick
                {
                    Location = clickPoint,
                    Timestamp = timestamp,
                    AppName = appName,
                    WindowTitle = windowTitle,
                    DisplayId = displayId
                };

                // Set timeout
                Timer timeoutTimer = null!;
                timeoutTimer = new Timer(_ =>
                {
                    HandleClickTimeout(clickId, clickPoint, timestamp, appName, windowTitle, displayId);
                    timeoutTimer?.Dispose();
                }, null, 250, Timeout.Infinite);
            }
            else
            {
                // Non-Chrome app, use UI Automation immediately
                HandleNonChromeClick(clickPoint, timestamp, appName, windowTitle, displayId);
            }
        }

        private void HandleExtensionMessage(Dictionary<string, object> message)
        {
            if (!message.ContainsKey("x") || !message.ContainsKey("y"))
            {
                return;
            }

            int x = Convert.ToInt32(message["x"]);
            int y = Convert.ToInt32(message["y"]);
            Point clickPoint = new Point(x, y);

            string text = message.ContainsKey("text") ? message["text"].ToString() ?? "" : "";
            string url = message.ContainsKey("url") ? message["url"].ToString() ?? "" : "";
            string role = message.ContainsKey("role") ? message["role"].ToString() ?? "element" : "element";

            // Find matching pending click
            string? matchedClickId = null;
            DateTime now = DateTime.UtcNow;

            foreach (var kvp in pendingClicks)
            {
                var pending = kvp.Value;
                double distance = Math.Sqrt(
                    Math.Pow(pending.Location.X - clickPoint.X, 2) +
                    Math.Pow(pending.Location.Y - clickPoint.Y, 2)
                );
                double timeDiff = (now - pending.Timestamp).TotalSeconds;

                if (distance < 10 && timeDiff < 1.0)
                {
                    matchedClickId = kvp.Key;
                    break;
                }
            }

            if (matchedClickId != null && pendingClicks.TryGetValue(matchedClickId, out var pendingClick))
            {
                pendingClicks.Remove(matchedClickId);

                var clickEvent = new ClickEvent
                {
                    Timestamp = pendingClick.Timestamp,
                    X = clickPoint.X,
                    Y = clickPoint.Y,
                    App = pendingClick.AppName,
                    WindowTitle = pendingClick.WindowTitle,
                    Role = role,
                    Text = text,
                    BrowserUrl = url,
                    DocPath = "",
                    DisplayId = pendingClick.DisplayId,
                    Source = "ext"
                };

                LogClickEvent(clickEvent);
            }
        }

        private void HandleClickTimeout(string clickId, Point clickPoint, DateTime timestamp, string appName, string windowTitle, int displayId)
        {
            if (!pendingClicks.ContainsKey(clickId))
            {
                return; // Already handled by extension
            }

            pendingClicks.Remove(clickId);

            // Extension didn't respond, fall back to UI Automation
            HandleNonChromeClick(clickPoint, timestamp, appName, windowTitle, displayId);
        }

        private void HandleNonChromeClick(Point clickPoint, DateTime timestamp, string appName, string windowTitle, int displayId)
        {
            // Use UI Automation to get element info
            var elementInfo = uiAutomationHelper.GetElementInfo(clickPoint);

            var clickEvent = new ClickEvent
            {
                Timestamp = timestamp,
                X = clickPoint.X,
                Y = clickPoint.Y,
                App = appName,
                WindowTitle = windowTitle,
                Role = elementInfo.Role,
                Text = elementInfo.Text,
                BrowserUrl = "",
                DocPath = elementInfo.DocPath,
                DisplayId = displayId,
                Source = "os"
            };

            LogClickEvent(clickEvent);
        }

        private void LogClickEvent(ClickEvent clickEvent)
        {
            outputManager.LogClick(clickEvent);
            Console.WriteLine($"Click logged: ({clickEvent.X}, {clickEvent.Y}) - {clickEvent.App} - {clickEvent.Source}");
        }

        private string GetProcessName(IntPtr hwnd)
        {
            try
            {
                GetWindowThreadProcessId(hwnd, out uint processId);
                Process process = Process.GetProcessById((int)processId);
                return process.ProcessName;
            }
            catch
            {
                return "Unknown";
            }
        }

        private string GetWindowTitle(IntPtr hwnd)
        {
            const int nChars = 256;
            System.Text.StringBuilder buff = new System.Text.StringBuilder(nChars);
            if (GetWindowText(hwnd, buff, nChars) > 0)
            {
                return buff.ToString();
            }
            return "";
        }

        private int GetDisplayId(Point point)
        {
            var screens = Screen.AllScreens;
            for (int i = 0; i < screens.Length; i++)
            {
                if (screens[i].Bounds.Contains(point))
                {
                    return i + 1; // 1-indexed
                }
            }
            return 1; // Default to primary
        }
    }
}
