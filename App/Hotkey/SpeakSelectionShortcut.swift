import Foundation
import KeyboardShortcuts

/// The global hotkey for "speak the current selection." KeyboardShortcuts is NSEvent-based, so it
/// needs Accessibility (not Input Monitoring) — the same grant capture already requires (§10).
extension KeyboardShortcuts.Name {
    static let speakSelection = Self("speakSelection")
    /// Optional dedicated stop key; unset by default (pressing the speak shortcut again also stops).
    static let stopSpeaking = Self("stopSpeaking")
}

/// Wraps KeyboardShortcuts registration so the rest of the app needn't import it.
enum SpeakSelectionShortcut {
    static func register(onSpeak: @escaping () -> Void, onStop: @escaping () -> Void) {
        let shortcut = KeyboardShortcuts.getShortcut(for: .speakSelection).map { "\($0)" } ?? "none"
        Log.speak.info("registering speak-selection hotkey: \(shortcut, privacy: .public)")
        KeyboardShortcuts.onKeyUp(for: .speakSelection) {
            Log.speak.info("speak-selection hotkey pressed")
            onSpeak()
        }
        KeyboardShortcuts.onKeyUp(for: .stopSpeaking) {
            Log.speak.info("stop-speaking hotkey pressed")
            onStop()
        }
    }
}
