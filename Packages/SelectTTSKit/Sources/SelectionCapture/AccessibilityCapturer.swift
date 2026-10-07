import Foundation
#if canImport(ApplicationServices)
import ApplicationServices
#endif
#if canImport(AppKit)
import AppKit
#endif

/// The non-destructive first link of the capture chain: read the focused element's selected
/// text via the system-wide Accessibility element. Instant, no clipboard side effects. Returns
/// `noSelection` on the apps where AX selection is null (Safari/WebKit, Chrome without renderer a11y,
/// Firefox, terminals, …) — the app then falls through to the SelectedTextKit chain.
public struct AccessibilityCapturer: SelectionCapturing {
    public init() {}

    /// Whether Accessibility permission is currently granted for this process.
    public static var isTrusted: Bool {
        #if canImport(ApplicationServices)
        return AXIsProcessTrusted()
        #else
        return false
        #endif
    }

    public func captureSelection() async throws -> CaptureResult {
        #if canImport(ApplicationServices)
        guard AXIsProcessTrusted() else { throw CaptureError.notTrusted }

        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        )
        guard focusErr == .success, let focused = focusedRef else {
            throw CaptureError.noFocusedElement
        }
        // Safe: a non-nil AX attribute value of this attribute is an AXUIElement.
        let element = focused as! AXUIElement // swiftlint:disable:this force_cast

        var selectedRef: CFTypeRef?
        let selErr = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &selectedRef
        )
        guard selErr == .success,
              let text = selectedRef as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CaptureError.noSelection
        }

        return CaptureResult(text: text, strategy: .accessibility, app: Self.frontmostApp())
        #else
        throw CaptureError.unsupportedPlatform
        #endif
    }

    static func frontmostApp() -> CapturedApp? {
        #if canImport(AppKit)
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return CapturedApp(bundleID: app.bundleIdentifier, name: app.localizedName)
        #else
        return nil
        #endif
    }
}
