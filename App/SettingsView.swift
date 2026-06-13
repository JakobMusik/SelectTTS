import SwiftUI

/// Settings window scaffold. Panes fill in over the increments: General · Modules · Providers ·
/// Shortcuts · Permissions/About (§9).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            PlaceholderPane(text: "Provider profiles arrive in increment 3.")
                .tabItem { Label("Providers", systemImage: "person.2") }

            PlaceholderPane(text: "Global hotkey & permissions arrive in increment 2.")
                .tabItem { Label("Shortcuts", systemImage: "command") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 280)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            LabeledContent("Active voice", value: environment.activeProviderName)
            LabeledContent("Status", value: environment.status)
            Button("Speak a sample") { environment.speakSample() }
        }
        .padding()
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("SelectTTS").font(.title2).bold()
            Text("Speak selected text from any app.").foregroundStyle(.secondary)
            Text("Open source · MIT License").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct PlaceholderPane: View {
    let text: String
    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}
