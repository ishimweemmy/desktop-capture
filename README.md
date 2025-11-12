# Desktop Capture App with Chrome Integration (v0)

A cross-platform desktop application (Windows & macOS) that captures screenshots at configurable intervals and logs detailed information about user clicks, with deep integration for Chrome browser content (LinkedIn and X/Twitter posts).

## Features

- **Automated Screenshots**: Capture at 1 Hz (configurable) with cursor visible
- **Click Tracking**: Global left-click monitoring with full metadata
- **Chrome Integration**: Deep inspection of LinkedIn and X/Twitter posts via Native Messaging
- **PDF Support**: Extract file paths from PDFs opened in Preview or Adobe Reader
- **Multi-Monitor**: Full support for multiple displays with display ID tracking
- **Structured Output**: Daily folders with timestamped screenshots, NDJSON and CSV logs
- **Cross-Platform**: Native implementations for both Windows and macOS

## Platform-Specific Documentation

- **Windows Users**: See [README-WINDOWS.md](README-WINDOWS.md) for Windows-specific instructions
- **macOS Users**: Continue reading below or see [README.md](README.md)

## System Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Google Chrome browser
- Xcode Command Line Tools (for building from source)

### Windows
- Windows 10 or Windows 11
- .NET 6.0 SDK or later
- Google Chrome browser
- Administrator privileges (for global click monitoring)

## Installation

### macOS Installation

#### 1. Build the Native App

```bash
./build.sh
```

This will compile the macOS app and place it in `build/DesktopCapture.app`.

### Windows Installation

#### 1. Build the Native App

```cmd
build-windows.bat
```

This will compile the Windows app and place it in `build-windows\DesktopCapture.exe`.

### 2. Grant Permissions

The app requires the following macOS permissions:
- **Accessibility**: For click monitoring and window information
- **Screen Recording**: For capturing screenshots

Go to `System Settings > Privacy & Security > Accessibility` and `Screen Recording` and enable permissions for DesktopCapture.

### 3. Install Chrome Extension

1. Open Chrome and go to `chrome://extensions/`
2. Enable "Developer mode" (toggle in top-right)
3. Click "Load unpacked"
4. Select the `chrome-extension` folder from this project
5. Note the Extension ID shown in the card

### 4. Configure Native Messaging

```bash
# Install the Native Messaging host manifest
./install-chrome-host.sh
```

This creates the manifest file that allows Chrome to communicate with the native app.

## Usage

### Start Capturing

```bash
# Default 1 Hz capture rate
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture

# Custom capture rate (2 screenshots per second)
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture --hz 2

# Custom output directory
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture --output ~/my-captures
```

### Output Structure

```
~/Desktop/captures/
  2025-11-11/
    2025-11-11T14-30-00.123Z.png
    2025-11-11T14-30-01.456Z.png
    clicks.ndjson
    clicks.csv
  2025-11-12/
    ...
```

### Log Format

**clicks.ndjson** (newline-delimited JSON):
```json
{"ts":"2025-11-11T14:30:15.123Z","x":1024,"y":768,"app":"Chrome","window_title":"LinkedIn Feed","role":"button","text":"This is the full post text...","browser_url":"https://www.linkedin.com/feed/","doc_path":"","display_id":1,"source":"ext"}
```

**clicks.csv**:
```csv
ts,x,y,app,window_title,role,text,browser_url,doc_path,display_id,source
2025-11-11T14:30:15.123Z,1024,768,Chrome,"LinkedIn Feed",button,"This is the full post text...",https://www.linkedin.com/feed/,,1,ext
```

### Fields

- `ts`: Timestamp in ISO-8601 format (UTC)
- `x`, `y`: Global screen coordinates of the click
- `app`: Application name (process name or bundle ID)
- `window_title`: Title of the active window
- `role`: UI element role (button, link, text, etc.)
- `text`: Full text content (expanded for social media posts)
- `browser_url`: URL if clicked in Chrome
- `doc_path`: File path if clicked in a document (PDF, etc.)
- `display_id`: Monitor/display identifier
- `source`: Data source - "ext" (Chrome extension) or "os" (OS accessibility)

## Architecture

### Native App (Swift)

- **ScreenCapture**: Uses `CGDisplayCreateImage` to capture all displays with cursor
- **ClickMonitor**: `NSEvent.addGlobalMonitorForEvents` for left-click detection
- **NativeMessaging**: Receives data from Chrome extension via stdin/stdout
- **Accessibility**: Falls back to `AXUIElement` for non-browser apps
- **OutputManager**: Manages daily folders, screenshots, and dual log format

### Chrome Extension

- **Content Scripts**: Injected into LinkedIn and X/Twitter pages
- **Post Detection**: Finds post containers at click coordinates
- **Expansion**: Clicks "See more" buttons and waits for full content
- **Background Service**: Handles Native Messaging communication
- **Multi-Tab/Profile**: Works across all Chrome instances

### Communication Flow

```
User Click → Extension (if Chrome) → Native Messaging → Native App → Log/Screenshot
          ↘ Extension (if other app) → Accessibility API → Native App → Log/Screenshot
```

## Testing

### Acceptance Tests

1. **LinkedIn Post**: Click on any LinkedIn post → logs full expanded text + URL
2. **X/Twitter Post**: Click on any tweet → logs full expanded text + URL
3. **PDF in Reader**: Click in Adobe Reader PDF → logs file path + text
4. **Multi-Monitor**: Click on secondary display → correct display_id logged

### Running Tests

```bash
# Start the app
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture

# Perform test clicks (see screen recording)
# Check output in ~/Desktop/captures/YYYY-MM-DD/
```

## Development

### Project Structure

```
desktop-capture/
  native-app/
    Sources/
      main.swift
      ScreenCapture.swift
      ClickMonitor.swift
      NativeMessaging.swift
      AccessibilityHelper.swift
      OutputManager.swift
    Package.swift
  chrome-extension/
    manifest.json
    background.js
    content-linkedin.js
    content-twitter.js
    native-messaging.js
  build.sh
  install-chrome-host.sh
  README.md
```

### Building

```bash
# Build native app
cd native-app
swift build -c release

# Extension is ready to load unpacked (no build needed)
```

## Troubleshooting

### Permissions Denied

Make sure to grant Accessibility and Screen Recording permissions in System Settings.

### Chrome Extension Not Communicating

1. Check that Native Messaging host is installed: `cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.desktopCapture.host.json`
2. Verify extension ID matches in the manifest
3. Check Chrome extension console for errors

### No Screenshots Captured

Ensure Screen Recording permission is granted. The app will log errors to Console.app.

### Missing Click Data

For Chrome clicks, verify the extension is active on the page. For other apps, verify Accessibility permission.

## Performance

- **CPU Usage**: ~1-2% during idle capture (1 Hz)
- **Memory**: ~50-100 MB typical
- **Disk**: ~1-2 MB per screenshot (PNG), ~1 KB per click record

## Privacy & Security

- All data is stored locally in `~/Desktop/captures/`
- No network communication (except Chrome visiting websites)
- No telemetry or analytics
- Screenshots may contain sensitive information - secure your capture directory

## License

MIT License - See LICENSE file

## Version

v0 (macOS only, Chrome only)
