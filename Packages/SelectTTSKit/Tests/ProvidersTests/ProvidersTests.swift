import XCTest
@testable import Providers
import SpeechCore

final class OpenAISpeechRequestBuilderTests: XCTestCase {
    private let builder = OpenAISpeechRequestBuilder()
    private let base = URL(string: "https://api.openai.com/v1")!

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
    }

    func testBuildsEndpointHeadersAndBody() throws {
        let req = try builder.makeRequest(
            baseURL: base, apiKey: "sk-abc",
            request: SpeechRequest(text: "hello", voice: "alloy", model: "tts-1", format: .wav, speed: 1.0),
            capabilities: .openAITTS1
        )
        XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/audio/speech")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-abc")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let json = try body(req)
        XCTAssertEqual(json["model"] as? String, "tts-1")
        XCTAssertEqual(json["input"] as? String, "hello")
        XCTAssertEqual(json["voice"] as? String, "alloy")
        XCTAssertEqual(json["response_format"] as? String, "wav")
        XCTAssertEqual(json["speed"] as? Double, 1.0) // openAITTS1 honors speed
    }

    func testOmitsSpeedWhenNotHonored() throws {
        let req = try builder.makeRequest(
            baseURL: base, apiKey: "sk-abc",
            request: SpeechRequest(text: "hi", voice: "marin", model: "gpt-4o-mini-tts", speed: 2.0),
            capabilities: .openAI // speedHonored == false
        )
        let json = try body(req)
        XCTAssertNil(json["speed"])
    }

    func testEmptyKeyGetsPlaceholderForLocalServers() throws {
        let req = try builder.makeRequest(
            baseURL: URL(string: "http://localhost:8880/v1")!, apiKey: "",
            request: SpeechRequest(text: "hi", voice: "af_bella", model: "kokoro"),
            capabilities: .kokoro
        )
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-no-key-required")
    }

    func testThrowsWhenInputExceedsCapability() {
        let longText = String(repeating: "a", count: 5000)
        XCTAssertThrowsError(
            try builder.makeRequest(
                baseURL: base, apiKey: "sk",
                request: SpeechRequest(text: longText, voice: "alloy"),
                capabilities: .openAI // maxInputCharacters == 4096
            )
        ) { error in
            XCTAssertEqual(error as? SpeechProviderError, .inputTooLong(limit: 4096))
        }
    }
}

final class ElevenLabsRequestBuilderTests: XCTestCase {
    private let builder = ElevenLabsRequestBuilder()

    func testVoiceInPathAndKeyHeader() throws {
        let req = try builder.makeRequest(apiKey: "xi-key", voiceID: "voice123", text: "hi", modelID: nil)
        XCTAssertEqual(req.url?.absoluteString, "https://api.elevenlabs.io/v1/text-to-speech/voice123")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "xi-key")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization")) // not Bearer

        let json = try JSONSerialization.jsonObject(with: XCTUnwrap(req.httpBody)) as! [String: Any]
        XCTAssertEqual(json["text"] as? String, "hi")
        XCTAssertEqual(json["model_id"] as? String, "eleven_multilingual_v2")
    }

    func testThrowsWithoutKey() {
        XCTAssertThrowsError(try builder.makeRequest(apiKey: "", voiceID: "v", text: "hi")) { error in
            XCTAssertEqual(error as? SpeechProviderError, .missingAPIKey)
        }
    }
}
