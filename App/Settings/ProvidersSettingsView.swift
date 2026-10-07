import SwiftUI
import AppSettings
import Providers
import SelectionCapture
import SpeechCore

/// Create/edit/delete provider profiles, store API keys in the Keychain, pick the active profile,
/// and test a profile before switching to it (§8/§9).
///
/// Placeholder and footnote strings that contain URLs use verbatim `Text`: a `LocalizedStringKey`
/// is parsed as Markdown, which turns bare URLs into blue links and styles a placeholder like typed
/// text.
struct ProvidersSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var selectedID: String = ""
    @State private var draft: ProviderConfig = .systemDefault
    @State private var apiKey: String = ""
    /// Last four characters of the key stored for `draft` (nil = none), refreshed on load/save.
    @State private var storedKeySuffix: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profilePicker
                    Divider()
                    editor
                }
                .padding(20)
            }
            // Pinned below the scrolling editor so Save/Test and their result are always visible.
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                actions
                statusLine
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
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
                    Text(verbatim: label(for: config)).tag(config.id)
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

    private var editor: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 12) {
            row("Name") {
                TextField("Name", text: $draft.name, prompt: Text(verbatim: "Profile name"))
                    .labelsHidden()
            }

            if draft.kind == .openAICompatible {
                row("Base URL") {
                    TextField("Base URL", text: bind(\.baseURLString),
                              prompt: Text(verbatim: "https://api.openai.com/v1"))
                        .labelsHidden()
                    footnote("OpenAI, Groq (https://api.groq.com/openai/v1), or a local server such as "
                        + "Kokoro-FastAPI (http://localhost:8880/v1). Not LM Studio/Ollama — they have no "
                        + "TTS endpoint.")
                }
            }
            if draft.kind == .elevenLabs {
                row("Base URL") {
                    TextField("Base URL", text: bind(\.baseURLString),
                              prompt: Text(verbatim: "https://api.elevenlabs.io (default)"))
                        .labelsHidden()
                    footnote("Leave empty for the global API. Data-residency workspaces use their own host: "
                        + "https://api.us.elevenlabs.io · https://api.eu.residency.elevenlabs.io · "
                        + "https://api.in.residency.elevenlabs.io · https://api.sg.residency.elevenlabs.io")
                }
            }

            if draft.kind != .system {
                row("API Key") {
                    SecureField("API Key", text: $apiKey, prompt: Text(verbatim: keyPrompt))
                        .labelsHidden()
                    keyStatus
                }

                row("Model") {
                    if fetchedModels.isEmpty {
                        TextField("Model", text: bind(\.model), prompt: Text(verbatim: modelPrompt))
                            .labelsHidden()
                        if draft.kind == .elevenLabs {
                            footnote("eleven_multilingual_v2 (default) · eleven_v4 (most expressive) · "
                                + "eleven_v4_turbo or eleven_flash_v2_5 (lowest latency). Save a key to "
                                + "pick from your account's models.")
                        }
                    } else {
                        modelPicker
                    }
                }
            }

            row("Voice") {
                HStack {
                    TextField("Voice", text: bind(\.voice),
                              prompt: Text(verbatim: draft.kind == .elevenLabs ? "Voice ID" : "Voice name"))
                        .labelsHidden()
                    if draft.kind == .elevenLabs {
                        Button("Refresh") { save(); env.refreshCatalog(for: draft) }
                            .help("Reload voices and models from ElevenLabs")
                    }
                }
                if draft.kind == .elevenLabs { voicePicker }
            }

            row("Format") {
                Picker("Format", selection: $draft.format) {
                    ForEach(AudioFormat.allCases, id: \.self) { format in
                        Text(verbatim: format.rawValue.uppercased()).tag(format)
                    }
                }
                .labelsHidden()
                .fixedSize()
                if draft.kind == .elevenLabs {
                    footnote("ElevenLabs streams 24 kHz PCM (low latency); WAV maps to PCM. MP3/Opus/other "
                        + "formats can't be played yet.", warning: !draft.format.isStreamable)
                } else if !draft.format.isStreamable {
                    footnote("\(draft.format.rawValue.uppercased()) isn't streamed yet — use WAV or PCM for "
                        + "low-latency playback.", warning: true)
                }
            }

            row("Speed") {
                HStack {
                    Slider(value: $draft.speed, in: speedRange)
                    Text(verbatim: String(format: "%.2f×", draft.speed)).monospacedDigit().frame(width: 48)
                }
            }
        }
    }

    /// One labelled grid row: a trailing-aligned label, then the field(s) and any footnote under it.
    private func row(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        GridRow {
            Text(verbatim: label)
                .gridColumnAlignment(.trailing)
            VStack(alignment: .leading, spacing: 6) { content() }
        }
    }

    private func footnote(_ text: String, warning: Bool = false) -> some View {
        Text(verbatim: warning ? "⚠︎ " + text : text)
            .font(.footnote)
            .foregroundStyle(warning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - API key

    private var keyPrompt: String {
        storedKeySuffix == nil ? "Paste your API key" : "•••• saved — type to replace"
    }

    /// Whether a key is saved for this profile, and whether the field holds an unsaved new one.
    @ViewBuilder
    private var keyStatus: some View {
        if !apiKey.isEmpty {
            Label { Text(verbatim: "New key — click Save to store it") } icon: {
                Image(systemName: "pencil.circle.fill")
            }
            .font(.footnote).foregroundStyle(.blue)
        } else if let suffix = storedKeySuffix {
            Label { Text(verbatim: "Saved in Keychain (ends in …\(suffix))") } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.footnote).foregroundStyle(.green)
        } else {
            Label {
                Text(verbatim: draft.kind == .elevenLabs
                    ? "Not set — the key needs Text to Speech access (and Voices read for Fetch Voices)."
                    : "Not set — local servers accept any value.")
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.footnote).foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelPrompt: String {
        draft.kind == .elevenLabs ? ElevenLabsRequestBuilder.defaultModelID : "e.g. gpt-4o-mini-tts or tts-1"
    }

    // MARK: - Model catalog (ElevenLabs)

    private var fetchedModels: [SpeechModel] {
        env.fetchedModelsProviderID == draft.id ? env.fetchedModels : []
    }

    /// The profile's model, or the provider default the request falls back to when none is set.
    private var currentModelID: String {
        draft.model ?? (draft.kind == .elevenLabs ? ElevenLabsRequestBuilder.defaultModelID : "")
    }

    /// Dropdown of the account's text-to-speech models (API order, newest first). A model id that
    /// isn't in the list (typed earlier, or retired) stays selectable so it is never silently lost.
    @ViewBuilder
    private var modelPicker: some View {
        let models = fetchedModels
        let current = currentModelID
        Picker("Model", selection: Binding(get: { current }, set: { draft.model = $0 })) {
            ForEach(models) { model in
                Text(verbatim: Self.label(for: model)).tag(model.id)
            }
            if !models.contains(where: { $0.id == current }) {
                Divider()
                Text(verbatim: "\(current) (not in your account's list)").tag(current)
            }
        }
        .labelsHidden()
        .fixedSize()
        if let model = models.first(where: { $0.id == current }) {
            footnote(Self.details(for: model))
        } else {
            footnote("This model isn't offered for your account — requests may fail.", warning: true)
        }
    }

    private static func label(for model: SpeechModel) -> String {
        guard let cost = model.costMultiplier, abs(cost - 1) > 0.001 else { return model.name }
        return "\(model.name)  ·  \(cost.formatted())× credits"
    }

    private static func details(for model: SpeechModel) -> String {
        var parts = [model.id]
        if let max = model.maxInputCharacters { parts.append("up to \(max.formatted()) characters per request") }
        if let cost = model.costMultiplier, abs(cost - 1) > 0.001 {
            parts.append("\(cost.formatted())× credits per character")
        }
        let facts = parts.joined(separator: " · ")
        return model.summary.map { "\($0)\n\(facts)" } ?? facts
    }

    // MARK: - Voice catalog (ElevenLabs)

    private var fetchedVoices: [Voice] {
        env.fetchedVoicesProviderID == draft.id ? env.fetchedVoices : []
    }

    /// Fetched voices, usable ones first; voices with a caveat (e.g. library voices that need a paid
    /// plan) are grouped under that caveat and flagged.
    @ViewBuilder
    private var voicePicker: some View {
        let voices = fetchedVoices
        if !voices.isEmpty {
            let plain = voices.filter { $0.note == nil }
            let caveated = Dictionary(grouping: voices.filter { $0.note != nil }) { $0.note ?? "" }
            Menu("Pick a fetched voice (\(voices.count))") {
                ForEach(plain) { voice in
                    Button { draft.voice = voice.id } label: { Text(verbatim: voice.name) }
                }
                ForEach(caveated.keys.sorted(), id: \.self) { note in
                    Divider()
                    Section {
                        ForEach(caveated[note] ?? []) { voice in
                            Button { draft.voice = voice.id } label: { Text(verbatim: "⚠︎ " + voice.name) }
                        }
                    } header: {
                        Text(verbatim: note)
                    }
                }
            }
            .fixedSize()
        }
        if let voice = voices.first(where: { $0.id == draft.voice }) {
            footnote(voice.note.map { "\(voice.name) — \($0)" } ?? voice.name, warning: voice.note != nil)
        }
    }

    // MARK: - Actions + status

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
    }

    /// The app status (test results, fetch results, errors such as "HTTP 402: …"), shown here so a
    /// failed Test Voice is never silent.
    private var statusLine: some View {
        Label {
            Text(verbatim: env.status)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: env.statusIsError ? "exclamationmark.triangle.fill" : "info.circle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.callout)
        .foregroundStyle(env.statusIsError ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
    }

    /// ElevenLabs only accepts 0.7–1.2× (`voice_settings.speed`); everything else takes 0.25–4×.
    private var speedRange: ClosedRange<Double> {
        draft.kind == .elevenLabs
            ? ElevenLabsRequestBuilder.speedRange
            : SpeechRequest.minSpeed...SpeechRequest.maxSpeed
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
            storedKeySuffix = env.storedKeySuffix(for: config)
            // Load the catalogs once per profile so the model dropdown and the current voice's name
            // (and any caveat, e.g. a library voice on a free plan) show without an extra click.
            if config.kind == .elevenLabs, storedKeySuffix != nil, env.fetchedVoicesProviderID != config.id {
                env.refreshCatalog(for: config)
            }
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
        storedKeySuffix = env.storedKeySuffix(for: draft)
    }

    private func delete() {
        env.deleteProvider(draft.id)
        selectedID = env.activeProviderID
        loadDraft(selectedID)
    }
}

#Preview("Providers — ElevenLabs") {
    let profile = ProviderConfig(
        id: "preview-el", kind: .elevenLabs, name: "ElevenLabs", apiKeyKeychainRef: "apikey.preview-el",
        model: "eleven_v4", voice: "lib1", format: .pcm, capabilities: ProviderCapabilities()
    )
    let secrets = InMemorySecretStore()
    try? secrets.set("sk_preview_0000c95", for: "apikey.preview-el")
    let env = AppEnvironment(
        capturer: StubSelectionCapturer(text: "Preview"),
        settings: InMemorySettingsStore(configs: [.systemDefault, profile], activeID: profile.id),
        secrets: secrets
    )
    env.showFetchedVoices([
        Voice(id: "george", name: "George - Warm, Captivating Storyteller"),
        Voice(id: "lib1", name: "Allison - Cowgirl", note: ElevenLabsVoiceList.libraryVoiceNote),
    ], for: profile.id)
    env.showFetchedModels([
        SpeechModel(id: "eleven_v4", name: "Eleven v4", summary: "Our fastest and most emotive model.",
                    maxInputCharacters: 10_000, costMultiplier: 1),
        SpeechModel(id: "eleven_v4_turbo", name: "Eleven v4 Turbo", maxInputCharacters: 10_000, costMultiplier: 0.5),
    ], for: profile.id)
    return ProvidersSettingsView()
        .environmentObject(env)
        .frame(width: 520, height: 500) // ≈ the Providers tab inside the 520×560 Settings window
}
