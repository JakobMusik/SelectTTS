import Foundation
import AppKit
import SelectionCapture
import SelectedTextKit

/// Production `SelectionCapturing` backed by SelectedTextKit's `.auto` chain (accessibility → menu
/// action, the README's "most reliable" mode), with AppleScript/⌘C fallbacks inside the library
/// (§5.2). MIT-licensed, so no copyleft (D8). Behind our protocol so the cores stay decoupled.
struct SelectedTextKitCapturer: SelectionCapturing {

    /// Strategy chain to try. `.auto` covers the common cases; the explicit list is available if we
    /// want to tune ordering later.
    let strategy: TextStrategy

    init(strategy: TextStrategy = .auto) {
        self.strategy = strategy
    }

    func captureSelection() async throws -> CaptureResult {
        let selected = try await SelectedTextManager.shared.getSelectedText(strategy: strategy)
        guard let text = selected,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CaptureError.noSelection
        }
        let app = NSWorkspace.shared.frontmostApplication
        return CaptureResult(
            text: text,
            strategy: .auto,
            app: CapturedApp(bundleID: app?.bundleIdentifier, name: app?.localizedName)
        )
    }
}
