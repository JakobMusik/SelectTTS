import AppSettings
import SelectionCapture
import SwiftUI

/// Settings window: General · Providers · Shortcuts · About.
struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ProvidersSettingsView()
                .tabItem { Label("Providers", systemImage: "person.2") }

            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "command") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 560)
        .onAppear {
            environment.refreshPermissions()
            environment.refreshLaunchAtLogin()
        }
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section {
                Toggle("Open SelectTTS at login", isOn: Binding(
                    get: { environment.launchAtLogin != .disabled },
                    set: { environment.setLaunchAtLogin($0) }
                ))
                if environment.launchAtLogin == .requiresApproval {
                    HStack {
                        Text(verbatim: "Allow SelectTTS in System Settings ▸ General ▸ Login Items.")
                            .font(.footnote).foregroundStyle(.orange)
                        Spacer()
                        Button("Open Login Items") { LaunchAtLogin.openLoginItemsSettings() }
                    }
                }
            }
            Section {
                LabeledContent("Active voice", value: environment.activeProviderName)
                LabeledContent("Status") {
                    Text(verbatim: environment.status)
                        .foregroundStyle(environment.statusIsError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .textSelection(.enabled)
                }
                Button("Speak a sample") { environment.speakSample() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsView: View {
    @State private var showingLicenses = false

    var body: some View {
        VStack(spacing: 8) {
            Text("SelectTTS").font(.title2).bold()
            Text("Speak selected text from any app.").foregroundStyle(.secondary)
            Text("Open source · MIT License").font(.footnote).foregroundStyle(.secondary)
            Button("Third-Party Licenses…") { showingLicenses = true }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sheet(isPresented: $showingLicenses) { LicensesView() }
    }
}

#Preview("General") {
    GeneralSettingsView()
        .environmentObject(AppEnvironment(
            capturer: StubSelectionCapturer(text: "Preview"),
            settings: InMemorySettingsStore(),
            secrets: InMemorySecretStore()
        ))
        .frame(width: 520, height: 500)
}
