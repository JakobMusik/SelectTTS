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

        Button("Speak Selection") { environment.speakSelection() }
        Button("Speak Sample (test voice)") { environment.speakSample() }
        Button("Stop") { environment.stopSpeaking() }

        Divider()

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
