import SwiftUI
import AppKit

/// The `MenuBarExtra` dropdown (default `.menu` style). The PopClip-style chooser and richer
/// transport controls arrive in later increments.
struct MenuContent: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Text("SelectTTS — \(environment.status)")

        if !environment.accessibilityTrusted {
            Text("⚠︎ Accessibility not granted — open Settings")
        }

        // Note: capturing the *selection* must be triggered by the global hotkey — opening this menu
        // makes SelectTTS frontmost, so there is no live selection to read. The menu speaks the
        // clipboard instead.
        Button("Speak Clipboard") { environment.speakClipboard() }
        Button("Stop") { environment.stopSpeaking() }

        Divider()

        Text("Tip: select text, then press your global shortcut to speak it.")
        Text("Active voice: \(environment.activeProviderName)")

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit SelectTTS") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
