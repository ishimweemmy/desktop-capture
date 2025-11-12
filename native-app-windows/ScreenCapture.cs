using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace DesktopCapture
{
    class ScreenCapture
    {
        // Windows API imports
        [DllImport("user32.dll")]
        private static extern bool GetCursorInfo(out CURSORINFO pci);

        [DllImport("user32.dll")]
        private static extern IntPtr CopyIcon(IntPtr hIcon);

        [DllImport("user32.dll")]
        private static extern bool DrawIcon(IntPtr hdc, int x, int y, IntPtr hIcon);

        [DllImport("user32.dll")]
        private static extern bool DestroyIcon(IntPtr hIcon);

        [StructLayout(LayoutKind.Sequential)]
        private struct CURSORINFO
        {
            public int cbSize;
            public int flags;
            public IntPtr hCursor;
            public Point ptScreenPos;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ICONINFO
        {
            public bool fIcon;
            public int xHotspot;
            public int yHotspot;
            public IntPtr hbmMask;
            public IntPtr hbmColor;
        }

        [DllImport("user32.dll")]
        private static extern bool GetIconInfo(IntPtr hIcon, out ICONINFO pIconInfo);

        [DllImport("gdi32.dll")]
        private static extern bool DeleteObject(IntPtr hObject);

        private const int CURSOR_SHOWING = 0x00000001;

        /// <summary>
        /// Captures all connected displays with cursor visible
        /// </summary>
        public Dictionary<int, Bitmap> CaptureAllDisplays()
        {
            var result = new Dictionary<int, Bitmap>();
            var screens = Screen.AllScreens;

            for (int i = 0; i < screens.Length; i++)
            {
                var screen = screens[i];
                var bitmap = CaptureScreen(screen, i);
                if (bitmap != null)
                {
                    result[i + 1] = bitmap; // 1-indexed display IDs
                }
            }

            return result;
        }

        /// <summary>
        /// Captures a single screen with cursor
        /// </summary>
        private Bitmap? CaptureScreen(Screen screen, int screenIndex)
        {
            try
            {
                var bounds = screen.Bounds;
                var bitmap = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);

                using (var graphics = Graphics.FromImage(bitmap))
                {
                    // Capture the screen
                    graphics.CopyFromScreen(
                        bounds.Left,
                        bounds.Top,
                        0,
                        0,
                        bounds.Size,
                        CopyPixelOperation.SourceCopy
                    );

                    // Draw cursor if it's on this screen
                    DrawCursor(graphics, bounds);
                }

                return bitmap;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Failed to capture screen {screenIndex}: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Draws the system cursor on the graphics object
        /// </summary>
        private void DrawCursor(Graphics graphics, Rectangle screenBounds)
        {
            try
            {
                CURSORINFO cursorInfo = new CURSORINFO();
                cursorInfo.cbSize = Marshal.SizeOf(cursorInfo);

                if (!GetCursorInfo(out cursorInfo))
                {
                    return;
                }

                if ((cursorInfo.flags & CURSOR_SHOWING) == 0)
                {
                    return; // Cursor not visible
                }

                // Check if cursor is on this screen
                if (!screenBounds.Contains(cursorInfo.ptScreenPos))
                {
                    return;
                }

                // Get cursor icon
                IntPtr hicon = CopyIcon(cursorInfo.hCursor);
                if (hicon == IntPtr.Zero)
                {
                    return;
                }

                try
                {
                    ICONINFO iconInfo;
                    if (GetIconInfo(hicon, out iconInfo))
                    {
                        // Calculate cursor position relative to screen
                        int x = cursorInfo.ptScreenPos.X - screenBounds.Left - iconInfo.xHotspot;
                        int y = cursorInfo.ptScreenPos.Y - screenBounds.Top - iconInfo.yHotspot;

                        // Draw the cursor
                        IntPtr hdc = graphics.GetHdc();
                        try
                        {
                            DrawIcon(hdc, x, y, hicon);
                        }
                        finally
                        {
                            graphics.ReleaseHdc(hdc);
                        }

                        // Clean up icon info bitmaps
                        if (iconInfo.hbmColor != IntPtr.Zero)
                            DeleteObject(iconInfo.hbmColor);
                        if (iconInfo.hbmMask != IntPtr.Zero)
                            DeleteObject(iconInfo.hbmMask);
                    }
                }
                finally
                {
                    DestroyIcon(hicon);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Failed to draw cursor: {ex.Message}");
            }
        }
    }
}
