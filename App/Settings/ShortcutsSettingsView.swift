import SwiftUI
import KeyboardShortcuts

/// Global hotkey recorder + Accessibility permission status (§10). Lives in its own file so the
/// KeyboardShortcuts import stays isolated.
struct ShortcutsSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Speak selection:", name: .speakSelection)
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Label(
                        environment.accessibilityTrusted ? "Granted" : "Not granted",
                        systemImage: environment.accessibilityTrusted
                            ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(environment.accessibilityTrusted ? .green : .orange)
                }
                HStack {
                    Button("Request…") { environment.requestAccessibilityPermission() }
                    Button("Open Settings") { environment.openAccessibilitySettings() }
                    Button("Re-check") { environment.refreshPermissions() }
                }
                Text("Accessibility lets SelectTTS read selected text in most apps and post the copy "
                    + "shortcut. Browser web selections also use Automation, prompted per-app on first use. "
                    + "After granting, you may need to relaunch SelectTTS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
