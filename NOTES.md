# Technical Notes - Desktop Capture v0

Development notes, design decisions, and implementation details.

## Design Decisions

### macOS Choice for v0

**Decision**: Build for macOS only (not Windows).

**Rationale**:
- Superior Swift APIs for screen capture and accessibility
- `CGDisplayCreateImage` provides easy multi-monitor capture
- Accessibility API is mature and well-documented
- Native Messaging integration straightforward
- Development environment consistency (Unix-like)

**Windows considerations for future**:
- Would require C++/C# rewrite
- Windows API for screenshots more complex
- UI Automation API for accessibility
- Native Messaging same protocol, different manifest location

### Swift vs Objective-C/C++

**Decision**: Use Swift with minimal Objective-C bridging.

**Rationale**:
- Modern, safe language with good macOS API support
- Swift Package Manager simplifies dependency management
- Better error handling and memory safety
- Native support for AppKit and Core Graphics
- No need for bridging headers in pure Swift

**Trade-offs**:
- Slightly larger binary size vs Objective-C
- Some private APIs harder to access (cursor image)
- Swift runtime required (already on all macOS 13+)

### Cursor Drawing Implementation

**Current**: Programmatically drawn arrow cursor.

**Challenge**: Getting actual system cursor requires private APIs:
- `CGSGetCursorForCoords` (private)
- `NSCursor.image` doesn't match active cursor
- Screenshots don't include cursor by default

**Solution**: Draw a simple arrow cursor overlay at `NSEvent.mouseLocation`.

**Future improvement**: Use private APIs (with caution) or screenshot the cursor separately.

### Native Messaging Protocol

**Decision**: Use Chrome Native Messaging with stdin/stdout.

**Rationale**:
- Standard Chrome extension communication method
- No network sockets, no HTTP servers needed
- Automatic process management by Chrome
- Works across multiple Chrome profiles
- Secure (extension must be explicitly allowed in manifest)

**Protocol**:
```
Message Format: [4-byte length (little-endian)] + [JSON payload]
Direction: Bidirectional (extension ↔ native app)
Connection: Chrome spawns native app on first message
```

**Limitations**:
- One native app instance per Chrome profile
- Messages limited to ~1 MB (configurable)
- No push notifications (app → extension unsolicited)

### Click Detection Strategy

**Two-tier approach**:

1. **Chrome clicks**: Wait 250ms for extension payload
   - Extension detects click in content script
   - Expands post if needed
   - Sends full text + URL
   - Native app waits briefly for this data

2. **Non-Chrome clicks**: Immediate accessibility fallback
   - Use `AXUIElementCopyElementAtPosition`
   - Extract role, text, document path
   - Less rich data but works everywhere

**Why 250ms?**:
- Typical "See more" expansion takes 100-200ms
- Network delay for extension communication ~10-50ms
- Trade-off: responsive logging vs complete data
- Timeout prevents indefinite waiting if extension fails

### Output Format Choice

**Decision**: Dual format (NDJSON + CSV).

**NDJSON** (Newline-Delimited JSON):
- Streaming friendly (append-only)
- Easy parsing: `cat file.ndjson | jq .`
- Maintains data types (numbers, booleans)
- No header row needed
- Machine-readable

**CSV**:
- Universal compatibility (Excel, Numbers, Google Sheets)
- Human-readable in text editors
- Easy filtering and sorting
- Header row for self-documentation
- Field escaping for commas/quotes

**Why both?**:
- Different use cases (scripting vs spreadsheet analysis)
- Minimal overhead (same data, two writes)
- User choice based on workflow

### Screenshot Timing

**Decision**: Timer-based capture (not event-driven).

**Alternatives considered**:
1. **On-click only**: Misses context, no temporal tracking
2. **On-change detection**: High CPU, complex to implement
3. **Fixed interval**: Simple, predictable, configurable ✓

**Current**: `Timer.scheduledTimer` with user-specified Hz.

