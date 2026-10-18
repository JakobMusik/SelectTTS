import AppSettings
import Providers
import SelectionCapture
import SpeechCore
import SwiftUI

/// Create/edit/delete provider profiles, store API keys in the Keychain, pick the active profile,
/// and test a profile before switching to it.
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
                    TextField(
                        "Base URL",
                        text: bind(\.baseURLString),
                        prompt: Text(verbatim: "https://api.openai.com/v1")
                    )
                    .labelsHidden()
                    footnote("OpenAI, Groq (https://api.groq.com/openai/v1), or a local server such as "
                        + "Kokoro-FastAPI (http://localhost:8880/v1). Not LM Studio/Ollama — they have no "
                        + "TTS endpoint.")
                }
            }
            if draft.kind == .elevenLabs {
                row("Base URL") {
                    TextField(
                        "Base URL",
                        text: bind(\.baseURLString),
                        prompt: Text(verbatim: "https://api.elevenlabs.io (default)")
                    )
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
                    TextField(
                        "Voice",
                        text: bind(\.voice),
                        prompt: Text(verbatim: draft.kind == .elevenLabs ? "Voice ID" : "Voice name")
                    )
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
                    footnote(
                        "ElevenLabs streams 24 kHz PCM (low latency); WAV maps to PCM. MP3/Opus/other "
                            + "formats can't be played yet.",
                        warning: !draft.format.isStreamable
                    )
                } else if !draft.format.isStreamable {
                    footnote(
                        "\(draft.format.rawValue.uppercased()) isn't streamed yet — use WAV or PCM for "
                            + "low-latency playback.",
                        warning: true
                    )
                }
            }

            row("Speed") {
                let unsupported = draft.kind == .elevenLabs
                    && !ElevenLabsModelSupport.supportsSpeed(modelID: currentModelID)
                HStack {
                    Slider(value: $draft.speed, in: speedRange)
                    Text(verbatim: String(format: "%.2f×", draft.speed)).monospacedDigit().frame(width: 48)
                }
                .disabled(unsupported)
                if unsupported { footnote("\(currentModelName) doesn't use speed.") }
            }

            if draft.kind == .elevenLabs { voiceSettingsRows }
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

// MARK: - Voice settings (ElevenLabs)

extension ProvidersSettingsView {
    /// Stability, similarity, style and speaker boost for this profile; off = the voice's saved ones.
    @ViewBuilder
    private var voiceSettingsRows: some View {
        row("Voice Settings") {
            HStack {
                Toggle("Customize for this profile", isOn: customVoiceSettings)
                if draft.voiceSettings != nil {
                    Spacer()
                    Button("Reset") { startCustomVoiceSettings() }
                        .help("Back to this voice's saved settings (ElevenLabs' defaults if they can't be loaded)")
                }
            }
            footnote(draft.voiceSettings == nil
                ? "Uses the stability, similarity and style saved with this voice on ElevenLabs."
                : "Starts from the voice's saved settings. Save, then Test Voice to hear a change.")
        }
        if draft.voiceSettings != nil {
            settingSlider(
                "Stability", \.stability, low: "Creative", high: "Stable",
                help: "Lower: a broader emotional range that varies between takes. "
                    + "Higher: consistent, but can sound monotone."
            )
            settingSlider(
                "Similarity", \.similarity, low: "Low", high: "High",
                help: "How closely the output sticks to the original voice. "
                    + "Very high values can also copy flaws in its recording.",
                unsupported: !ElevenLabsModelSupport.supportsSimilarity(modelID: currentModelID)
            )
            settingSlider(
                "Style", \.style, low: "None", high: "Exaggerated",
                help: "Exaggerates the voice's style. Adds latency; 0 suits most text.",
                unsupported: currentModel?.supportsStyle == false
            )
            row("Speaker Boost") {
                let unsupported = currentModel?.supportsSpeakerBoost == false
                Toggle("Boost similarity to the original speaker", isOn: speakerBoost)
                    .disabled(unsupported)
                    .help("Closer to the original speaker, at a little extra latency.")
                if unsupported { footnote("\(currentModelName) doesn't use speaker boost.") }
            }
        }
    }

