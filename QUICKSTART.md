# Quick Start Guide - Desktop Capture v0

Get up and running in 5 minutes.

## Prerequisites

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`
- Google Chrome

## Installation (5 steps)

### 1. Build the App

```bash
./build.sh
```

### 2. Install Chrome Extension

1. Open Chrome: `chrome://extensions/`
2. Enable "Developer mode" (top-right toggle)
3. Click "Load unpacked"
4. Select the `chrome-extension` folder
5. **Copy the Extension ID** (shown in the extension card)

### 3. Configure Native Messaging

```bash
./install-chrome-host.sh
# Paste the Extension ID when prompted
```

### 4. Grant Permissions

Go to **System Settings > Privacy & Security**:

- **Accessibility**: Add and enable DesktopCapture
- **Screen Recording**: Add and enable DesktopCapture

### 5. Start Capturing

```bash
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture
```

## Quick Test

1. **Open LinkedIn**: Go to https://www.linkedin.com/feed/
2. **Click a post**: Click anywhere on a LinkedIn post
3. **Check output**:
   ```bash
   ls ~/Desktop/captures/$(date -u +%Y-%m-%d)/
   # Should show: clicks.ndjson, clicks.csv, and .png files
   ```

4. **View logs**:
   ```bash
   cat ~/Desktop/captures/$(date -u +%Y-%m-%d)/clicks.ndjson | jq .
   ```

## Usage

### Default (1 screenshot/second)
```bash
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture
```

### Custom rate (2 screenshots/second)
```bash
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture --hz 2
```

### Custom output directory
```bash
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture --output ~/my-captures
```

## What Gets Captured

### Screenshots
- **Frequency**: 1 per second (configurable)
- **Location**: `~/Desktop/captures/YYYY-MM-DD/YYYY-MM-DDTHH-MM-SS.mmmZ.png`
- **Includes**: Cursor visible, all monitors

### Click Logs
- **Format**: NDJSON and CSV
- **Location**: `~/Desktop/captures/YYYY-MM-DD/clicks.{ndjson,csv}`
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
✅ **PDFs in Preview** (file path)
✅ **Any macOS app** (basic text via Accessibility API)

## Troubleshooting

### "Permission denied" errors
→ Grant Accessibility and Screen Recording permissions in System Settings

### Extension not working
→ Check Chrome DevTools (chrome://extensions/ → "Inspect views: background page")

### No screenshots
→ Grant Screen Recording permission

### Missing click data
→ Grant Accessibility permission

## Next Steps

- Read [TESTING.md](TESTING.md) for detailed test procedures
- Read [README.md](README.md) for full documentation

## Stop Capturing

Press `Ctrl+C` in the terminal running the app.

## Uninstall

```bash
# Remove app
rm -rf build/

# Remove Chrome extension
# Go to chrome://extensions/ and click "Remove"

# Remove Native Messaging host
rm ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.desktopcapture.host.json

# Remove captured data (optional)
rm -rf ~/Desktop/captures/
```
