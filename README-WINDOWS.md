# Desktop Capture v0 - Windows Edition

Desktop capture application for Windows 10/11 with Chrome integration. Captures screenshots and logs detailed click information with deep LinkedIn and X/Twitter integration.

## Quick Start (Windows)

### Prerequisites

- Windows 10 or Windows 11
- [.NET 6.0 SDK or later](https://dotnet.microsoft.com/download)
- Google Chrome browser
- Administrator privileges (for global click monitoring)

### Installation

1. **Build the App**

   ```cmd
   build-windows.bat
   ```

2. **Install Chrome Extension**

   - Open Chrome: `chrome://extensions/`
   - Enable "Developer mode" (top-right toggle)
   - Click "Load unpacked"
   - Select the `chrome-extension` folder
   - **Copy the Extension ID**

3. **Configure Native Messaging**

   ```cmd
   install-chrome-host-windows.bat
   ```
   (Paste the Extension ID when prompted)

4. **Run the App (as Administrator)**

   ```cmd
   cd build-windows
   DesktopCapture.exe
   ```

   **Important**: Right-click `DesktopCapture.exe` → "Run as administrator" for click monitoring to work.

## Usage

### Command Line Options

```cmd
REM Default (1 screenshot per second)
DesktopCapture.exe

REM Custom capture rate (2 screenshots/second)
DesktopCapture.exe --hz 2

REM Custom output directory
DesktopCapture.exe --output C:\Users\YourName\Captures
```

### Output Structure

```
Desktop\captures\
  2025-11-11\
    2025-11-11T14-30-00.123Z.png
    2025-11-11T14-30-01.456Z.png
    clicks.ndjson
    clicks.csv
```

## Features

✅ **Screenshots**: Captured at 1 Hz (configurable) with cursor visible
✅ **Click Tracking**: Global left-click monitoring with full metadata
✅ **Chrome Integration**: Deep inspection of LinkedIn and X/Twitter posts
✅ **PDF Support**: Extract file paths from Adobe Reader
✅ **Multi-Monitor**: Full support with display ID tracking
✅ **Structured Output**: NDJSON and CSV logs

## What Gets Logged

### For LinkedIn/Twitter Clicks (in Chrome)

- Full expanded post text
- Post URL
- Click coordinates
- App name and window title
- Display ID
- Source: "ext" (from Chrome extension)

### For PDF Clicks (Adobe Reader)

- File path
- Text content near click
- Click coordinates
- Source: "os" (from Windows UI Automation)

### For Other App Clicks

- Click coordinates
- App name and window title
- UI element type and text (via UI Automation)
- Display ID

## Troubleshooting

### "Access Denied" or clicks not logged

**Solution**: Run as Administrator
- Right-click `DesktopCapture.exe`
- Select "Run as administrator"
- This is required for global mouse hook (SetWindowsHookEx)

### Chrome extension not communicating

**Checks**:
1. Verify Native Messaging manifest exists:
   ```cmd
   type "%LOCALAPPDATA%\Google\Chrome\NativeMessagingHosts\com.desktopcapture.host.json"
   ```

2. Check that extension ID matches in the manifest

3. Open Chrome extension console:
   - Go to `chrome://extensions/`
   - Find "Desktop Capture Helper"
   - Click "Inspect views: background page"
   - Check console for errors

### No screenshots captured

**Checks**:
- Ensure .NET 6.0 Windows Desktop runtime is installed
- Check disk space
- Verify output directory is writable

### ".NET SDK not found"

**Solution**: Download and install .NET 6.0 SDK from:
https://dotnet.microsoft.com/download/dotnet/6.0

Select "Windows x64" installer

## Windows-Specific Notes

### Administrator Privileges

The app requires Administrator privileges because:
- Global mouse hook (`SetWindowsHookEx`) requires elevated permissions
- This allows monitoring clicks in ALL applications
- Without admin rights, only clicks within the app itself are monitored

### Cursor Capture

Windows implementation captures the actual system cursor using:
- `GetCursorInfo()` - Gets cursor position and handle
- `GetIconInfo()` - Gets cursor hotspot
- `DrawIcon()` - Draws cursor on screenshot

This provides accurate cursor representation (unlike macOS which draws a simple arrow).

### UI Automation

Windows uses UI Automation API for non-browser apps:
- `AutomationElement.FromPoint()` - Gets element at click point
- `ValuePattern` - Extracts text from inputs
- `TextPattern` - Extracts document text
- Control type detection for role

### PDF Path Extraction

For Adobe Reader/Acrobat:
- Parses window title (e.g., "document.pdf - Adobe Acrobat Reader DC")
- Searches UI Automation tree for document properties
- Extracts full path when available

## Performance

- **CPU Usage**: 1-3% idle, 5-10% during capture
- **Memory**: 60-120 MB
- **Disk**: ~1-2 MB per screenshot (PNG)

## Security Notes

### Why Administrator Rights?

The app uses low-level Windows hooks to monitor mouse clicks globally. This requires admin privileges for security reasons:

- **What it monitors**: Left mouse clicks (position only)
- **What it doesn't do**:
  - No keyboard input monitoring
  - No password capture
  - No network communication (except Chrome visiting websites)
  - No data sent to external servers

### Data Storage

- All data stored locally in `Desktop\captures\`
- No telemetry or analytics
- No cloud upload
- **Important**: Screenshots may contain sensitive information - secure your capture directory

## Building from Source

### Requirements

- Windows 10/11
- .NET 6.0 SDK or later
- Visual Studio 2022 (optional, for development)

### Build

```cmd
cd native-app-windows
dotnet build -c Release
```

Binary will be in: `bin\Release\net6.0-windows\DesktopCapture.exe`

### Development

Open `native-app-windows\DesktopCapture.csproj` in Visual Studio 2022 or VS Code.

**Project Structure**:
- `Program.cs` - Entry point, configuration
- `ScreenCapture.cs` - Screenshot capture with cursor
- `ClickMonitor.cs` - Global mouse hook, click detection
- `NativeMessaging.cs` - Chrome extension communication
- `UIAutomationHelper.cs` - Windows UI Automation
- `OutputManager.cs` - File I/O (screenshots, logs)

## Comparison: Windows vs macOS

| Feature | Windows | macOS |
|---------|---------|-------|
| Admin/Root Required | Yes (for global hook) | No |
| Cursor Rendering | Actual system cursor | Drawn arrow |
| Screenshot API | GDI/Graphics | CGDisplayCreateImage |
| Click Monitoring | SetWindowsHookEx | NSEvent |
| Accessibility | UI Automation | Accessibility API |
| PDF Path | Window title parsing | AXDocument attribute |
| Build Tool | .NET CLI | Swift Package Manager |

## Known Limitations

- Requires Administrator privileges
- Windows 10/11 only (not Windows 7/8)
- Chrome only (no Firefox, Edge)
- LinkedIn and X/Twitter only
- Adobe Reader/Acrobat for PDF (not all PDF viewers)

## Uninstall

```cmd
REM Remove build files
rmdir /s /q build-windows

REM Remove Native Messaging manifest
del "%LOCALAPPDATA%\Google\Chrome\NativeMessagingHosts\com.desktopcapture.host.json"

REM Remove Chrome extension (go to chrome://extensions/ and click Remove)

REM Remove captured data (optional)
rmdir /s /q "%USERPROFILE%\Desktop\captures"
```

## Support

- **Build Issues**: Ensure .NET 6.0 SDK is installed
- **Click Monitoring**: Run as Administrator
- **Extension Issues**: Check Native Messaging manifest and extension console

## License

MIT License - See LICENSE file

## Version

v0 (Windows + macOS)
