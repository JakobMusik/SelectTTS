import Foundation
import SwiftUI
import AppKit
import AppCore
import AppSettings
import AudioPlayback
import SelectionCapture
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

    init(capturer: SelectionCapturing) {
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
        let router = TextRouter(registry: registry)
        self.router = router
        self.coordinator = CaptureSpeakCoordinator(capturer: capturer, router: router)

        registerHotkey()
    }

    var activeProviderName: String { settingsStore.activeConfig().name }

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

    // MARK: - Permissions

    func refreshPermissions() {
        accessibilityTrusted = AccessibilityAuthorization.isTrusted
    }

    func requestAccessibilityPermission() {
        AccessibilityAuthorization.prompt()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        AccessibilityAuthorization.openSettings()
    }

    // MARK: - Private

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
