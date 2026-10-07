import Foundation
import SwiftUI
import AppKit
import AppCore
import AppSettings
import AudioPlayback
import Providers
import SelectionCapture
import SpeechCore
import TextRouting

/// The app's composition root. Instantiates the cores from `SelectTTSKit` and wires them together;
/// SwiftUI views observe it. Remote-dep-backed pieces are injected (the capturer) or called through
/// same-target shims (`SpeakSelectionShortcut`, `AccessibilityAuthorization`) so this file stays on
/// Apple-SDK + local-module imports only.
@MainActor
final class AppEnvironment: ObservableObject {
    let settingsStore: SettingsStore
    let secretStore: SecretStore
    let registry: ModuleRegistry
    let router: TextRouter
    let coordinator: CaptureSpeakCoordinator

    /// Held strongly so the audio engine survives between utterances.
    private let player: StreamingAudioPlayer

    /// One-line status shown in the menu and at the bottom of the Settings panes.
    @Published private(set) var status: String = "Ready" {
        didSet { statusIsError = false }
    }
    /// Whether `status` reports a failure (set via `fail(_:)`), so views can style it.
    @Published private(set) var statusIsError = false
    @Published private(set) var accessibilityTrusted: Bool = AccessibilityAuthorization.isTrusted

    /// True from the start of an utterance (capture → synthesis) until its audio has finished
    /// playing or it was stopped. Drives the ⌥T toggle and the menu's Stop item.
    @Published private(set) var isSpeaking = false
    /// The current utterance; `stopSpeaking()` cancels it.
    private var speakTask: Task<Void, Never>?
    /// Teardown of the last stopped utterance. The next utterance waits for it, so a late `stop()`
    /// from that teardown can't cut the new audio off.
    private var stopTask: Task<Void, Never>?

    /// Provider profiles + the active selection, mirrored for the UI. Mutations write through to the
    /// settings store; the TTS pipeline reads the store, so edits take effect immediately.
    @Published private(set) var providerConfigs: [ProviderConfig] = []
    @Published private(set) var activeProviderID: String = ProviderConfig.systemDefault.id

    /// Voices fetched from a provider's catalog endpoint (currently ElevenLabs `/v2/voices`), shown in
    /// the editor so the user can pick a voice id instead of typing it. Keyed to the profile they were
    /// fetched for so a stale list isn't shown against a different profile.
    @Published private(set) var fetchedVoices: [Voice] = []
    @Published private(set) var fetchedVoicesProviderID: String?
    /// The provider's model catalog (ElevenLabs `/v1/models`), loaded with the voices; empty when the
    /// provider has none or it couldn't be fetched (the editor then falls back to a text field).
    @Published private(set) var fetchedModels: [SpeechModel] = []
    @Published private(set) var fetchedModelsProviderID: String?

    /// Whether SelectTTS is registered to open at login (re-read, since System Settings can change it).
    @Published private(set) var launchAtLogin: LaunchAtLogin.State = LaunchAtLogin.state

    /// `settings`/`secrets` default to the real stores; previews inject in-memory ones so they never
    /// touch the user's defaults or Keychain.
    init(
        capturer: SelectionCapturing,
        settings: SettingsStore = UserDefaultsSettingsStore(),
        secrets: SecretStore = KeychainSecretStore()
    ) {
        self.settingsStore = settings
        self.secretStore = secrets

        let player = StreamingAudioPlayer()
        self.player = player

        // The TTS module always speaks through whatever profile is active (system voice by default).
        let ttsModule = TTSPipeline.makeModule(
            sink: player,
            secrets: secrets,
            activeConfig: { settings.activeConfig() }
        )

        let registry = ModuleRegistry([ttsModule])
        self.registry = registry
        let router = TextRouter(registry: registry)
        self.router = router
        self.coordinator = CaptureSpeakCoordinator(capturer: capturer, router: router)

        // Load persisted profiles; guarantee the permanent offline system profile is present.
        var configs = settings.loadProviderConfigs()
        if !configs.contains(where: { $0.id == ProviderConfig.systemDefault.id }) {
            configs.insert(.systemDefault, at: 0)
        }
        self.providerConfigs = configs
        self.activeProviderID = settings.loadActiveProviderID() ?? configs.first?.id ?? ProviderConfig.systemDefault.id

        registerHotkey()
    }