**Performance**:
- 1 Hz: ~2% CPU average
- 2 Hz: ~4% CPU average
- 10 Hz: ~15-20% CPU (not recommended for long-term)

### PDF Path Extraction

**Challenge**: Different PDF viewers expose path differently.

**Implementations**:

1. **Preview.app**: Use `kAXDocumentAttribute`
   ```swift
   AXUIElementCopyAttributeValue(element, kAXDocumentAttribute, &docRef)
   // Returns: "file:///path/to/file.pdf"
   ```

2. **Adobe Reader**: Use window title + traversal
   ```swift
   // Title: "document.pdf - Adobe Acrobat Reader"
   // Or use AXDocument on window element
   ```

3. **Chrome PDF viewer**: Use extension to get `file://` URL
   ```javascript
   window.location.href // "file:///path/to/file.pdf"
   ```

**Fallback**: If path not available, log window title (may contain filename).

## Implementation Details

### ScreenCapture.swift

**Key challenge**: Drawing cursor on screenshot.

```swift
func drawCursorOnImage(_ baseImage: CGImage, displayID: CGDirectDisplayID) -> CGImage? {
    // 1. Create bitmap context
    // 2. Draw base image
    // 3. Get cursor position (NSEvent.mouseLocation)
    // 4. Convert to display-relative coordinates
    // 5. Check if cursor on this display
    // 6. Draw cursor overlay
    // 7. Return composited image
}
```

**Coordinate systems**:
- `NSEvent.mouseLocation`: Global coordinates, origin at bottom-left of primary display
- `CGDisplayBounds`: Display bounds in global coordinates
- Quartz context: Local to image, origin at top-left (flipped Y)

**Conversions**:
```swift
let relativeX = cursorPosition.x - displayBounds.origin.x
let relativeY = cursorPosition.y - displayBounds.origin.y
let flippedY = CGFloat(height) - relativeY
```

### ClickMonitor.swift

**Pending clicks mechanism**:

```swift
var pendingClicks: [String: (CGPoint, Date, NSRunningApplication?, String)] = [:]
```

**Flow**:
1. Click detected → Check if Chrome
2. If Chrome → Add to `pendingClicks` with UUID
3. Set 250ms timeout
4. If extension responds → Match by coordinates + timestamp
5. If timeout → Fall back to accessibility
6. Remove from pending

**Why UUID?**: Multiple rapid clicks could have same coordinates.

**Matching criteria**:
- Distance < 10 pixels
- Time difference < 1 second

### NativeMessaging.swift

**Threading model**:
- Input listener runs on background thread (`Thread`)
- Callbacks dispatched to main queue (`DispatchQueue.main.async`)
- Output (sendMessage) writes to stdout directly

**Why background thread?**:
- `FileHandle.readData` is blocking
- Can't block main thread (UI would freeze)
- Native Messaging expects persistent connection

**Error handling**:
- Invalid message length → Log and continue
- JSON parse error → Log and skip message
- EOF on stdin → Exit gracefully (Chrome closed)

### OutputManager.swift

**Daily folder rotation**:

```swift
func createTodayFolder() {
    let today = getTodayFolderName() // "YYYY-MM-DD" in UTC
    // Create folder, open log files
}

func saveScreenshot(...) {
    // Check if date changed
    if todayFolder != currentFolder {
        closeLogFiles()
        createTodayFolder()
    }
    // Save screenshot
}
```

**Why UTC?**: Consistent timestamps across time zones, no DST issues.

**File handles**: Keep open for performance (append-only, flushed after each write).

### Content Scripts

**LinkedIn selectors** (as of 2025):
```javascript
const SELECTORS = {
  postContainer: [
    '.feed-shared-update-v2',      // Main feed post
    'div[data-urn]',                // URN-based posts
    '.occludable-update',           // Occludable posts
    'article'                       // Generic fallback
  ],
  seeMoreButton: [
    '.feed-shared-inline-show-more-text__see-more-less-toggle',
    'button[aria-label*="more"]',
    '.see-more',
    'button.inline-show-more-text__button'
  ],
  // ...
}
```

