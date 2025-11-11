import Foundation
import AppKit
import CoreGraphics

struct ClickEvent {
    let timestamp: Date
    let x: CGFloat
    let y: CGFloat
    let app: String
    let windowTitle: String
    let role: String
    let text: String
    let browserURL: String
    let docPath: String
    let displayID: CGDirectDisplayID
    let source: String // "ext" or "os"

    func toNDJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let dict: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: timestamp),
            "x": Int(x),
            "y": Int(y),
            "app": app,
            "window_title": windowTitle,
            "role": role,
            "text": text,
            "browser_url": browserURL,
            "doc_path": docPath,
            "display_id": Int(displayID),
            "source": source
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "{}"
    }

    func toCSVRow() -> String {
        // Escape fields that may contain commas or quotes
        func escape(_ str: String) -> String {
            if str.contains(",") || str.contains("\"") || str.contains("\n") {
                return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return str
        }

        return [
            ISO8601DateFormatter().string(from: timestamp),
            "\(Int(x))",
            "\(Int(y))",
            escape(app),
            escape(windowTitle),
            escape(role),
            escape(text),
            escape(browserURL),
            escape(docPath),
            "\(Int(displayID))",
            source
        ].joined(separator: ",")
    }

    static var csvHeader: String {
        return "ts,x,y,app,window_title,role,text,browser_url,doc_path,display_id,source"
    }
}

class ClickMonitor {
    let accessibilityHelper: AccessibilityHelper
    let nativeMessaging: NativeMessaging
    let outputManager: OutputManager

    var globalMonitor: Any?
    var pendingClicks: [String: (CGPoint, Date, NSRunningApplication?, String)] = [:] // clickID -> (point, timestamp, app, windowTitle)

    init(accessibilityHelper: AccessibilityHelper, nativeMessaging: NativeMessaging, outputManager: OutputManager) {
        self.accessibilityHelper = accessibilityHelper
        self.nativeMessaging = nativeMessaging
        self.outputManager = outputManager

        // Set callback for native messaging
        nativeMessaging.onMessageReceived = { [weak self] message in
            self?.handleExtensionMessage(message)
        }
    }

    func start() {
        // Monitor left mouse clicks globally
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClick(event)
        }

        // Also monitor local clicks (in case app has focus)
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClick(event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func handleClick(_ event: NSEvent) {
        let clickPoint = NSEvent.mouseLocation // Global coordinates
        let timestamp = Date()

        // Get active application
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return
        }

        let appName = activeApp.localizedName ?? activeApp.bundleIdentifier ?? "Unknown"

        // Get window title
        let windowTitle = getActiveWindowTitle(for: activeApp)

        // Get display ID
        let displayID = getDisplayID(for: clickPoint)

        // Check if this is Chrome
        let isChromeApp = activeApp.bundleIdentifier?.contains("chrome") == true ||
                          activeApp.bundleIdentifier?.contains("Chrome") == true

        if isChromeApp {
            // Wait for extension response (up to 250ms)
            let clickID = UUID().uuidString
            pendingClicks[clickID] = (clickPoint, timestamp, activeApp, windowTitle)

            // Send notification to extension via native messaging might not be needed
            // since extension detects clicks directly

            // Wait 250ms for extension response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.handleClickTimeout(clickID, clickPoint: clickPoint, timestamp: timestamp, app: activeApp, windowTitle: windowTitle, displayID: displayID)
            }
        } else {
            // Non-Chrome app, use accessibility API immediately
            handleNonChromeClick(clickPoint: clickPoint, timestamp: timestamp, app: activeApp, windowTitle: windowTitle, displayID: displayID)
        }
    }

    private func handleExtensionMessage(_ message: [String: Any]) {
        // Extension sent click data
        guard let x = message["x"] as? Double,
              let y = message["y"] as? Double else {
            return
        }

        let clickPoint = CGPoint(x: x, y: y)
        let text = message["text"] as? String ?? ""
        let url = message["url"] as? String ?? ""
        let role = message["role"] as? String ?? "element"

        // Find matching pending click (within 1 second and close proximity)
        let now = Date()
        var matchedClickID: String?

        for (clickID, (pendingPoint, pendingTime, _, _)) in pendingClicks {
            let distance = hypot(pendingPoint.x - clickPoint.x, pendingPoint.y - clickPoint.y)
            let timeDiff = now.timeIntervalSince(pendingTime)

            if distance < 10 && timeDiff < 1.0 {
                matchedClickID = clickID
                break
            }
        }

        if let clickID = matchedClickID,
           let (_, timestamp, app, windowTitle) = pendingClicks[clickID] {
            // Remove from pending
            pendingClicks.removeValue(forKey: clickID)

            // Create click event with extension data
            let displayID = getDisplayID(for: clickPoint)
            let appName = app?.localizedName ?? app?.bundleIdentifier ?? "Chrome"

            let clickEvent = ClickEvent(
                timestamp: timestamp,
                x: clickPoint.x,
                y: clickPoint.y,
                app: appName,
                windowTitle: windowTitle,
                role: role,
                text: text,
                browserURL: url,
                docPath: "",
                displayID: displayID,
                source: "ext"
            )

            logClickEvent(clickEvent)
        }
    }

    private func handleClickTimeout(_ clickID: String, clickPoint: CGPoint, timestamp: Date, app: NSRunningApplication, windowTitle: String, displayID: CGDirectDisplayID) {
        // Check if still pending (not handled by extension)
        guard pendingClicks[clickID] != nil else {
            return // Already handled by extension
        }

        pendingClicks.removeValue(forKey: clickID)

        // Extension didn't respond, fall back to accessibility
        handleNonChromeClick(clickPoint: clickPoint, timestamp: timestamp, app: app, windowTitle: windowTitle, displayID: displayID)
    }

    private func handleNonChromeClick(clickPoint: CGPoint, timestamp: Date, app: NSRunningApplication, windowTitle: String, displayID: CGDirectDisplayID) {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"

        // Use accessibility API to get element info
        let elementInfo = accessibilityHelper.getElementInfo(at: clickPoint, for: app)

        let clickEvent = ClickEvent(
            timestamp: timestamp,
            x: clickPoint.x,
            y: clickPoint.y,
            app: appName,
            windowTitle: windowTitle,
            role: elementInfo.role,
            text: elementInfo.text,
            browserURL: "",
            docPath: elementInfo.docPath,
            displayID: displayID,
            source: "os"
        )

        logClickEvent(clickEvent)
    }

    private func logClickEvent(_ event: ClickEvent) {
        outputManager.logClick(event)
        print("Click logged: (\(Int(event.x)), \(Int(event.y))) - \(event.app) - \(event.source)")
    }

    private func getActiveWindowTitle(for app: NSRunningApplication) -> String {
        guard let appElement = AXUIElementCreateApplication(app.processIdentifier) as? AXUIElement else {
            return ""
        }

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let window = focusedWindow else {
            return ""
        }

        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)

        return title as? String ?? ""
    }

    private func getDisplayID(for point: CGPoint) -> CGDirectDisplayID {
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)

        guard CGGetOnlineDisplayList(16, &displays, &displayCount) == .success else {
            return CGMainDisplayID()
        }

        for i in 0..<Int(displayCount) {
            let displayID = displays[i]
            let bounds = CGDisplayBounds(displayID)

            if bounds.contains(point) {
                return displayID
            }
        }

        return CGMainDisplayID()
    }
}
