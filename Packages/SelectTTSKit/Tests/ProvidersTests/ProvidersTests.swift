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

    func testOutputFormatIsAppendedAsQuery() throws {
        let req = try builder.makeRequest(
            apiKey: "xi-key", voiceID: "voice123", text: "hi", outputFormat: "pcm_24000"
        )
        let components = URLComponents(url: try XCTUnwrap(req.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "output_format" })?.value, "pcm_24000")
    }

    func testVoiceListRequestShape() throws {
        let req = try builder.makeVoiceListRequest(apiKey: "xi-key")
        XCTAssertEqual(req.url?.absoluteString, "https://api.elevenlabs.io/v1/voices")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "xi-key")
    }

    func testVoiceListRequestThrowsWithoutKey() {
        XCTAssertThrowsError(try builder.makeVoiceListRequest(apiKey: "")) { error in
            XCTAssertEqual(error as? SpeechProviderError, .missingAPIKey)
        }
    }
}

final class ElevenLabsOutputFormatTests: XCTestCase {
    func testStreamableFormatsRequestHeaderlessPCM() {
        for format in [AudioFormat.pcm, .wav] {
            let resolved = ElevenLabsOutputFormat.resolve(format)
            XCTAssertEqual(resolved.token, "pcm_24000")
            XCTAssertEqual(resolved.pcm, .openAIpcm) // 24 kHz / 16-bit / signed LE / mono
        }
    }

    func testCompressedFormatsCarryNoPCMLayout() {
        XCTAssertEqual(ElevenLabsOutputFormat.resolve(.mp3).token, "mp3_44100_128")
        XCTAssertNil(ElevenLabsOutputFormat.resolve(.mp3).pcm)
        XCTAssertEqual(ElevenLabsOutputFormat.resolve(.opus).token, "opus_48000_128")
        XCTAssertNil(ElevenLabsOutputFormat.resolve(.opus).pcm)
        for format in [AudioFormat.aac, .flac, .m4a] {
            XCTAssertEqual(ElevenLabsOutputFormat.resolve(format).token, "mp3_44100_128")
            XCTAssertNil(ElevenLabsOutputFormat.resolve(format).pcm)
        }
    }
}

final class ElevenLabsVoiceListTests: XCTestCase {
    func testDecodesVoiceIDNameAndLabels() throws {
        let json = """
        { "voices": [
            { "voice_id": "abc123", "name": "Rachel", "labels": { "gender": "female", "language": "en" } },
            { "voice_id": "def456", "name": "Josh", "labels": { "gender": "male" } }
        ] }
        """.data(using: .utf8)!

        let voices = try ElevenLabsVoiceList.decode(json)
        XCTAssertEqual(voices.count, 2)
        XCTAssertEqual(voices[0].id, "abc123")
        XCTAssertEqual(voices[0].name, "Rachel")
        XCTAssertEqual(voices[0].language, "en")
        XCTAssertEqual(voices[0].gender, .female)
        XCTAssertEqual(voices[1].id, "def456")
        XCTAssertEqual(voices[1].gender, .male)
        XCTAssertNil(voices[1].language)
    }

    func testFallsBackToVoiceIDWhenNameMissing() throws {
        let json = #"{ "voices": [ { "voice_id": "xyz" } ] }"#.data(using: .utf8)!
        let voices = try ElevenLabsVoiceList.decode(json)
        XCTAssertEqual(voices.count, 1)
        XCTAssertEqual(voices[0].name, "xyz")
        XCTAssertNil(voices[0].gender)
    }

    func testThrowsOnMalformedJSON() {
        let json = #"{ "not_voices": [] }"#.data(using: .utf8)!
        XCTAssertThrowsError(try ElevenLabsVoiceList.decode(json))
    }
}
