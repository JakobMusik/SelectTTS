import Foundation
import SpeechCore

/// Decodes ElevenLabs `GET {root}/v1/models` — a JSON array of `{ model_id, name, description,
/// can_do_text_to_speech, requires_alpha_access, maximum_text_length_per_request,
/// model_rates: { character_cost_multiplier } }` — into the text-to-speech models as
/// `[SpeechModel]`, in the API's order (newest first). Speech-to-speech-only models and models that
/// need alpha access are dropped; unknown/missing fields degrade gracefully.
public enum ElevenLabsModelList {

    public static func decode(_ data: Data) throws -> [SpeechModel] {
        try JSONDecoder().decode([LossyModel].self, from: data)
            .compactMap(\.model)
            .filter { $0.canDoTextToSpeech != false && $0.requiresAlphaAccess != true }
            .map { raw in
                SpeechModel(
                    id: raw.modelID,
                    name: raw.name?.isEmpty == false ? raw.name! : raw.modelID,
                    summary: raw.description?.isEmpty == false ? raw.description : nil,
                    maxInputCharacters: raw.maximumTextLengthPerRequest,
                    costMultiplier: raw.modelRates?.characterCostMultiplier
                )
            }
    }

    /// One array element; a malformed entry becomes nil instead of failing the whole list.
    private struct LossyModel: Decodable {
        let model: RawModel?
        init(from decoder: Decoder) throws {
            model = try? RawModel(from: decoder)
        }
    }

    private struct RawModel: Decodable {
        let modelID: String
        let name: String?
        let description: String?
        let canDoTextToSpeech: Bool?
        let requiresAlphaAccess: Bool?
        let maximumTextLengthPerRequest: Int?
        let modelRates: Rates?

        enum CodingKeys: String, CodingKey {
            case modelID = "model_id"
            case name
            case description
            case canDoTextToSpeech = "can_do_text_to_speech"
            case requiresAlphaAccess = "requires_alpha_access"
            case maximumTextLengthPerRequest = "maximum_text_length_per_request"
            case modelRates = "model_rates"
        }
    }

    private struct Rates: Decodable {
        let characterCostMultiplier: Double?

        enum CodingKeys: String, CodingKey {
            case characterCostMultiplier = "character_cost_multiplier"
        }
    }
}
