# Quick Start Guide - Desktop Capture v0 (Windows)

Get up and running in 5 minutes on Windows 10/11.

## Prerequisites

- Windows 10 or 11
- [.NET 6.0 SDK](https://dotnet.microsoft.com/download/dotnet/6.0) (download and install)
- Google Chrome

## Installation (5 steps)

### 1. Build the App

```cmd
build-windows.bat
```

Press any key when prompted.

### 2. Install Chrome Extension

1. Open Chrome: `chrome://extensions/`
2. Enable "Developer mode" (top-right toggle)
3. Click "Load unpacked"
4. Select the `chrome-extension` folder
5. **Copy the Extension ID** (shown in the extension card)

### 3. Configure Native Messaging

```cmd
install-chrome-host-windows.bat
```

Paste the Extension ID when prompted and press Enter.

### 4. Start Capturing (as Administrator)

**Important**: Right-click `build-windows\DesktopCapture.exe` → "Run as administrator"

Or from command prompt (as Administrator):

```cmd
cd build-windows
DesktopCapture.exe
```

### 5. Test It

1. **Open LinkedIn**: Go to https://www.linkedin.com/feed/
2. **Click a post**: Click anywhere on a LinkedIn post
3. **Check output**:
   ```cmd
   dir %USERPROFILE%\Desktop\captures
   ```

## Quick Test

View the log files:

```cmd
cd %USERPROFILE%\Desktop\captures
dir

cd 2025-11-11
type clicks.ndjson
type clicks.csv
dir *.png
```

## Usage

### Default (1 screenshot/second)
```cmd
DesktopCapture.exe
```

### Custom rate (2 screenshots/second)
```cmd
DesktopCapture.exe --hz 2
```

### Custom output directory
```cmd
DesktopCapture.exe --output C:\MyCaptures
```

## What Gets Captured

### Screenshots
- **Frequency**: 1 per second (configurable with `--hz`)
- **Location**: `Desktop\captures\YYYY-MM-DD\YYYY-MM-DDTHH-MM-SS.mmmZ.png`
- **Includes**: Actual system cursor, all monitors

### Click Logs
- **Format**: NDJSON and CSV
- **Location**: `Desktop\captures\YYYY-MM-DD\clicks.{ndjson,csv}`
- **Data**:
  - Timestamp, coordinates
  - App name, window title
  - Full text (expanded for LinkedIn/Twitter)
  - URL (if browser) or file path (if document)
  - Display ID, source (extension or OS)

## Supported Click Targets

✅ **LinkedIn posts** (with expansion)
✅ **X/Twitter posts** (with expansion)
✅ **PDFs in Adobe Reader** (file path)
✅ **Any Windows app** (basic text via UI Automation)

## Troubleshooting

### "Access Denied" or clicks not logged
→ Run as Administrator (right-click exe → "Run as administrator")

### ".NET SDK not found"
→ Install .NET 6.0 SDK from https://dotnet.microsoft.com/download/dotnet/6.0

### Extension not working
→ Check Chrome DevTools console (`chrome://extensions/` → "Inspect views: background page")

### No screenshots
→ Check disk space and ensure output directory is writable

## Stop Capturing

Press `Ctrl+C` in the command window.

## Windows-Specific Notes

### Why Administrator?

The app uses Windows global mouse hooks (`SetWindowsHookEx`) which require Administrator privileges. This allows monitoring clicks in ALL applications system-wide.

**What it monitors**: Mouse click positions only
**What it doesn't monitor**: Keyboard input, passwords, or other sensitive data

### Firewall Notice

Windows may show a firewall prompt. You can safely **Cancel** it - the app doesn't need network access (only Chrome visits websites).

### Antivirus

Some antivirus software may flag the app due to global mouse hook usage. This is a false positive - the app is open source and only logs click data locally.

## Next Steps

- Read [README-WINDOWS.md](README-WINDOWS.md) for full documentation
- See [TESTING.md](TESTING.md) for detailed test procedures

## Uninstall

```cmd
REM Remove build
rmdir /s /q build-windows

REM Remove extension (chrome://extensions/ → Remove)

REM Remove Native Messaging manifest
del "%LOCALAPPDATA%\Google\Chrome\NativeMessagingHosts\com.desktopcapture.host.json"

REM Remove captured data (optional)
rmdir /s /q "%USERPROFILE%\Desktop\captures"
```
