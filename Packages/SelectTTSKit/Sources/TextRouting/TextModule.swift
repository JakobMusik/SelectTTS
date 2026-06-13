import Foundation

public typealias ModuleID = String

/// Anything that consumes selected text. TTS is the first; translate/summarize/custom-LLM-prompt
/// come later by conforming to this one protocol and registering in `ModuleRegistry`.
public protocol TextModule: AnyObject, Sendable {
    var id: ModuleID { get }
    var displayName: String { get }
    /// User toggle, persisted by the app.
    var isEnabled: Bool { get }
    /// Cheap pre-check: e.g. skip empty/whitespace input, or input the module can't use.
    func canHandle(_ input: TextInput) -> Bool
    /// Do the work. The module owns its own UI/side effects (speaking, showing a window, …).
    func perform(_ input: TextInput) async throws
}
