import SwiftUI
import AppKit

/// The `MenuBarExtra` dropdown (default `.menu` style). Increment 1 is a smoke-test menu; the
/// PopClip-style chooser and richer transport controls arrive in later increments.
struct MenuContent: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Text("SelectTTS — \(environment.status)")

        Button("Speak Sample") { environment.speakSample() }
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
