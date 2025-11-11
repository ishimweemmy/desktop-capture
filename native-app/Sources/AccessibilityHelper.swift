import Foundation
import AppKit
import ApplicationServices

struct ElementInfo {
    let role: String
    let text: String
    let docPath: String
}

class AccessibilityHelper {

    /// Gets information about the UI element at the given point
    func getElementInfo(at point: CGPoint, for app: NSRunningApplication) -> ElementInfo {
        guard let element = getElementAtPoint(point, for: app) else {
            return ElementInfo(role: "", text: "", docPath: "")
        }

        let role = getRole(for: element)
        let text = getText(for: element)
        let docPath = getDocumentPath(for: element, app: app)

        return ElementInfo(role: role, text: text, docPath: docPath)
    }

    /// Gets the UI element at the given screen point
    private func getElementAtPoint(_ point: CGPoint, for app: NSRunningApplication) -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &elementRef)

        if result == .success, let element = elementRef {
            return element
        }

        return nil
    }

    /// Gets the role of the UI element
    private func getRole(for element: AXUIElement) -> String {
        var roleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)

        if result == .success, let role = roleRef as? String {
            // Simplify role names (remove "AX" prefix)
            return role.replacingOccurrences(of: "AX", with: "").lowercased()
        }

        return "element"
    }

    /// Gets text content from the UI element
    private func getText(for element: AXUIElement) -> String {
        // Try different text attributes
        let textAttributes = [
            kAXValueAttribute,
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute
        ]

        for attribute in textAttributes {
            var valueRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef)

            if result == .success, let text = valueRef as? String, !text.isEmpty {
                return text
            }
        }

        // Try to get selected text
        if let selectedText = getSelectedText(for: element) {
            return selectedText
        }

        return ""
    }

    /// Gets selected text from text fields/areas
    private func getSelectedText(for element: AXUIElement) -> String? {
        var selectedTextRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextRef)

        if result == .success, let text = selectedTextRef as? String {
            return text
        }

        return nil
    }

    /// Gets the document path for PDF viewers and other document apps
    func getDocumentPath(for element: AXUIElement, app: NSRunningApplication) -> String {
        // Check if this is a PDF viewer
        let bundleID = app.bundleIdentifier ?? ""

        // Preview.app or Adobe Reader
        if bundleID.contains("Preview") || bundleID.contains("Reader") || bundleID.contains("Acrobat") {
            return getDocumentPathFromApp(element)
        }

        return ""
    }

    /// Extracts document path from application's accessibility tree
    private func getDocumentPathFromApp(_ element: AXUIElement) -> String {
        // Try to get the document attribute
        var docRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDocumentAttribute as CFString, &docRef)

        if result == .success, let docPath = docRef as? String {
            // Clean up file:// URLs
            if docPath.hasPrefix("file://") {
                let path = docPath.replacingOccurrences(of: "file://", with: "")
                return path.removingPercentEncoding ?? path
            }
            return docPath
        }

        // Try to traverse up to find window with document
        if let window = getParentWindow(element) {
            var docRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &docRef)

            if result == .success, let docPath = docRef as? String {
                if docPath.hasPrefix("file://") {
                    let path = docPath.replacingOccurrences(of: "file://", with: "")
                    return path.removingPercentEncoding ?? path
                }
                return docPath
            }

            // Try title as fallback (might contain filename)
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title.hasSuffix(".pdf") {
                return title
            }
        }

        return ""
    }

    /// Gets the parent window of an element
    private func getParentWindow(_ element: AXUIElement) -> AXUIElement? {
        var current = element
        var iterations = 0
        let maxIterations = 20 // Prevent infinite loops

        while iterations < maxIterations {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)

            if let role = roleRef as? String, role == kAXWindowRole as String {
                return current
            }

            var parentRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef)

            guard result == .success, let parent = parentRef else {
                break
            }

            current = parent as! AXUIElement
            iterations += 1
        }

        return nil
    }
}
