import Foundation

/// Handles Native Messaging communication with Chrome extension
/// Chrome extensions communicate via stdin/stdout with JSON messages
class NativeMessaging {
    var onMessageReceived: (([String: Any]) -> Void)?

    private var inputThread: Thread?
    private var isRunning = false

    func start() {
        isRunning = true

        // Start listening on stdin in background thread
        inputThread = Thread { [weak self] in
            self?.listenForMessages()
        }
        inputThread?.start()
    }

    func stop() {
        isRunning = false
    }

    /// Listens for messages from Chrome extension on stdin
    private func listenForMessages() {
        let inputHandle = FileHandle.standardInput

        while isRunning {
            autoreleasepool {
                // Native Messaging format: 4-byte length (little-endian) + JSON message
                var lengthBytes = Data(count: 4)
                let lengthData = inputHandle.readData(ofLength: 4)

                guard lengthData.count == 4 else {
                    // No more data or invalid
                    if lengthData.count == 0 {
                        // Normal EOF when Chrome closes
                        return
                    }
                    NSLog("Invalid length data received")
                    return
                }

                lengthBytes = lengthData

                // Convert to UInt32 (little-endian)
                let messageLength = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }

                guard messageLength > 0 && messageLength < 1024 * 1024 else {
                    NSLog("Invalid message length: \(messageLength)")
                    return
                }

                // Read message data
                let messageData = inputHandle.readData(ofLength: Int(messageLength))

                guard messageData.count == Int(messageLength) else {
                    NSLog("Incomplete message received")
                    return
                }

                // Parse JSON
                if let json = try? JSONSerialization.jsonObject(with: messageData, options: []) as? [String: Any] {
                    DispatchQueue.main.async {
                        self.onMessageReceived?(json)
                    }
                } else {
                    NSLog("Failed to parse JSON message")
                }
            }
        }
    }

    /// Sends a message to Chrome extension via stdout
    func sendMessage(_ message: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: []) else {
            NSLog("Failed to serialize message")
            return
        }

        let messageLength = UInt32(jsonData.count)
        var lengthBytes = withUnsafeBytes(of: messageLength.littleEndian) { Data($0) }

        // Write length + message to stdout
        FileHandle.standardOutput.write(lengthBytes)
        FileHandle.standardOutput.write(jsonData)
    }
}
