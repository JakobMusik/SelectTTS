import Foundation

/// Voice settings some ElevenLabs models ignore although `GET /v1/models` doesn't say so (it reports
/// only `can_use_style` / `can_use_speaker_boost`). The API still accepts these fields and drops them,
/// so the editor greys them out for these models.
public enum ElevenLabsModelSupport {
    /// Speed is not available on Eleven v3 or v4 (product guide). Measured 2026-10-18: v4 clips are the
    /// same length at speed 0.7 and 1.2.
    static let modelsWithoutSpeed: Set<String> = ["eleven_v3", "eleven_v4", "eleven_v4_turbo"]
    /// Similarity is not available on Eleven v3 (product guide). v4 uses it (guide and playground), even
    /// though `/v1/history` records only stability for v4 requests.
    static let modelsWithoutSimilarity: Set<String> = ["eleven_v3"]

    public static func supportsSpeed(modelID: String) -> Bool {
        !modelsWithoutSpeed.contains(normalized(modelID))
    }

    public static func supportsSimilarity(modelID: String) -> Bool {
        !modelsWithoutSimilarity.contains(normalized(modelID))
    }

    private static func normalized(_ modelID: String) -> String {
        modelID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