    var activeProviderName: String {
        providerConfigs.first(where: { $0.id == activeProviderID })?.name
            ?? ProviderConfig.systemDefault.name
    }

    // MARK: - Actions

    /// The speak shortcut: speak the selection, or — if something is already speaking — stop it,
    /// like macOS's own Speak Selection (press the key again to stop).
    func toggleSpeakSelection() {
        if isSpeaking { stopSpeaking() } else { speakSelection() }
    }

    /// Capture the current selection and speak it.
    func speakSelection() {
        Log.speak.info("speakSelection (accessibility trusted: \(self.accessibilityTrusted, privacy: .public))")
        guard accessibilityTrusted else {
            status = "Grant Accessibility to read selected text"
            AccessibilityAuthorization.prompt()
            return
        }
        let coordinator = coordinator
        beginSpeaking { [weak self] in
            self?.report(try await coordinator.captureAndRoute(trigger: .hotkey))
        }
    }

    /// Speak the current clipboard text. Unlike selection capture this works from the menu, since
    /// opening the menu makes SelectTTS frontmost (so there is no live selection to read) but the
    /// pasteboard persists.
    func speakClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Clipboard is empty"
            return
        }
        let router = router
        beginSpeaking { [weak self] in
            self?.report(try await router.route(TextInput(text: text, trigger: .menuBar)))
        }
    }

    /// Speak a fixed sample through the active provider (no selection needed) — handy for testing a
    /// voice without selecting text. Used by the Settings "Speak a sample" button.
    func speakSample() {
        let router = router
        beginSpeaking { [weak self] in
            self?.report(try await router.route(TextInput(
                text: "SelectTTS is ready. This sample is spoken by the active voice.",
                trigger: .manual
            )))
        }
    }

    /// Stop whatever is speaking — the menu's Stop, the optional stop shortcut, or the speak shortcut
    /// pressed while speaking. Cancels synthesis too, so no later audio restarts playback.
    func stopSpeaking() {
        let wasSpeaking = speakTask != nil
        haltCurrentSpeech()
        if !wasSpeaking { Task { [player] in await player.stop() } }
        Log.speak.info("stop (was speaking: \(wasSpeaking, privacy: .public))")
        status = wasSpeaking ? "Stopped" : "Ready"
    }

    /// Runs one utterance as the tracked `speakTask`, replacing whatever is playing. `work` returns
    /// once its audio has played (the sink's `finish()` waits for playback). Errors are shown via
    /// `failure` (default: `describe`); a stop (cancellation) is silent.
    private func beginSpeaking(
        failure: (@MainActor (Error) -> String)? = nil,
        _ work: @escaping @MainActor () async throws -> Void
    ) {
        haltCurrentSpeech()
        let pendingStop = stopTask
        let player = player
        isSpeaking = true
        status = "Speaking…"
        speakTask = Task { [weak self] in
            await pendingStop?.value
            await player.stop() // a fresh engine and format for every utterance
            do {
                try Task.checkCancellation()
                try await work()
            } catch {
                if Task.isCancelled || error is CancellationError { return } // stopped by the user
                Log.speak.error("utterance failed: \(String(describing: error), privacy: .public)")
                if let self { self.fail(failure?(error) ?? self.describe(error)) }
            }
            guard !Task.isCancelled else { return }
            await player.stop() // release the audio device while idle
            self?.isSpeaking = false
            self?.speakTask = nil
        }
    }

    /// Cancels the current utterance and silences it now, then stops the player once more after the
    /// cancelled pipeline has unwound, dropping anything it enqueued in between.
    private func haltCurrentSpeech() {
        guard let task = speakTask else { return }
        speakTask = nil
        isSpeaking = false
        task.cancel()
        let player = player
        let previousStop = stopTask
        stopTask = Task {
            await previousStop?.value
            await player.stop()
            await task.value
            await player.stop()
        }
    }

    // MARK: - Provider profiles

    /// A new profile pre-filled with sensible defaults for its kind.
    func makeNewProvider(kind: ProviderKind) -> ProviderConfig {
        let id = UUID().uuidString
        switch kind {
        case .system:
            return ProviderConfig(id: id, kind: .system, name: "System Voice")
        case .openAICompatible:
            return ProviderConfig(
                id: id, kind: .openAICompatible, name: "OpenAI",
                baseURLString: "https://api.openai.com/v1", apiKeyKeychainRef: "apikey.\(id)",
                model: "gpt-4o-mini-tts", voice: "marin", format: .wav, speed: 1.0,
                capabilities: .openAI
            )
        case .elevenLabs:
            return ProviderConfig(
                id: id, kind: .elevenLabs, name: "ElevenLabs",
                apiKeyKeychainRef: "apikey.\(id)", model: ElevenLabsRequestBuilder.defaultModelID,
                voice: ElevenLabsRequestBuilder.defaultVoiceID, format: .pcm, speed: 1.0,
                capabilities: ProviderCapabilities()
            )
        }
    }

    func upsertProvider(_ config: ProviderConfig) {
        if let index = providerConfigs.firstIndex(where: { $0.id == config.id }) {
            providerConfigs[index] = config
        } else {
            providerConfigs.append(config)
        }
        persistConfigs()
    }

    func deleteProvider(_ id: String) {
        guard id != ProviderConfig.systemDefault.id else { return } // permanent
        providerConfigs.removeAll { $0.id == id }
        if activeProviderID == id {
            setActiveProvider(providerConfigs.first?.id ?? ProviderConfig.systemDefault.id)
        }
        persistConfigs()
    }

    func setActiveProvider(_ id: String) {
        activeProviderID = id
        settingsStore.saveActiveProviderID(id)
    }

    // MARK: - Secrets

    func hasStoredKey(for config: ProviderConfig) -> Bool {
        storedKeySuffix(for: config) != nil
    }

    /// The last four characters of the stored key (to tell keys apart without revealing them), or
    /// nil when no key is stored for this profile.
    func storedKeySuffix(for config: ProviderConfig) -> String? {
        guard let ref = config.apiKeyKeychainRef,
              let stored = (try? secretStore.secret(for: ref)) ?? nil,
              !stored.isEmpty else { return nil }
        return String(stored.suffix(4))
    }

    func storeKey(_ key: String, for config: ProviderConfig) {
        guard let ref = config.apiKeyKeychainRef else { return }
        do {
            try secretStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: ref)
        } catch {
            fail("Couldn't save the API key to the Keychain: \(error)")
        }
    }

    // MARK: - Test a profile

    /// Speak a short sample through a specific profile (not necessarily the active one), so the user
    /// can verify an endpoint/key before switching to it.
    func testProvider(_ config: ProviderConfig) {
        let secrets = secretStore
        let player = player
        beginSpeaking(failure: { "Test failed: \($0)" }) { [weak self] in
            self?.status = "Testing \(config.name)…"
            let provider = try ProviderFactory.makeProvider(from: config, secrets: secrets)
            let request = ProviderFactory.makeRequest(
                text: "This is a test of \(config.name).", config: config
            )
            for try await chunk in provider.synthesize(request) {
                try Task.checkCancellation()
                try await player.enqueue(chunk)
            }
            try Task.checkCancellation()
            await player.finish() // returns once the sample has played
            self?.status = "Test OK — \(config.name)"
        }
    }

    // MARK: - Voice catalog

    /// Load the provider's voice and model catalogs (ElevenLabs `/v2/voices` + `/v1/models`) so the
    /// editor can offer pickers. Voice failures (no key, bad key, missing permission) land in `status`
    /// with the server's message; a model failure just leaves the model as a text field. The fields
    /// stay editable either way.
    func refreshCatalog(for config: ProviderConfig) {
        status = "Loading voices and models for \(config.name)…"
        let secrets = secretStore
        Task {
            let provider: SpeechProvider
            do {
                provider = try ProviderFactory.makeProvider(from: config, secrets: secrets)
            } catch {
                fail("Couldn't load \(config.name): \(error)")
                return
            }
            async let voices = Self.fetch { try await provider.availableVoices() }
            async let models = Self.fetch { try await provider.availableModels() }

            var modelNote = ""
            switch await models {
            case .success(let list):
                showFetchedModels(list, for: config.id)
                if !list.isEmpty { modelNote = " and \(list.count) models" }
            case .failure(let error):
                showFetchedModels([], for: config.id)
                Log.speak.error("model catalog failed: \(String(describing: error), privacy: .public)")
                modelNote = " (models unavailable: \(error))"
            }

            switch await voices {
            case .success(let list):
                showFetchedVoices(list, for: config.id)
                let caveats = list.filter { $0.note != nil }.count
                status = list.isEmpty ? "No voices returned" + modelNote
                    : "Loaded \(list.count) voices" + modelNote
                        + (caveats > 0 ? " — \(caveats) voices marked ⚠︎ may not work on your plan" : "")
            case .failure(let error):
                showFetchedVoices([], for: config.id)
                fail("Couldn't fetch voices: \(error)")
            }
        }
    }

    nonisolated private static func fetch<T: Sendable>(
        _ body: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do { return .success(try await body()) } catch { return .failure(error) }
    }

    /// Publishes a fetched voice catalog for one profile's editor.
    func showFetchedVoices(_ voices: [Voice], for providerID: String) {
        fetchedVoices = voices
        fetchedVoicesProviderID = providerID
    }

    /// Publishes a fetched model catalog for one profile's editor.
    func showFetchedModels(_ models: [SpeechModel], for providerID: String) {
        fetchedModels = models
        fetchedModelsProviderID = providerID
    }

    // MARK: - Open at login

    func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.state
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            status = enabled ? "SelectTTS will open at login" : "SelectTTS won't open at login"
        } catch {
            fail("Couldn't change Open at Login: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
    }

    // MARK: - Permissions

    func refreshPermissions() {
        accessibilityTrusted = AccessibilityAuthorization.isTrusted
    }

    func requestAccessibilityPermission() {
        // Bring the app forward so the system permission dialog appears in front (accessory apps are
        // not active by default).
        NSApp.activate(ignoringOtherApps: true)
        AccessibilityAuthorization.prompt()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        AccessibilityAuthorization.openSettings()
    }

    // MARK: - Private

    private func fail(_ message: String) {
        status = message
        statusIsError = true
    }

    private func persistConfigs() {
        settingsStore.saveProviderConfigs(providerConfigs)
    }

    private func registerHotkey() {
        SpeakSelectionShortcut.register(
            onSpeak: { [weak self] in Task { @MainActor in self?.toggleSpeakSelection() } },
            onStop: { [weak self] in Task { @MainActor in self?.stopSpeaking() } }
        )
    }

    /// The router keeps going when a module fails and returns the failures instead of throwing, so
    /// they must be surfaced here — otherwise a provider error (bad key, 402, network) is silent.
    private func report(_ outcome: RouteOutcome) {
        if let failure = outcome.failures.first {
            Log.speak.error("module \(failure.moduleID, privacy: .public) failed: \(failure.message, privacy: .public)")
            fail("Couldn't speak via \(activeProviderName): \(failure.message)")
        } else {
            let provider = activeProviderName
            Log.speak.info("spoken by \(outcome.handledBy, privacy: .public) via \(provider, privacy: .public)")
            status = "Ready"
        }
    }

    private func describe(_ error: Error) -> String {
        switch error {
        case CaptureError.noSelection: return "No text selected"
        case CaptureError.notTrusted: return "Grant Accessibility to read selected text"
        case RoutingRejection.empty: return "No text selected"
        default: return "Error: \(error)"
        }
    }
}
