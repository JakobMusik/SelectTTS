import Foundation
import SelectionCapture
import SpeechCore
import TextRouting

/// The top-level action a trigger invokes: capture the current selection, wrap it as `TextInput`,
/// and route it to the enabled modules (TTS in v1). Pure orchestration over the core protocols, so
/// it is testable end-to-end with a stub capturer + fake modules; the app injects the real
/// SelectedTextKit-backed capturer and the TTS module.
public final class CaptureSpeakCoordinator: Sendable {
    private let capturer: SelectionCapturing
    private let router: TextRouter

    public init(capturer: SelectionCapturing, router: TextRouter) {
        self.capturer = capturer
        self.router = router
    }

    /// Capture and route. Throws `CaptureError` if nothing could be captured, or `RoutingRejection`
    /// if the captured text is filtered out / no module is enabled.
    @discardableResult
    public func captureAndRoute(trigger: Trigger) async throws -> RouteOutcome {
        let capture = try await capturer.captureSelection()
        let input = TextInput(
            text: capture.text,
            sourceApp: AppInfo(bundleID: capture.app?.bundleID, name: capture.app?.name),
            trigger: trigger
        )
        return try await router.route(input)
    }
}
