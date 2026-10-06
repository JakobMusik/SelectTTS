import Foundation

/// Pulls the human-readable message out of an ElevenLabs error response body, so a failure reads
/// "HTTP 401: Invalid API key" rather than a bare status code.
///
/// ElevenLabs answers errors with a `detail` field in one of three shapes (observed live):
/// - `{"detail": {"status": "voice_not_found", "message": "A voice with voice_id … was not found."}}`
/// - `{"detail": [{"loc": ["body", "text"], "msg": "Field required", "type": "missing"}]}` (422)
/// - `{"detail": "Not Found"}`
/// Anything else falls back to the body text, truncated.
public enum ElevenLabsErrorMessage {

    static let maxFallbackLength = 300

    public static func extract(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = message(fromDetail: object["detail"]) {
            return message
        }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count > maxFallbackLength ? String(text.prefix(maxFallbackLength)) + "…" : text
    }

    private static func message(fromDetail detail: Any?) -> String? {
        switch detail {
        case let text as String:
            return text.isEmpty ? nil : text
        case let object as [String: Any]:
            return (object["message"] as? String) ?? (object["status"] as? String)
        case let list as [[String: Any]]:
            let messages = list.compactMap { item -> String? in
                guard let msg = item["msg"] as? String else { return nil }
                let location = (item["loc"] as? [Any])?.map { "\($0)" }.joined(separator: ".")
                return location.map { "\($0): \(msg)" } ?? msg
            }
            return messages.isEmpty ? nil : messages.joined(separator: "; ")
        default:
            return nil
        }
    }
}
