import Foundation
import SwiftUI
import AppCore
import AppSettings
import AudioPlayback
import SelectionCapture
import TextRouting

/// The app's composition root. Instantiates the cores from `SelectTTSKit` and wires them together;
/// SwiftUI views observe it. Remote-dep-backed pieces (SelectedTextKit capturer, Defaults store,
/// Keychain secrets, global hotkey) are swapped in over the next increments at the marked seams.
@MainActor
final class AppEnvironment: ObservableObject {
    let settingsStore: SettingsStore
    let secretStore: SecretStore
    let registry: ModuleRegistry
    let coordinator: CaptureSpeakCoordinator

    /// Held strongly so the audio engine survives between utterances.
    private let player: StreamingAudioPlayer

    @Published private(set) var status: String = "Ready"

    init() {
        // Inc 3 swaps these for Defaults-backed settings and a Keychain secret store.
        let settings = UserDefaultsSettingsStore()
        let secrets = InMemorySecretStore()
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

        // Inc 2 replaces this stub with a SelectedTextKit-backed capturer + a global hotkey trigger.
        let sampleCapturer = StubSelectionCapturer(
            text: "SelectTTS is ready. This sample is spoken by the offline system voice."
        )
        self.coordinator = CaptureSpeakCoordinator(
            capturer: sampleCapturer,
            router: TextRouter(registry: registry)
        )
    }

    var activeProviderName: String { settingsStore.activeConfig().name }

    /// Increment-1 smoke action: capture (stub) → route → speak via the active provider.
    func speakSample() {
        status = "Speaking…"
        Task {
            do {
                try await coordinator.captureAndRoute(trigger: .manual)
                status = "Ready"
            } catch {
                status = "Error: \(error)"
            }
        }
    }

    func stopSpeaking() {
        Task { await player.stop() }
        status = "Ready"
    }
}
