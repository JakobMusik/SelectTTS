import SwiftUI
import AppSettings
import SpeechCore

/// Create/edit/delete provider profiles, store API keys in the Keychain, pick the active profile,
/// and test a profile before switching to it (§8/§9).
struct ProvidersSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var selectedID: String = ""
    @State private var draft: ProviderConfig = .systemDefault
    @State private var apiKey: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profilePicker
                Divider()
                editor
            }
            .padding(20)
        }
        .onAppear {
            if selectedID.isEmpty { selectedID = env.activeProviderID }
            loadDraft(selectedID)
        }
        .onChange(of: selectedID) { _, newID in loadDraft(newID) }
    }

    // MARK: - Picker + Add

    private var profilePicker: some View {
        HStack {
            Picker("Profile", selection: $selectedID) {
                ForEach(env.providerConfigs) { config in
                    Text(label(for: config)).tag(config.id)
                }
            }
            Menu("Add") {
                Button("OpenAI-compatible") { addProvider(.openAICompatible) }
                Button("ElevenLabs") { addProvider(.elevenLabs) }
                Button("System Voice") { addProvider(.system) }
            }
            .fixedSize()
        }
    }

    private func label(for config: ProviderConfig) -> String {
        config.id == env.activeProviderID ? "● \(config.name) (active)" : config.name
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $draft.name)

            if draft.kind == .openAICompatible {
                TextField("Base URL", text: bind(\.baseURLString))
                Text("e.g. https://api.openai.com/v1 · Groq · or a local server like Kokoro-FastAPI "
                    + "(http://localhost:8880/v1). Not LM Studio/Ollama — those have no TTS endpoint.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if draft.kind != .system {
                SecureField("API Key", text: $apiKey)
                Text(env.hasStoredKey(for: draft)
                    ? "A key is stored in the Keychain. Type to replace it."
                    : "No key stored. Local servers can use any value.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if draft.kind != .system {
                TextField("Model", text: bind(\.model))
            }

            HStack {
                TextField(draft.kind == .elevenLabs ? "Voice ID" : "Voice", text: bind(\.voice))
                if draft.kind == .elevenLabs {
                    Button("Fetch Voices") { save(); env.refreshVoices(for: draft) }
                }
            }
            if draft.kind == .elevenLabs,
               env.fetchedVoicesProviderID == draft.id, !env.fetchedVoices.isEmpty {
                Menu("Pick a fetched voice (\(env.fetchedVoices.count))") {
                    ForEach(env.fetchedVoices) { voice in
                        Button(voice.name) { draft.voice = voice.id }
                    }
                }
                .fixedSize()
            }

            Picker("Format", selection: $draft.format) {
                ForEach(AudioFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            if draft.kind == .elevenLabs {
                Text("ElevenLabs streams as PCM (low latency). WAV maps to PCM; MP3/other formats are "
                    + "fetched but won't play through the streaming engine yet.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !draft.format.isStreamable {
                Text("⚠︎ \(draft.format.rawValue.uppercased()) isn't streamed yet — use WAV or PCM for "
                    + "low-latency playback.")
                    .font(.footnote).foregroundStyle(.orange)
            }

            HStack {
                Text("Speed")
                Slider(value: $draft.speed, in: 0.25...4.0)
                Text(String(format: "%.2f×", draft.speed)).monospacedDigit().frame(width: 48)
            }

            actions
        }
    }

    private var actions: some View {
        HStack {
            Button("Save") { save() }
            Button("Test Voice") { save(); env.testProvider(draft) }
            if env.activeProviderID != draft.id {
                Button("Set as Active") { env.setActiveProvider(draft.id) }
            }
            Spacer()
            if draft.id != ProviderConfig.systemDefault.id {
                Button("Delete", role: .destructive) { delete() }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - State plumbing

    /// Two-way binding for an optional `String` field, treating empty as `nil`.
    private func bind(_ keyPath: WritableKeyPath<ProviderConfig, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func loadDraft(_ id: String) {
        if let config = env.providerConfigs.first(where: { $0.id == id }) {
            draft = config
            apiKey = ""
        }
    }

    private func addProvider(_ kind: ProviderKind) {
        let config = env.makeNewProvider(kind: kind)
        env.upsertProvider(config)
        selectedID = config.id
        loadDraft(config.id)
    }

    private func save() {
        env.upsertProvider(draft)
        if !apiKey.isEmpty {
            env.storeKey(apiKey, for: draft)
            apiKey = ""
        }
    }

    private func delete() {
        env.deleteProvider(draft.id)
        selectedID = env.activeProviderID
        loadDraft(selectedID)
    }
}