**X/Twitter selectors**:
```javascript
const SELECTORS = {
  tweetContainer: [
    'article[data-testid="tweet"]', // Primary selector
    'div[data-testid="tweet"]',     // Alternative
    'article',                      // Fallback
  ],
  // ...
}
```

**Why multiple selectors?**:
- Social media sites change DOM frequently
- A/B testing creates variations
- Fallbacks increase reliability

**Expansion strategy**:
1. Find container under click
2. Query for "See more"/"Show more" button
3. Check if button is visible (`offsetParent !== null`)
4. Click button
5. Wait 300ms for animation
6. Extract full text

## Known Issues & Workarounds

### Issue: Cursor not at exact click point

**Symptom**: Cursor appears slightly offset in screenshot.

**Cause**: Screenshot capture is async; cursor may have moved between click event and capture.

**Workaround**: Screenshots are on a timer (1 Hz), clicks logged with exact coordinates. Use click logs for precise position, screenshot for context.

**Future fix**: Capture screenshot immediately on click (in addition to timer).

### Issue: Extension doesn't detect click on embedded content

**Symptom**: Click on YouTube embed in LinkedIn post doesn't capture post text.

**Cause**: Click event on iframe doesn't bubble to content script.

**Workaround**: Click on post text directly (not embedded media).

**Future fix**: Use `all_frames: true` in content script (may have side effects).

### Issue: PDF path empty for some PDF viewers

**Symptom**: `doc_path` is empty when clicking in some PDF apps.

**Cause**: Not all PDF viewers expose document path via Accessibility API.

**Workaround**: Window title often contains filename.

**Future fix**: Maintain table of known PDF apps and extraction methods.

### Issue: Extension manifest allows all origins on domain

**Symptom**: Extension has broad permissions for linkedin.com.

**Security note**: `host_permissions: ["https://www.linkedin.com/*"]` allows all LinkedIn pages.

**Acceptable for v0**: User explicitly installs extension.

**Future**: Narrow to specific paths if possible (may break on URL changes).

## Performance Optimization

### Screenshot Capture

**Optimization**: Only capture changed displays.

**Future**:
```swift
var previousHashes: [CGDirectDisplayID: Int] = [:]

func captureIfChanged(displayID: CGDirectDisplayID) {
    let hash = quickHash(of: display)
    if hash != previousHashes[displayID] {
        capture(displayID)
        previousHashes[displayID] = hash
    }
}
```

**Trade-off**: Hash computation may be as expensive as capture.

### Log File I/O

**Current**: Append after every click, flush immediately.

**Optimization**: Buffer writes, flush every N clicks or every T seconds.

**Trade-off**: Risk of data loss on crash vs. I/O efficiency.

**Decision**: Prioritize data integrity (immediate flush) in v0.

### Memory Management

**Screenshots**: Not kept in memory after saving (PNG data released).

**Logs**: Append-only file handles, minimal buffer.

**Extension messages**: Parsed and processed immediately, not queued.

## Testing Challenges

### Unit Testing

**Challenge**: Heavy use of macOS APIs that require GUI environment.

**Current**: Manual testing with TESTING.md procedures.

**Future**:
- Mock CGDisplayCreateImage for screenshot tests
- Mock AXUIElement for accessibility tests
- Integration tests with test apps

### Extension Testing

**Challenge**: Content scripts depend on live websites (LinkedIn, Twitter).

**Current**: Manual testing on real sites.

**Future**:
- Local HTML fixtures mimicking LinkedIn/Twitter DOM
- Inject fixtures in test mode
- Automated Puppeteer/Selenium tests

## Security Considerations

### Permissions

**Accessibility**: Extremely powerful (can read all UI, simulate input).
- Only used for click target inspection
- No input simulation in v0
- User must explicitly grant

**Screen Recording**: Can capture entire screen.
- Only used for screenshots
- User must explicitly grant
- macOS shows recording indicator (dot in menu bar)

