import Foundation

/// A deterministic capturer for tests, previews, and the app's "speak this sample" first-run check.
public struct StubSelectionCapturer: SelectionCapturing {
    public let result: Result<CaptureResult, CaptureError>

    public init(result: Result<CaptureResult, CaptureError>) {
        self.result = result
    }

    public init(text: String, strategy: CaptureStrategy = .accessibility, app: CapturedApp? = nil) {
        self.result = .success(CaptureResult(text: text, strategy: strategy, app: app))
    }

    public func captureSelection() async throws -> CaptureResult {
        try result.get()
    }
}
