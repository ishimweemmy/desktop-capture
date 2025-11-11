import Foundation
import AppKit
import CoreGraphics

class OutputManager {
    let baseDir: String
    var currentDateFolder: String?

    private let fileManager = FileManager.default
    private let dateFormatter = ISO8601DateFormatter()

    private var ndjsonHandle: FileHandle?
    private var csvHandle: FileHandle?
    private var csvHeaderWritten = false

    init(baseDir: String) {
        self.baseDir = baseDir
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    deinit {
        closeLogFiles()
    }

    /// Creates today's output folder (YYYY-MM-DD)
    func createTodayFolder() {
        let today = getTodayFolderName()
        let folderPath = (baseDir as NSString).appendingPathComponent(today)

        currentDateFolder = folderPath

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)

        // Open log files
        openLogFiles()
    }

    /// Gets today's folder name in YYYY-MM-DD format (UTC)
    private func getTodayFolderName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    /// Opens log files for writing
    private func openLogFiles() {
        guard let folder = currentDateFolder else { return }

        let ndjsonPath = (folder as NSString).appendingPathComponent("clicks.ndjson")
        let csvPath = (folder as NSString).appendingPathComponent("clicks.csv")

        // Create files if they don't exist
        if !fileManager.fileExists(atPath: ndjsonPath) {
            fileManager.createFile(atPath: ndjsonPath, contents: nil, attributes: nil)
        }

        if !fileManager.fileExists(atPath: csvPath) {
            fileManager.createFile(atPath: csvPath, contents: nil, attributes: nil)
            csvHeaderWritten = false
        } else {
            csvHeaderWritten = true // Assume header exists if file exists
        }

        // Open file handles
        ndjsonHandle = FileHandle(forWritingAtPath: ndjsonPath)
        csvHandle = FileHandle(forWritingAtPath: csvPath)

        // Seek to end
        if #available(macOS 10.15.4, *) {
            try? ndjsonHandle?.seekToEnd()
            try? csvHandle?.seekToEnd()
        } else {
            ndjsonHandle?.seekToEndOfFile()
            csvHandle?.seekToEndOfFile()
        }

        // Write CSV header if needed
        if !csvHeaderWritten, let handle = csvHandle {
            let header = ClickEvent.csvHeader + "\n"
            if let data = header.data(using: .utf8) {
                if #available(macOS 10.15.4, *) {
                    try? handle.write(contentsOf: data)
                } else {
                    handle.write(data)
                }
                csvHeaderWritten = true
            }
        }
    }

    /// Closes log files
    private func closeLogFiles() {
        if #available(macOS 10.15, *) {
            try? ndjsonHandle?.close()
            try? csvHandle?.close()
        } else {
            ndjsonHandle?.closeFile()
            csvHandle?.closeFile()
        }
    }

    /// Saves a screenshot with UTC timestamp filename
    func saveScreenshot(_ image: CGImage, displayID: CGDirectDisplayID) {
        // Check if we need to create a new folder (date changed)
        let todayFolder = getTodayFolderName()
        let currentFolder = (currentDateFolder as NSString?)?.lastPathComponent

        if todayFolder != currentFolder {
            closeLogFiles()
            createTodayFolder()
        }

        guard let folder = currentDateFolder else { return }

        // Generate filename: YYYY-MM-DDTHH-MM-SS.mmmZ.png
        let timestamp = Date()
        let filename = getScreenshotFilename(timestamp, displayID: displayID)
        let filePath = (folder as NSString).appendingPathComponent(filename)

        // Convert CGImage to PNG and save
        if let pngData = image.pngData() {
            try? pngData.write(to: URL(fileURLWithPath: filePath))
        }
    }

    /// Generates screenshot filename with ISO-8601 format
    private func getScreenshotFilename(_ date: Date, displayID: CGDirectDisplayID) -> String {
        let isoString = dateFormatter.string(from: date)

        // Format: YYYY-MM-DDTHH-MM-SS.mmmZ.png
        // ISO8601 gives us: 2025-11-11T14:30:15.123Z
        // We need to replace colons with dashes for filesystem compatibility
        let formatted = isoString.replacingOccurrences(of: ":", with: "-")

        // Add display ID suffix if multiple displays
        let displaySuffix = displayID == CGMainDisplayID() ? "" : "-display\(displayID)"

        return "\(formatted)\(displaySuffix).png"
    }

    /// Logs a click event to both NDJSON and CSV files
    func logClick(_ event: ClickEvent) {
        // Check if we need to create a new folder
        let todayFolder = getTodayFolderName()
        let currentFolder = (currentDateFolder as NSString?)?.lastPathComponent

        if todayFolder != currentFolder {
            closeLogFiles()
            createTodayFolder()
        }

        // Write to NDJSON
        if let handle = ndjsonHandle {
            let ndjson = event.toNDJSON() + "\n"
            if let data = ndjson.data(using: .utf8) {
                if #available(macOS 10.15.4, *) {
                    try? handle.write(contentsOf: data)
                } else {
                    handle.write(data)
                }
            }
        }

        // Write to CSV
        if let handle = csvHandle {
            let csv = event.toCSVRow() + "\n"
            if let data = csv.data(using: .utf8) {
                if #available(macOS 10.15.4, *) {
                    try? handle.write(contentsOf: data)
                } else {
                    handle.write(data)
                }
            }
        }

        // Flush to disk
        if #available(macOS 10.15, *) {
            try? ndjsonHandle?.synchronize()
            try? csvHandle?.synchronize()
        } else {
            ndjsonHandle?.synchronizeFile()
            csvHandle?.synchronizeFile()
        }
    }
}
