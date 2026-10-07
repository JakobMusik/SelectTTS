import AppKit
import ApplicationServices
import Foundation

/// Thin wrapper over the Accessibility (kTCCServiceAccessibility) TCC checks. Accessibility
/// is required for the AX read + menu-AXPress + simulated-⌘C capture strategies; the browser
/// AppleScript path uses Automation instead (prompted per-app on first use).
enum AccessibilityAuthorization {

    /// Whether this process is currently trusted for the Accessibility API.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Trigger the system prompt to grant Accessibility (shows the "Open System Settings" alert the
    /// first time). Returns the current trust state. Note: a granted change usually requires an app
    /// relaunch before `AXIsProcessTrusted()` flips to true.
    @discardableResult
    static func prompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Deep-link to System Settings → Privacy & Security → Accessibility.
    static func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
