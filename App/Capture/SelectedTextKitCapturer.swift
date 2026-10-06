import Foundation
import AppKit
import SelectionCapture
import SelectedTextKit

/// Production `SelectionCapturing` backed by SelectedTextKit (§5.2). MIT-licensed, so no copyleft
/// (D8). Behind our protocol so the cores stay decoupled.
///
/// Uses the library's per-strategy chain rather than `.auto`: `.auto` only falls back to menu Copy
/// when the Accessibility read returns *empty* text, but rethrows when it *fails* — and Electron
/// apps (the Claude app, VS Code, Slack, …) answer the selected-text attribute with
/// `AXError.noValue`, so `.auto` never reached the copy fallback there. `getSelectedText(strategies:)`
/// moves on to the next strategy after any non-permission error. Both copy strategies restore the
/// user's clipboard afterwards.
struct SelectedTextKitCapturer: SelectionCapturing {

    /// Tried in order: Accessibility read → Edit ▸ Copy via the menu bar → simulated ⌘C.
    let strategies: [TextStrategy]

    init(strategies: [TextStrategy] = [.accessibility, .menuAction, .shortcut]) {
        self.strategies = strategies
    }

    func captureSelection() async throws -> CaptureResult {
        let app = NSWorkspace.shared.frontmostApplication
        let source = app?.bundleIdentifier ?? "unknown"
        let selected: String?
        do {
            selected = try await SelectedTextManager.shared.getSelectedText(strategies: strategies)
        } catch {
            let reason = String(describing: error)
            Log.capture.error("capture in \(source, privacy: .public) threw: \(reason, privacy: .public)")
            throw error
        }
        guard let text = selected,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            Log.capture.info("no selection captured in \(source, privacy: .public)")
            throw CaptureError.noSelection
        }
        Log.capture.info("captured \(text.count, privacy: .public) chars from \(source, privacy: .public)")
        return CaptureResult(
            text: text,
            strategy: .auto,
            app: CapturedApp(bundleID: app?.bundleIdentifier, name: app?.localizedName)
        )
    }
}
