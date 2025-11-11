# Desktop Capture v0 - Testing Guide

This guide walks through testing all features of the Desktop Capture app.

## Prerequisites

Before testing, ensure you have:

1. ✅ Built the native app (`./build.sh`)
2. ✅ Installed Chrome extension (load unpacked from `chrome-extension/`)
3. ✅ Configured Native Messaging host (`./install-chrome-host.sh`)
4. ✅ Granted macOS permissions:
   - Accessibility: System Settings > Privacy & Security > Accessibility
   - Screen Recording: System Settings > Privacy & Security > Screen Recording

## Starting the App

```bash
./build/DesktopCapture.app/Contents/MacOS/DesktopCapture
```

You should see:
```
Desktop Capture v0 started
Capture rate: 1.0 Hz
Output directory: /Users/yourname/Desktop/captures

Monitoring clicks and capturing screenshots...
Press Ctrl+C to stop
```

## Test 1: LinkedIn Post Click

**Objective**: Verify full post text extraction with expansion.

### Steps:

1. Open Chrome and navigate to https://www.linkedin.com/feed/
2. Log in if needed
3. Find a post with "...See more" (collapsed post)
4. Click anywhere on the post text or image

### Expected Results:

**Console Output**:
```
Desktop Capture: LinkedIn content script loaded
Desktop Capture: Click detected on LinkedIn post
Desktop Capture: Expanding LinkedIn post
Desktop Capture: Sending click data: {type: 'click_data', x: ..., y: ..., text: '...', ...}
Click logged: (1234, 567) - Google Chrome - ext
```

**Log File** (`~/Desktop/captures/YYYY-MM-DD/clicks.ndjson`):
```json
{
  "ts": "2025-11-11T14:30:15.123Z",
  "x": 1234,
  "y": 567,
  "app": "Google Chrome",
  "window_title": "LinkedIn Feed",
  "role": "div",
  "text": "Full expanded post text here...",
  "browser_url": "https://www.linkedin.com/feed/update/urn:li:...",
  "doc_path": "",
  "display_id": 1,
  "source": "ext"
}
```

**Verification**:
- ✅ `text` field contains the FULL post text (not truncated)
- ✅ `browser_url` contains the LinkedIn post URL
- ✅ `source` is "ext" (from extension)
- ✅ Screenshot exists with cursor visible at click position

## Test 2: X/Twitter Post Click

**Objective**: Verify tweet text extraction with expansion.

### Steps:

1. Open Chrome and navigate to https://x.com/ or https://twitter.com/
2. Log in if needed
3. Find a tweet with "Show more" (long tweet)
4. Click anywhere on the tweet text

### Expected Results:

**Console Output**:
```
Desktop Capture: X/Twitter content script loaded
Desktop Capture: Click detected on tweet
Desktop Capture: Expanding tweet
Desktop Capture: Sending click data: ...
Click logged: (890, 432) - Google Chrome - ext
```

**Log File**:
```json
{
  "ts": "2025-11-11T14:31:22.456Z",
  "x": 890,
  "y": 432,
  "app": "Google Chrome",
  "window_title": "X",
  "role": "span",
  "text": "Full tweet text here...",
  "browser_url": "https://x.com/username/status/1234567890",
  "doc_path": "",
  "display_id": 1,
  "source": "ext"
}
```

**Verification**:
- ✅ `text` field contains the FULL tweet text
- ✅ `browser_url` contains the tweet status URL
- ✅ `source` is "ext"
- ✅ Screenshot captured with cursor visible

## Test 3: PDF in Adobe Reader

**Objective**: Verify PDF path extraction and text capture.

### Steps:

1. Download a PDF file (or use a sample PDF)
2. Open it in Adobe Acrobat Reader (not Chrome, not Preview)
3. Click on any text in the PDF body

### Expected Results:

**Console Output**:
```
Click logged: (1100, 650) - Adobe Acrobat Reader - os
```

