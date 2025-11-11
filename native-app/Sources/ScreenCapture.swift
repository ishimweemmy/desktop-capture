import Foundation
import AppKit
import CoreGraphics
import CoreImage

class ScreenCapture {

    /// Captures all connected displays with cursor visible
    /// Returns dictionary of [displayID: CGImage]
    func captureAllDisplays() -> [CGDirectDisplayID: CGImage]? {
        var result: [CGDirectDisplayID: CGImage] = [:]

        // Get all online displays
        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)

        guard CGGetOnlineDisplayList(16, &displays, &displayCount) == .success else {
            NSLog("Failed to get display list")
            return nil
        }

        // Capture each display
        for i in 0..<Int(displayCount) {
            let displayID = displays[i]

            if let image = captureDisplay(displayID) {
                result[displayID] = image
            }
        }

        return result.isEmpty ? nil : result
    }

    /// Captures a single display with cursor
    private func captureDisplay(_ displayID: CGDirectDisplayID) -> CGImage? {
        // Capture the display
        guard let baseImage = CGDisplayCreateImage(displayID) else {
            NSLog("Failed to capture display \(displayID)")
            return nil
        }

        // Draw cursor on top
        return drawCursorOnImage(baseImage, displayID: displayID)
    }

    /// Draws the system cursor on the captured image
    private func drawCursorOnImage(_ baseImage: CGImage, displayID: CGDirectDisplayID) -> CGImage? {
        let width = baseImage.width
        let height = baseImage.height

        // Create bitmap context
        guard let colorSpace = baseImage.colorSpace else { return baseImage }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return baseImage
        }

        // Draw base image
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get cursor image and position
        let cursorPosition = NSEvent.mouseLocation

        // Convert cursor position to display-relative coordinates
        let displayBounds = CGDisplayBounds(displayID)

        // Check if cursor is on this display
        if !displayBounds.contains(cursorPosition) {
            // Cursor not on this display, just return base image
            return context.makeImage()
        }

        // Calculate cursor position relative to display
        let relativeX = cursorPosition.x - displayBounds.origin.x
        let relativeY = cursorPosition.y - displayBounds.origin.y

        // Flip Y coordinate (Quartz has origin at bottom-left)
        let flippedY = CGFloat(height) - relativeY

        // Draw cursor
        drawSystemCursor(at: CGPoint(x: relativeX, y: flippedY), in: context)

        return context.makeImage()
    }

    /// Draws a simple cursor representation
    /// Note: Getting the actual system cursor image requires private APIs
    /// For v0, we draw a simple arrow cursor
    private func drawSystemCursor(at position: CGPoint, in context: CGContext) {
        context.saveGState()

        // Draw cursor shadow for visibility
        context.setShadow(offset: CGSize(width: 1, height: -1), blur: 2, color: CGColor(gray: 0, alpha: 0.5))

        // Draw white arrow cursor outline
        context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let cursorPath = createCursorPath(at: position)
        context.addPath(cursorPath)
        context.strokePath()

        // Draw black arrow cursor fill
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.addPath(cursorPath)
        context.fillPath()

        context.restoreGState()
    }

    /// Creates a cursor arrow path
    private func createCursorPath(at position: CGPoint) -> CGPath {
        let path = CGMutablePath()
        let size: CGFloat = 16

        // Arrow points
        path.move(to: position)
        path.addLine(to: CGPoint(x: position.x, y: position.y + size))
        path.addLine(to: CGPoint(x: position.x + size * 0.35, y: position.y + size * 0.65))
        path.addLine(to: CGPoint(x: position.x + size * 0.5, y: position.y + size))
        path.addLine(to: CGPoint(x: position.x + size * 0.7, y: position.y + size * 0.55))
        path.addLine(to: CGPoint(x: position.x + size, y: position.y + size * 0.5))
        path.addLine(to: CGPoint(x: position.x + size * 0.55, y: position.y + size * 0.35))
        path.closeSubpath()

        return path
    }
}

// MARK: - Helper Extensions

extension CGImage {
    /// Converts CGImage to PNG data
    func pngData() -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, self, nil)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return mutableData as Data
    }
}
