import Foundation
import SwiftUI
import AppKit
import AppCore
import AppSettings
import AudioPlayback
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

    @Published private(set) var status: String = "Ready"
    @Published private(set) var accessibilityTrusted: Bool = AccessibilityAuthorization.isTrusted

    /// Provider profiles + the active selection, mirrored for the UI. Mutations write through to the
    /// settings store; the TTS pipeline reads the store, so edits take effect immediately.
    @Published private(set) var providerConfigs: [ProviderConfig] = []
    @Published private(set) var activeProviderID: String = ProviderConfig.systemDefault.id

    /// Voices fetched from a provider's catalog endpoint (currently ElevenLabs `/v1/voices`), shown in
    /// the editor so the user can pick a voice id instead of typing it. Keyed to the profile they were
    /// fetched for so a stale list isn't shown against a different profile.
    @Published private(set) var fetchedVoices: [Voice] = []
    @Published private(set) var fetchedVoicesProviderID: String?

    init(capturer: SelectionCapturing) {
        let settings = UserDefaultsSettingsStore()
        let secrets = KeychainSecretStore()
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

    /// Capture the current selection and speak it. The global hotkey and the menu both call this.
    func speakSelection() {
        guard accessibilityTrusted else {
            status = "Grant Accessibility to read selected text"
            AccessibilityAuthorization.prompt()
            return
        }
        status = "Capturing…"
        Task {
            do {
                try await coordinator.captureAndRoute(trigger: .hotkey)
                status = "Speaking…"
            } catch {
                status = describe(error)
            }
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
        status = "Speaking…"
        Task {
            do {
                try await router.route(TextInput(text: text, trigger: .menuBar))
                status = "Ready"
            } catch {
                status = describe(error)
            }
        }
    }

    /// Speak a fixed sample through the active provider (no selection needed) — handy for testing a
    /// voice without selecting text. Used by the Settings "Speak a sample" button.
    func speakSample() {
        status = "Speaking…"
        Task {
            do {
                try await router.route(TextInput(
                    text: "SelectTTS is ready. This sample is spoken by the active voice.",
                    trigger: .manual
                ))
                status = "Ready"
            } catch {
                status = describe(error)
            }
        }
    }

    func stopSpeaking() {
        Task { await player.stop() }
        status = "Ready"
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
                apiKeyKeychainRef: "apikey.\(id)", model: "eleven_multilingual_v2",
                voice: "", format: .pcm, speed: 1.0, capabilities: ProviderCapabilities()
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
        guard let ref = config.apiKeyKeychainRef else { return false }
        let stored = (try? secretStore.secret(for: ref)) ?? nil
        return !(stored ?? "").isEmpty
    }

    func storeKey(_ key: String, for config: ProviderConfig) {
        guard let ref = config.apiKeyKeychainRef else { return }
        try? secretStore.set(key, for: ref)
    }

    // MARK: - Test a profile

    /// Speak a short sample through a specific profile (not necessarily the active one), so the user
    /// can verify an endpoint/key before switching to it.
    func testProvider(_ config: ProviderConfig) {
        status = "Testing \(config.name)…"
        let secrets = secretStore
        let player = player
        Task {
            do {
                let provider = try ProviderFactory.makeProvider(from: config, secrets: secrets)
                let request = ProviderFactory.makeRequest(
                    text: "This is a test of \(config.name).", config: config
                )
                for try await chunk in provider.synthesize(request) {
                    try await player.enqueue(chunk)
                }
                await player.finish()
                status = "Ready"
            } catch {
                status = "Test failed: \(error)"
            }
        }
    }

    // MARK: - Voice catalog

    /// Fetch the provider's voice catalog (ElevenLabs `/v1/voices`) so the editor can offer a picker.
    /// Best-effort: adapters fall back to their preset voices on failure, so this never throws to the UI.
    func refreshVoices(for config: ProviderConfig) {
        status = "Fetching voices for \(config.name)…"
        let secrets = secretStore
        Task {
            do {
                let provider = try ProviderFactory.makeProvider(from: config, secrets: secrets)
                let voices = try await provider.availableVoices()
                fetchedVoices = voices
                fetchedVoicesProviderID = config.id
                status = voices.isEmpty ? "No voices returned" : "Loaded \(voices.count) voices"
            } catch {
                fetchedVoices = []
                fetchedVoicesProviderID = config.id
                status = "Couldn't fetch voices: \(error)"
            }
        }
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

    private func persistConfigs() {
        settingsStore.saveProviderConfigs(providerConfigs)
    }

    private func registerHotkey() {
        SpeakSelectionShortcut.register { [weak self] in
            Task { @MainActor in self?.speakSelection() }
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