**Log File**:
```json
{
  "ts": "2025-11-11T14:32:30.789Z",
  "x": 1100,
  "y": 650,
  "app": "Adobe Acrobat Reader",
  "window_title": "sample.pdf - Adobe Acrobat Reader",
  "role": "text",
  "text": "Text at click location",
  "browser_url": "",
  "doc_path": "/Users/yourname/Downloads/sample.pdf",
  "display_id": 1,
  "source": "os"
}
```

**Verification**:
- ✅ `doc_path` contains full path to PDF file
- ✅ `text` contains text near click (may be partial)
- ✅ `source` is "os" (from OS accessibility)
- ✅ `browser_url` is empty

### Alternative: PDF in Preview (macOS)

If using Preview.app instead:
- Should also capture `doc_path` via AXDocument attribute
- `source` will be "os"

### Alternative: PDF in Chrome

If using Chrome with file:// URL:
- `browser_url` will contain `file:///path/to/file.pdf`
- `source` will be "ext" (from extension)
- Either `browser_url` or `doc_path` should have the PDF path

## Test 4: Multi-Monitor Support

**Objective**: Verify correct display ID and cursor position on secondary display.

### Setup:

1. Connect a second monitor to your Mac
2. Arrange displays in System Settings > Displays
3. Note which is Display 1 vs Display 2

### Steps:

1. Move Chrome to the secondary display
2. Click on a LinkedIn post on that display
3. Move a non-Chrome app (e.g., TextEdit) to secondary display
4. Click in that app

### Expected Results:

**Log File**:
```json
{
  "ts": "2025-11-11T14:33:15.123Z",
  "x": 2560,
  "y": 450,
  "app": "Google Chrome",
  ...
  "display_id": 2,
  "source": "ext"
}
```

**Verification**:
- ✅ `display_id` matches the actual display number
- ✅ `x`, `y` coordinates are global (not display-relative)
- ✅ Screenshot file includes display ID suffix: `YYYY-MM-DDTHH-MM-SS.mmmZ-display2.png`
- ✅ Screenshot shows cursor at correct position
- ✅ Both displays captured separately

## Test 5: Screenshot Capture Rate

**Objective**: Verify configurable capture rate.

### Steps:

1. Stop the app (Ctrl+C)
2. Start with custom rate: `./build/DesktopCapture.app/Contents/MacOS/DesktopCapture --hz 2`
3. Wait 10 seconds
4. Check output folder

### Expected Results:

**Output Folder**:
- Should have ~20 screenshots (2 Hz × 10 seconds)
- Filenames should be 500ms apart (2 Hz = 0.5s interval)
- All screenshots should have cursor visible

**Verification**:
- ✅ Correct number of screenshots
- ✅ Timestamps match configured rate
- ✅ Cursor visible in all screenshots
- ✅ CPU usage remains low (~1-3%)

## Test 6: Non-Browser App Click

**Objective**: Verify accessibility API fallback.

### Steps:

1. Open any non-Chrome app (TextEdit, Notes, etc.)
2. Type some text
3. Click on the text

### Expected Results:

**Log File**:
```json
{
  "ts": "2025-11-11T14:34:45.000Z",
  "x": 800,
  "y": 400,
  "app": "TextEdit",
  "window_title": "Untitled",
  "role": "text",
  "text": "Selected or nearby text",
  "browser_url": "",
  "doc_path": "",
  "display_id": 1,
  "source": "os"
}
```

**Verification**:
- ✅ `source` is "os"
- ✅ `app` matches the application name
- ✅ `role` contains UI element type
- ✅ `text` contains some accessible text (may be limited)

## Test 7: Output File Format

**Objective**: Verify NDJSON and CSV formats are correct.

### Steps:

1. Perform several test clicks (mix of Chrome and non-Chrome)
2. Open `~/Desktop/captures/YYYY-MM-DD/clicks.ndjson`
3. Open `~/Desktop/captures/YYYY-MM-DD/clicks.csv`

### Expected Results:

**NDJSON**:
- Each line is valid JSON
- Can be parsed with `cat clicks.ndjson | jq .`
- All fields present

