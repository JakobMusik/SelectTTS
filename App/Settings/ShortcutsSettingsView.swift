import SwiftUI
import KeyboardShortcuts

/// Global hotkey recorder + Accessibility permission status (§10).
///
/// Deliberately NOT a `Form`: `KeyboardShortcuts.Recorder` is an NSSearchField-backed control, and
/// inside a grouped Form its field overlaps the label column. A plain VStack with an explicit label
/// lays it out cleanly.
struct ShortcutsSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Shortcuts").font(.headline)
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Speak selection:").gridColumnAlignment(.trailing)
                        KeyboardShortcuts.Recorder(for: .speakSelection)
                    }
                    GridRow {
                        Text("Stop speaking:")
                        KeyboardShortcuts.Recorder(for: .stopSpeaking)
                    }
                }
                Text("Select text in any app, then press the speak shortcut to hear it. Press it again "
                    + "while speaking to stop. The stop shortcut is optional — leave it empty unless you "
                    + "want a dedicated key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions").font(.headline)
                HStack(spacing: 8) {
                    Image(systemName: environment.accessibilityTrusted
                        ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(environment.accessibilityTrusted ? .green : .orange)
                    Text("Accessibility: \(environment.accessibilityTrusted ? "Granted" : "Not granted")")
                }
                HStack {
                    Button("Request…") { environment.requestAccessibilityPermission() }
                    Button("Open Settings") { environment.openAccessibilitySettings() }
                    Button("Re-check") { environment.refreshPermissions() }
                }
                Text("Accessibility lets SelectTTS read selected text and post the copy shortcut. "
                    + "Browser web selections also use Automation, prompted per-app on first use. "
                    + "After granting, you may need to relaunch SelectTTS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
