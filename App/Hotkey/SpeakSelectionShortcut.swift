import Foundation
import KeyboardShortcuts

/// The global hotkey for "speak the current selection." KeyboardShortcuts is NSEvent-based, so it
/// needs Accessibility (not Input Monitoring) — the same grant capture already requires (§10).
extension KeyboardShortcuts.Name {
    static let speakSelection = Self("speakSelection")
}

/// Wraps KeyboardShortcuts registration so the rest of the app needn't import it.
enum SpeakSelectionShortcut {
    static func register(action: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .speakSelection) {
            action()
        }
    }
}