**CSV**:
- First line is header: `ts,x,y,app,window_title,role,text,browser_url,doc_path,display_id,source`
- Fields with commas/quotes are properly escaped
- Can be opened in Excel/Numbers

**Verification**:
```bash
# Validate NDJSON
cat clicks.ndjson | jq . > /dev/null && echo "Valid JSON"

# Check CSV
head -1 clicks.csv  # Should show header
wc -l clicks.csv    # Should match NDJSON + 1 (header)
```

## Test 8: Daily Folder Rotation

**Objective**: Verify new folder created at midnight UTC.

### Steps:

This is difficult to test in real-time. To simulate:

1. Note the current folder name (e.g., `2025-11-11/`)
2. Manually change system date to next day (in VM/test environment)
3. Restart app
4. Perform a click

### Expected Results:

- New folder created with next day's date
- Clicks logged to new folder's `clicks.ndjson` and `clicks.csv`
- Previous folder remains intact

## Test 9: Chrome Extension Multi-Tab

**Objective**: Verify extension works across multiple tabs.

### Steps:

1. Open 3+ Chrome tabs
2. Tab 1: LinkedIn
3. Tab 2: X/Twitter
4. Tab 3: Other website
5. Click in each tab sequentially

### Expected Results:

- All LinkedIn clicks logged with full post text
- All Twitter clicks logged with full tweet text
- Other website clicks logged (source=ext if in Chrome, may have limited data)

## Test 10: Performance & Efficiency

**Objective**: Verify CPU and memory efficiency.

### Steps:

1. Start the app with default 1 Hz
2. Open Activity Monitor
3. Find "DesktopCapture" process
4. Monitor for 5 minutes while using computer normally

### Expected Results:

**CPU**: 0.5-2% average (spikes to 5-10% during screenshot capture)
**Memory**: 50-100 MB
**Energy Impact**: Low

**Verification**:
- ✅ No memory leaks (memory stable over time)
- ✅ CPU usage acceptable
- ✅ No system slowdown
- ✅ Screenshot files ~1-2 MB each (PNG)

## Troubleshooting

### Extension Not Communicating

**Symptoms**: Clicks logged with `source: "os"` even in Chrome.

**Checks**:
1. Open Chrome DevTools on extension background page:
   - Go to `chrome://extensions/`
   - Click "Inspect views: background page"
   - Check console for connection errors
2. Verify Native Messaging manifest:
   ```bash
   cat ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.desktopcapture.host.json
   ```
3. Ensure extension ID matches in manifest
4. Check that binary path is correct and executable

### No Screenshots Captured

**Symptoms**: Clicks logged but no PNG files.

**Checks**:
1. Verify Screen Recording permission granted
2. Check disk space
3. Check Console.app for errors from DesktopCapture

### Missing Click Data

**Symptoms**: Some clicks not logged.

**Checks**:
1. Verify Accessibility permission granted
2. Check that you're clicking (not dragging)
3. Some UI elements may not be accessible

### PDF Path Not Captured

**Symptoms**: `doc_path` is empty for PDFs.

**Checks**:
1. Ensure using Adobe Reader or Preview (not all PDF viewers expose path)
2. Verify Accessibility permission
3. Try clicking different areas of the PDF

## Success Criteria

All tests should pass with:
- ✅ Screenshots captured every second with visible cursor
- ✅ LinkedIn posts fully expanded and text captured
- ✅ X/Twitter tweets fully expanded and text captured
- ✅ PDF file paths captured from Reader/Preview
- ✅ Multi-monitor support with correct display IDs
- ✅ Both NDJSON and CSV logs properly formatted
- ✅ CPU/memory usage efficient
- ✅ No crashes or errors during normal use

## Reporting Issues

If any test fails, capture:
1. Console output from the app
2. Chrome extension console logs
3. System Console.app logs (filter for "DesktopCapture")
4. Sample screenshots and log files
5. macOS version and hardware specs
