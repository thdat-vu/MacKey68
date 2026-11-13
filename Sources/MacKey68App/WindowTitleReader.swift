// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import ApplicationServices

/// Reads the focused window title of another app. Requires Accessibility.
enum WindowTitleReader {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func frontmost() -> (bundleID: String?, title: String?)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return (app.bundleIdentifier, title(for: app))
    }

    static func title(for app: NSRunningApplication) -> String? {
        guard isTrusted else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)

        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var windowRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element,
                                                attribute as CFString,
                                                &windowRef) == .success,
                  let windowRef else { continue }
            let window = unsafeBitCast(windowRef, to: AXUIElement.self)
            var titleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window,
                                                kAXTitleAttribute as CFString,
                                                &titleRef) == .success,
                  let title = titleRef as? String,
                  !title.isEmpty else { continue }
            return title
        }
        return nil
    }
}