### Data Privacy

**Local storage only**: All data saved to `~/Desktop/captures/`.

**No network**: No analytics, no telemetry, no cloud upload.

**Sensitive content**: Screenshots may capture passwords, private messages, etc.

**User responsibility**: Secure the captures folder, don't share screenshots publicly.

### Extension Security

**Native Messaging**: Extension must be explicitly allowed in manifest.

**Content Security**: Extension only injected on LinkedIn and Twitter.

**No eval()**: No dynamic code execution in extension.

## Future Architecture Ideas

### Database Backend

Replace NDJSON/CSV with SQLite:
- Better query performance
- Full-text search
- Relational data (clicks → screenshots)
- Atomic transactions

### Event Sourcing

Store all events (clicks, screenshots, app switches):
- Rebuild state from events
- Time travel debugging
- Analytics queries

### Plugin System

Allow user-defined handlers for other sites:
```javascript
// plugins/reddit-post.js
export function detectPost(element) { ... }
export function expandPost(post) { ... }
export function extractText(post) { ... }
```

### Cloud Sync (Optional)

End-to-end encrypted cloud backup:
- User's own cloud storage (S3, Dropbox)
- Client-side encryption
- Opt-in only

## Debugging Tips

### Enable verbose logging

Add to main.swift:
```swift
let verbose = CommandLine.arguments.contains("--verbose")
if verbose {
    print("Debug: Screenshot captured at \(timestamp)")
}
```

### Monitor extension

Chrome DevTools:
1. Go to `chrome://extensions/`
2. Find Desktop Capture Helper
3. Click "Inspect views: background page"
4. Open Console

### Check Native Messaging connection

In extension console:
```javascript
console.log(chrome.runtime.lastError)
```

### macOS Console.app

Filter for "DesktopCapture" to see NSLog messages.

### Verify permissions

```bash
# Check Accessibility
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client FROM access WHERE service='kTCCServiceAccessibility';"

# Check Screen Recording
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client FROM access WHERE service='kTCCServiceScreenCapture';"
```

## Code Style

### Swift

- Follow Apple's Swift API Design Guidelines
- Use explicit type annotations for class/struct properties
- Prefer `let` over `var`
- Use guard for early returns
- Document public APIs with `///` comments

### JavaScript

- ES6+ syntax (arrow functions, const/let)
- Semicolons required
- Use strict mode: `'use strict'`
- Prefer async/await over callbacks
- Console logging for debugging (removed in production)

## References

### Apple Documentation

- [Quartz Display Services](https://developer.apple.com/documentation/coregraphics/quartz_display_services)
- [Accessibility API](https://developer.apple.com/documentation/applicationservices/accessibility)
- [Event Monitoring](https://developer.apple.com/documentation/appkit/nsevent)

### Chrome Extensions

- [Native Messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
- [Content Scripts](https://developer.chrome.com/docs/extensions/develop/concepts/content-scripts)
- [Manifest V3](https://developer.chrome.com/docs/extensions/develop/migrate/what-is-mv3)

### Specifications

- [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) - Date/time format
- [NDJSON](http://ndjson.org/) - Newline Delimited JSON
- [CSV RFC 4180](https://tools.ietf.org/html/rfc4180) - CSV format

## Maintenance

### Updating LinkedIn/Twitter selectors

Social media sites change frequently. When selectors break:

1. Open DevTools on the site
2. Inspect post container element
3. Find new stable selectors (data-testid preferred)
4. Update content script arrays
5. Test with multiple post types

### macOS API changes

Monitor Apple's release notes for:
- Deprecated Accessibility APIs
- Screen recording permission changes
- Notarization requirements

## Contact & Contributions

**License**: MIT (see LICENSE file)

**Issues**: Report bugs and feature requests via GitHub Issues

**Pull Requests**: Welcome! Please follow existing code style.

**Roadmap**: See DELIVERABLES.md for future enhancements

---

Last updated: 2025-11-11
Version: v0