    /// A 0...1 voice setting: the slider and its value, with what each end means underneath.
    private func settingSlider(
        _ label: String,
        _ keyPath: WritableKeyPath<VoiceSettings, Double?>,
        low: String,
        high: String,
        help: String,
        unsupported: Bool = false
    ) -> some View {
        let value = voiceSetting(keyPath)
        return row(label) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Slider(value: value, in: VoiceSettings.range)
                    Text(verbatim: "\(Int((value.wrappedValue * 100).rounded()))%")
                        .monospacedDigit().frame(width: 48)
                }
                HStack {
                    Text(verbatim: low)
                    Spacer()
                    Text(verbatim: high)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 56) // under the slider, not the value
            }
            .disabled(unsupported)
            .help(help)
            if unsupported { footnote("\(currentModelName) doesn't use \(label.lowercased()).") }
        }
    }

    /// The profile's model from the fetched catalog, once loaded.
    private var currentModel: SpeechModel? {
        fetchedModels.first { $0.id == currentModelID }
    }

    /// The model's name for notes, or its id while the catalog isn't loaded.
    private var currentModelName: String {
        currentModel?.name ?? currentModelID
    }

    private var customVoiceSettings: Binding<Bool> {
        Binding(
            get: { draft.voiceSettings != nil },
            set: { $0 ? startCustomVoiceSettings() : (draft.voiceSettings = nil) }
        )
    }

    private func voiceSetting(_ keyPath: WritableKeyPath<VoiceSettings, Double?>) -> Binding<Double> {
        Binding(
            get: {
                draft.voiceSettings?[keyPath: keyPath]
                    ?? ElevenLabsVoiceSettings.apiDefaults.asVoiceSettings[keyPath: keyPath] ?? 0
            },
            set: { draft.voiceSettings?[keyPath: keyPath] = $0 }
        )
    }

    private var speakerBoost: Binding<Bool> {
        Binding(
            get: { draft.voiceSettings?.speakerBoost ?? true },
            set: { draft.voiceSettings?.speakerBoost = $0 }
        )
    }

    /// Shows ElevenLabs' defaults at once, then the voice's saved settings when they arrive — unless
    /// the user has moved a slider, or switched profile or voice, in the meantime.
    private func startCustomVoiceSettings() {
        let placeholder = ElevenLabsVoiceSettings.apiDefaults.asVoiceSettings
        draft.voiceSettings = placeholder
        let config = draft
        Task {
            guard let saved = await env.savedVoiceSettings(for: config),
                  draft.id == config.id, draft.voice == config.voice, draft.voiceSettings == placeholder
            else { return }
            draft.voiceSettings = saved
        }
    }
}

#Preview("Providers — ElevenLabs") {
    let profile = ProviderConfig(
        id: "preview-el", kind: .elevenLabs, name: "ElevenLabs", apiKeyKeychainRef: "apikey.preview-el",
        model: "eleven_v4", voice: "lib1", format: .pcm, capabilities: ProviderCapabilities(),
        voiceSettings: VoiceSettings(stability: 0.35, similarity: 0.8, style: 0, speakerBoost: true)
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
        SpeechModel(
            id: "eleven_v4",
            name: "Eleven v4",
            summary: "Our fastest and most emotive model.",
            maxInputCharacters: 10_000,
            costMultiplier: 1,
            supportsStyle: false,
            supportsSpeakerBoost: false
        ),
        SpeechModel(id: "eleven_v4_turbo", name: "Eleven v4 Turbo", maxInputCharacters: 10_000, costMultiplier: 0.5),
    ], for: profile.id)
    return ProvidersSettingsView()
        .environmentObject(env)
        .frame(width: 520, height: 500) // ≈ the Providers tab inside the 520×560 Settings window
}
