import Foundation

/// A synthesis model a provider offers (e.g. an ElevenLabs `model_id`). Like voices, model catalogs
/// churn, so they are runtime data fetched from the provider (decision D4), never hard-coded.
public struct SpeechModel: Identifiable, Hashable, Codable, Sendable {
    /// The string sent back to the provider (`SpeechRequest.model`).
    public let id: String
    public let name: String
    /// The provider's one-line description, when it gives one.
    public let summary: String?
    /// Longest text accepted per request, when the provider says.
    public let maxInputCharacters: Int?
    /// Relative price per character (1 = the provider's standard rate), when known.
    public let costMultiplier: Double?

    public init(
        id: String,
        name: String,
        summary: String? = nil,
        maxInputCharacters: Int? = nil,
        costMultiplier: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.maxInputCharacters = maxInputCharacters
        self.costMultiplier = costMultiplier
    }
}
