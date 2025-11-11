import Foundation
import AppKit
import CoreGraphics

// MARK: - Command Line Arguments

struct Config {
    let hz: Double
    let outputDir: String

    static func parse() -> Config {
        var hz: Double = 1.0
        var outputDir = NSString(string: "~/Desktop/captures").expandingTildeInPath

        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            switch args[i] {
            case "--hz":
                if i + 1 < args.count, let value = Double(args[i + 1]) {
                    hz = value
                    i += 2
                } else {
                    print("Error: --hz requires a numeric value")
                    exit(1)
                }
            case "--output":
                if i + 1 < args.count {
                    outputDir = NSString(string: args[i + 1]).expandingTildeInPath
                    i += 2
                } else {
                    print("Error: --output requires a path")
                    exit(1)
                }
            case "--help", "-h":
                printUsage()
                exit(0)
            default:
                print("Unknown argument: \(args[i])")
                printUsage()
                exit(1)
            }
        }

        return Config(hz: hz, outputDir: outputDir)
    }

    static func printUsage() {
        print("""
        Desktop Capture v0 - macOS Screenshot and Click Logger

        Usage: DesktopCapture [options]

        Options:
          --hz <number>      Screenshot capture rate in Hz (default: 1.0)
          --output <path>    Output directory (default: ~/Desktop/captures)
          --help, -h         Show this help message

        Permissions Required:
          - Accessibility: For click monitoring and window info
          - Screen Recording: For capturing screenshots

        Output Structure:
          <output-dir>/YYYY-MM-DD/
            - YYYY-MM-DDTHH-MM-SS.mmmZ.png (screenshots)
            - clicks.ndjson (click logs in JSON format)
            - clicks.csv (click logs in CSV format)
        """)
    }
}

// MARK: - Main Application

class DesktopCaptureApp {
    let config: Config
    let outputManager: OutputManager
    let screenCapture: ScreenCapture
    let clickMonitor: ClickMonitor
    let nativeMessaging: NativeMessaging
    let accessibilityHelper: AccessibilityHelper

    var captureTimer: Timer?

    init(config: Config) {
        self.config = config
        self.outputManager = OutputManager(baseDir: config.outputDir)
        self.screenCapture = ScreenCapture()
        self.accessibilityHelper = AccessibilityHelper()

        // Native messaging needs reference to output manager
        self.nativeMessaging = NativeMessaging()

        // Click monitor needs to coordinate with native messaging
        self.clickMonitor = ClickMonitor(
            accessibilityHelper: accessibilityHelper,
            nativeMessaging: nativeMessaging,
            outputManager: outputManager
        )
    }

    func run() {
        // Check permissions
        checkPermissions()

        // Create output directory
        outputManager.createTodayFolder()

        print("Desktop Capture v0 started")
        print("Capture rate: \(config.hz) Hz")
        print("Output directory: \(config.outputDir)")
        print("")
        print("Monitoring clicks and capturing screenshots...")
        print("Press Ctrl+C to stop")

        // Start native messaging listener (runs on background thread)
        nativeMessaging.start()

        // Start click monitor
        clickMonitor.start()

        // Start screenshot capture timer
        let interval = 1.0 / config.hz
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureScreenshot()
        }

        // Run the main run loop
        RunLoop.main.run()
    }

    func checkPermissions() {
        // Check Accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            print("⚠️  Accessibility permission required!")
            print("Please grant access in: System Settings > Privacy & Security > Accessibility")
            print("Then restart this app.")
            print("")
        }

        // Check Screen Recording permission (will prompt on first screenshot)
        if #available(macOS 10.15, *) {
            print("Note: Screen Recording permission will be requested on first screenshot")
            print("Grant access in: System Settings > Privacy & Security > Screen Recording")
            print("")
        }
    }

    func captureScreenshot() {
        guard let images = screenCapture.captureAllDisplays() else {
            return
        }

        for (displayID, image) in images {
            outputManager.saveScreenshot(image, displayID: displayID)
        }
    }
}

// MARK: - Entry Point

let config = Config.parse()
let app = DesktopCaptureApp(config: config)
app.run()
