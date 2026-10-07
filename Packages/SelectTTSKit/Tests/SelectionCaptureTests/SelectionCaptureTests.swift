@testable import SelectionCapture
import XCTest

final class SelectionCaptureTests: XCTestCase {

    func testStubReturnsConfiguredText() async throws {
        let capturer = StubSelectionCapturer(
            text: "selected words",
            app: CapturedApp(bundleID: "com.apple.Safari", name: "Safari")
        )
        let result = try await capturer.captureSelection()
        XCTAssertEqual(result.text, "selected words")
        XCTAssertEqual(result.strategy, .accessibility)
        XCTAssertEqual(result.app?.bundleID, "com.apple.Safari")
    }

    func testStubCanThrow() async {
        let capturer = StubSelectionCapturer(result: .failure(.noSelection))
        do {
            _ = try await capturer.captureSelection()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? CaptureError, .noSelection)
        }
    }

    func testCaptureStrategyCodableRoundTrip() throws {
        for strategy in [CaptureStrategy.accessibility, .appleScript, .menuAction, .shortcut] {
            let data = try JSONEncoder().encode(strategy)
            XCTAssertEqual(try JSONDecoder().decode(CaptureStrategy.self, from: data), strategy)
        }
    }
}
