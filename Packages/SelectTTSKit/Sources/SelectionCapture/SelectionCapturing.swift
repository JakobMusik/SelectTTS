import Foundation

/// The strategy that produced (or would produce) a selection. Mirrors SelectedTextKit's enum so the
/// app can swap in a SelectedTextKit-backed implementation behind this protocol (§5.2).
public enum CaptureStrategy: String, Sendable, Equatable, Codable {
    /// The chained default (accessibility → menu action) — SelectedTextKit's recommended mode.
    case auto
    case accessibility
    case appleScript
    case menuAction
    case shortcut
}

/// Lightweight description of the app a selection came from. Kept local to this module so
/// SelectionCapture has no dependency on TextRouting; the app maps this to `AppInfo`.
public struct CapturedApp: Sendable, Equatable, Hashable {
    public let bundleID: String?
    public let name: String?
    public init(bundleID: String? = nil, name: String? = nil) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// A successful capture.
public struct CaptureResult: Sendable, Equatable {
    public let text: String
    public let strategy: CaptureStrategy
    public let app: CapturedApp?
    public init(text: String, strategy: CaptureStrategy, app: CapturedApp? = nil) {
        self.text = text
        self.strategy = strategy
        self.app = app
    }
}

public enum CaptureError: Error, Equatable, Sendable {
    /// Accessibility permission (kTCCServiceAccessibility) not granted.
    case notTrusted
    case noFocusedElement
    case noSelection
    case timedOut
    case unsupportedPlatform
    case strategyFailed(CaptureStrategy)
}

/// Abstracts "get the current selection." The native `AccessibilityCapturer` implements the
/// non-destructive first link; the app injects a full-chain implementation (SelectedTextKit:
/// accessibility → AppleScript → menu AXPress → ⌘C with pasteboard restore) behind this protocol.
public protocol SelectionCapturing: Sendable {
    func captureSelection() async throws -> CaptureResult
}
