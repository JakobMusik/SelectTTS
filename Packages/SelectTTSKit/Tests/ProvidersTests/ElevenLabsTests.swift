import XCTest
@testable import Providers
import SpeechCore

final class ElevenLabsRequestBuilderTests: XCTestCase {
    private let builder = ElevenLabsRequestBuilder()

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
    }

    func testStreamEndpointVoiceInPathAndKeyHeader() throws {
        let req = try builder.makeRequest(apiKey: "xi-key", voiceID: "voice123", text: "hi", modelID: nil)
        XCTAssertEqual(req.url?.absoluteString, "https://api.elevenlabs.io/v1/text-to-speech/voice123/stream")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "xi-key")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization")) // not Bearer

        let json = try body(req)
        XCTAssertEqual(json["text"] as? String, "hi")
        XCTAssertEqual(json["model_id"] as? String, "eleven_multilingual_v2")
        XCTAssertNil(json["voice_settings"]) // speed 1.0 → stored voice settings untouched
    }

    func testLegacyV1BaseURLAndResidencyHostsNormalize() throws {
        let cases: [(String, String)] = [
            ("https://api.elevenlabs.io/v1", "https://api.elevenlabs.io/v1/text-to-speech/v/stream"),
            ("https://api.elevenlabs.io/v1/", "https://api.elevenlabs.io/v1/text-to-speech/v/stream"),
            ("https://api.us.elevenlabs.io", "https://api.us.elevenlabs.io/v1/text-to-speech/v/stream"),
            ("https://api.eu.residency.elevenlabs.io/",
             "https://api.eu.residency.elevenlabs.io/v1/text-to-speech/v/stream"),
        ]
        for (base, expected) in cases {
            let req = try builder.makeRequest(
                baseURL: URL(string: base)!, apiKey: "k", voiceID: "v", text: "hi"
            )
            XCTAssertEqual(req.url?.absoluteString, expected, "base \(base)")
        }
    }

    func testSpeedIsSentAsVoiceSettingsAndClampedToAPIRange() throws {
        func speed(_ value: Double) throws -> Double? {
            let req = try builder.makeRequest(apiKey: "k", voiceID: "v", text: "hi", speed: value)
            return (try body(req)["voice_settings"] as? [String: Any])?["speed"] as? Double
        }
        XCTAssertEqual(try XCTUnwrap(speed(1.1)), 1.1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(speed(2.0)), 1.2, accuracy: 1e-9)  // API rejects > 1.2
        XCTAssertEqual(try XCTUnwrap(speed(0.25)), 0.7, accuracy: 1e-9) // API rejects < 0.7
        XCTAssertNil(try speed(1.0))
    }

    func testSpeedOverrideKeepsStoredVoiceSettings() throws {
        let stored = ElevenLabsVoiceSettings(
            stability: 0.2, similarityBoost: 0.9, style: 0.6, useSpeakerBoost: false, speed: 1.16
        )
        let req = try builder.makeRequest(
            apiKey: "k", voiceID: "v", text: "hi", speed: 1.1, storedVoiceSettings: stored
        )
        let settings = try XCTUnwrap(try body(req)["voice_settings"] as? [String: Any])
        XCTAssertEqual(settings["stability"] as? Double, 0.2)
        XCTAssertEqual(settings["similarity_boost"] as? Double, 0.9)
        XCTAssertEqual(settings["style"] as? Double, 0.6)
        XCTAssertEqual(settings["use_speaker_boost"] as? Bool, false)
        XCTAssertEqual(try XCTUnwrap(settings["speed"] as? Double), 1.1, accuracy: 1e-9)

        // At 1.0 nothing is overridden, so the saved settings (incl. their own speed) apply as-is.
        let normal = try builder.makeRequest(
            apiKey: "k", voiceID: "v", text: "hi", speed: 1.0, storedVoiceSettings: stored
        )
        XCTAssertNil(try body(normal)["voice_settings"])
    }

    func testVoiceSettingsRequestShape() throws {
        let req = try builder.makeVoiceSettingsRequest(
            baseURL: URL(string: "https://api.elevenlabs.io/v1")!, apiKey: "k", voiceID: " v1d "
        )
        XCTAssertEqual(req.url?.absoluteString, "https://api.elevenlabs.io/v1/voices/v1d/settings")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "k")
    }

    func testBlankModelFallsBackToDefault() throws {
        let req = try builder.makeRequest(apiKey: "k", voiceID: "v", text: "hi", modelID: "  ")
        XCTAssertEqual(try body(req)["model_id"] as? String, ElevenLabsRequestBuilder.defaultModelID)
        let custom = try builder.makeRequest(apiKey: "k", voiceID: "v", text: "hi", modelID: "eleven_flash_v2_5")
        XCTAssertEqual(try body(custom)["model_id"] as? String, "eleven_flash_v2_5")
    }

    func testThrowsWithoutKey() {
        XCTAssertThrowsError(try builder.makeRequest(apiKey: "", voiceID: "v", text: "hi")) { error in
            XCTAssertEqual(error as? SpeechProviderError, .missingAPIKey)
        }
    }

    func testThrowsWithoutVoice() {
        for voice in ["", "   "] {
            XCTAssertThrowsError(try builder.makeRequest(apiKey: "k", voiceID: voice, text: "hi")) { error in
                XCTAssertEqual(error as? SpeechProviderError, .missingVoice)
            }
        }
    }

    func testOutputFormatIsAppendedAsQuery() throws {
        let req = try builder.makeRequest(
            apiKey: "xi-key", voiceID: "voice123", text: "hi", outputFormat: "pcm_24000"
        )
        let components = URLComponents(url: try XCTUnwrap(req.url), resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.path, "/v1/text-to-speech/voice123/stream")
        XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "output_format" })?.value, "pcm_24000")
    }

    func testVoiceListRequestShape() throws {
        let req = try builder.makeVoiceListRequest(apiKey: "xi-key")
        XCTAssertEqual(req.url?.absoluteString, "https://api.elevenlabs.io/v2/voices?page_size=100")
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.value(forHTTPHeaderField: "xi-api-key"), "xi-key")
    }

    func testVoiceListRequestCarriesPageTokenAndNormalizesLegacyBase() throws {
        let req = try builder.makeVoiceListRequest(
            baseURL: URL(string: "https://api.elevenlabs.io/v1")!, apiKey: "k", pageToken: "abc"
        )
        XCTAssertEqual(
            req.url?.absoluteString,
            "https://api.elevenlabs.io/v2/voices?page_size=100&next_page_token=abc"
        )
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

    func testDecodesV2PageCursorAndPrefersVerifiedLocale() throws {
        let json = """
        { "voices": [
            { "voice_id": "JBFqnCBsd6RMkjVDRZzb", "name": "George", "category": "premade",
              "labels": { "accent": "british", "gender": "male", "language": "en" },
              "verified_languages": [ { "language": "en", "model_id": "eleven_v3", "locale": "en-GB" } ] },
            { "voice_id": "n1", "name": "River", "labels": { "accent": "american", "gender": "neutral" } }
          ],
          "has_more": true, "total_count": 40, "next_page_token": "tok2" }
        """.data(using: .utf8)!

        let page = try ElevenLabsVoiceList.decodePage(json)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextPageToken, "tok2")
        XCTAssertEqual(page.voices[0].language, "en-GB")
        XCTAssertEqual(page.voices[1].gender, .unspecified)
        XCTAssertNil(page.voices[1].language) // "american" is an accent, not a language tag
    }

    func testLibraryVoicesCarryAPaidPlanNote() throws {
        let json = """
        { "voices": [
            { "voice_id": "lib", "name": "Allison", "category": "professional",
              "sharing": { "status": "copied", "original_voice_id": "orig" } },
            { "voice_id": "pre", "name": "George", "category": "premade", "sharing": null },
            { "voice_id": "own", "name": "Mine", "category": "cloned", "sharing": { "status": "enabled" } }
        ] }
        """.data(using: .utf8)!
        let voices = try ElevenLabsVoiceList.decode(json)
        XCTAssertEqual(voices[0].note, ElevenLabsVoiceList.libraryVoiceNote)
        XCTAssertNil(voices[1].note)
        XCTAssertNil(voices[2].note) // the user's own voice, merely shared — not a library copy
    }

    func testOddMetadataDoesNotDropTheVoice() throws {
        let json = #"""
        { "voices": [ { "voice_id": "v1", "name": null,
                        "labels": { "gender": "female", "descriptive": null },
                        "verified_languages": "not-a-list" } ] }
        """#.data(using: .utf8)!
        let page = try ElevenLabsVoiceList.decodePage(json)
        XCTAssertEqual(page.voices.count, 1)
        XCTAssertEqual(page.voices[0].name, "v1")
        XCTAssertEqual(page.voices[0].gender, .female)
        XCTAssertFalse(page.hasMore) // legacy /v1 shape: no cursor
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

final class ElevenLabsErrorMessageTests: XCTestCase {
    private func extract(_ text: String) -> String? {
        ElevenLabsErrorMessage.extract(from: Data(text.utf8))
    }

    func testObjectDetailMessage() {
        XCTAssertEqual(
            extract(#"{"detail":{"status":"invalid_api_key","message":"Invalid API key"}}"#),
            "Invalid API key"
        )
        XCTAssertEqual(extract(#"{"detail":{"status":"quota_exceeded"}}"#), "quota_exceeded")
    }

    func testValidationListDetail() {
        XCTAssertEqual(
            extract(#"{"detail":[{"loc":["body","text"],"msg":"Field required","type":"missing"}]}"#),
            "body.text: Field required"
        )
    }

    func testStringDetailAndPlainText() {
        XCTAssertEqual(extract(#"{"detail":"Not Found"}"#), "Not Found")
        XCTAssertEqual(extract("Bad Gateway\n"), "Bad Gateway")
        XCTAssertNil(extract("  "))
    }

    func testDescriptionIncludesMessage() {
        XCTAssertEqual(
            "\(SpeechProviderError.httpStatus(401, body: "Invalid API key"))", "HTTP 401: Invalid API key"
        )
        XCTAssertEqual("\(SpeechProviderError.httpStatus(500, body: nil))", "HTTP 500")
    }
}

// MARK: - Provider over a stubbed URLSession

final class ElevenLabsProviderTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
        StubURLProtocol.reset()
    }

    private func provider(apiKey: String = "k") -> ElevenLabsProvider {
        ElevenLabsProvider(id: "el", apiKey: apiKey, session: session)
    }

    private func collect(_ stream: AsyncThrowingStream<AudioChunk, Error>) async throws -> [AudioChunk] {
        var chunks: [AudioChunk] = []
        for try await chunk in stream { chunks.append(chunk) }
        return chunks
    }

    func testSynthesizeStreamsPCMChunksFromTheStreamEndpoint() async throws {
        let audio = Data((0..<40_000).map { UInt8($0 % 251) })
        StubURLProtocol.respond { _ in (200, audio) }

        let chunks = try await collect(provider().synthesize(
            SpeechRequest(text: "hi", voice: "voiceA", model: "eleven_flash_v2_5", format: .pcm)
        ))
        XCTAssertEqual(chunks.last?.isFinal, true)
        XCTAssertEqual(Data(chunks.filter { !$0.isFinal }.flatMap(\.data)), audio)
        XCTAssertTrue(chunks.filter { !$0.isFinal }.allSatisfy { $0.pcmFormat == .openAIpcm })

        XCTAssertEqual(StubURLProtocol.requests.count, 1) // speed 1.0 → no saved-settings fetch
        let url = try XCTUnwrap(StubURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/v1/text-to-speech/voiceA/stream")
        XCTAssertEqual(url.query, "output_format=pcm_24000")
    }

    func testSpeedOverrideFetchesAndMergesSavedSettings() async throws {
        let saved = #"{"stability":0.2,"use_speaker_boost":false,"similarity_boost":0.9,"style":0.6,"speed":1.0}"#
        StubURLProtocol.respond { request in
            request.httpMethod == "GET" ? (200, Data(saved.utf8)) : (200, Data(repeating: 0, count: 64))
        }
        _ = try await collect(provider().synthesize(
            SpeechRequest(text: "hi", voice: "voiceA", format: .pcm, speed: 1.1)
        ))

        XCTAssertEqual(StubURLProtocol.requests.map(\.httpMethod), ["GET", "POST"])
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.path, "/v1/voices/voiceA/settings")
        let sent = try XCTUnwrap(StubURLProtocol.bodies.last)
        let settings = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: sent) as? [String: Any])?["voice_settings"] as? [String: Any]
        )
        XCTAssertEqual(settings["stability"] as? Double, 0.2)
        XCTAssertEqual(settings["style"] as? Double, 0.6)
        XCTAssertEqual(settings["use_speaker_boost"] as? Bool, false)
        XCTAssertEqual(try XCTUnwrap(settings["speed"] as? Double), 1.1, accuracy: 1e-9)
    }

    func testSpeedOverrideFallsBackToSpeedOnlyWhenSettingsUnavailable() async throws {
        StubURLProtocol.respond { request in
            request.httpMethod == "GET"
                ? (401, Data(#"{"detail":{"status":"missing_permissions"}}"#.utf8))
                : (200, Data(repeating: 0, count: 64))
        }
        _ = try await collect(provider().synthesize(
            SpeechRequest(text: "hi", voice: "voiceA", format: .pcm, speed: 0.8)
        ))

        let sent = try XCTUnwrap(StubURLProtocol.bodies.last)
        let settings = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: sent) as? [String: Any])?["voice_settings"] as? [String: Any]
        )
        XCTAssertEqual(Set(settings.keys), ["speed"])
        XCTAssertEqual(try XCTUnwrap(settings["speed"] as? Double), 0.8, accuracy: 1e-9)
    }

    func testSynthesizeSurfacesServerErrorMessage() async {
        StubURLProtocol.respond { _ in
            (401, Data(#"{"detail":{"status":"invalid_api_key","message":"Invalid API key"}}"#.utf8))
        }
        do {
            _ = try await collect(provider().synthesize(SpeechRequest(text: "hi", voice: "voiceA", format: .pcm)))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? SpeechProviderError, .httpStatus(401, body: "Invalid API key"))
        }
    }

    func testSynthesizeRefusesCompressedFormatsWithoutCallingTheAPI() async {
        StubURLProtocol.respond { _ in (200, Data()) }
        do {
            _ = try await collect(provider().synthesize(SpeechRequest(text: "hi", voice: "voiceA", format: .mp3)))
            XCTFail("expected an error")
        } catch {
            guard case .unsupported = error as? SpeechProviderError else {
                return XCTFail("unexpected \(error)")
            }
        }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testAvailableVoicesFollowsPagination() async throws {
        StubURLProtocol.respond { request in
            let token = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "next_page_token" })?.value
            let body = token == nil
                ? #"{"voices":[{"voice_id":"a","name":"A"}],"has_more":true,"next_page_token":"p2"}"#
                : #"{"voices":[{"voice_id":"b","name":"B"}],"has_more":false,"next_page_token":null}"#
            return (200, Data(body.utf8))
        }
        let voices = try await provider().availableVoices()
        XCTAssertEqual(voices.map(\.id), ["a", "b"])
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.path, "/v2/voices")
    }

    func testAvailableVoicesThrowsOnHTTPErrorAndMissingKey() async {
        StubURLProtocol.respond { _ in (401, Data(#"{"detail":{"message":"Invalid API key"}}"#.utf8)) }
        do {
            _ = try await provider().availableVoices()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? SpeechProviderError, .httpStatus(401, body: "Invalid API key"))
        }
        do {
            _ = try await provider(apiKey: "").availableVoices()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? SpeechProviderError, .missingAPIKey)
        }
    }
}

/// Serves canned responses to a `URLSession` configured with it, recording each request.
private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) private static var recorded: [URLRequest] = []
    nonisolated(unsafe) private static var recordedBodies: [Data] = []

    static var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    /// Request bodies, in order (empty for body-less requests).
    static var bodies: [Data] {
        lock.lock(); defer { lock.unlock() }
        return recordedBodies
    }

    static func respond(_ handler: @escaping (URLRequest) -> (Int, Data)) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = nil
        recorded = []
        recordedBodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let requestBody = Self.readBody(of: request)
        Self.lock.lock()
        Self.recorded.append(request)
        Self.recordedBodies.append(requestBody)
        let handler = Self.handler
        Self.lock.unlock()

        let (status, body) = handler?(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
