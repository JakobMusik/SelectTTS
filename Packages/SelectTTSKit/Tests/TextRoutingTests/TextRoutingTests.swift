import XCTest
@testable import TextRouting

private final class FakeModule: TextModule, @unchecked Sendable {
    let id: ModuleID
    let displayName: String
    var isEnabled: Bool
    let handles: Bool
    private let lock = NSLock()
    private(set) var performedInputs: [TextInput] = []

    init(id: ModuleID, isEnabled: Bool = true, handles: Bool = true) {
        self.id = id
        self.displayName = id
        self.isEnabled = isEnabled
        self.handles = handles
    }

    func canHandle(_ input: TextInput) -> Bool { handles }

    func perform(_ input: TextInput) async throws {
        lock.lock(); performedInputs.append(input); lock.unlock()
    }

    var performCount: Int { lock.lock(); defer { lock.unlock() }; return performedInputs.count }
}

private struct BoomError: Error {}
private final class FailingModule: TextModule, @unchecked Sendable {
    let id: ModuleID = "boom"
    let displayName = "boom"
    var isEnabled = true
    func canHandle(_ input: TextInput) -> Bool { true }
    func perform(_ input: TextInput) async throws { throw BoomError() }
}

final class TextRouterTests: XCTestCase {

    func testDispatchesToEnabledWillingModules() async throws {
        let a = FakeModule(id: "a")
        let b = FakeModule(id: "b")
        let router = TextRouter(registry: ModuleRegistry([a, b]))
        let outcome = try await router.route(TextInput(text: "hello"))
        XCTAssertEqual(Set(outcome.handledBy), ["a", "b"])
        XCTAssertEqual(a.performCount, 1)
        XCTAssertEqual(b.performCount, 1)
    }

    func testSkipsDisabledAndUnwilling() async throws {
        let disabled = FakeModule(id: "off", isEnabled: false)
        let unwilling = FakeModule(id: "cant", handles: false)
        let ok = FakeModule(id: "ok")
        let router = TextRouter(registry: ModuleRegistry([disabled, unwilling, ok]))
        let outcome = try await router.route(TextInput(text: "hi"))
        XCTAssertEqual(outcome.handledBy, ["ok"])
        XCTAssertEqual(disabled.performCount, 0)
        XCTAssertEqual(unwilling.performCount, 0)
    }

    func testRejectsEmptyInput() async {
        let router = TextRouter(registry: ModuleRegistry([FakeModule(id: "a")]))
        await assertThrows(RoutingRejection.empty) { try await router.route(TextInput(text: "   ")) }
    }

    func testRejectsTooLong() async {
        let router = TextRouter(
            registry: ModuleRegistry([FakeModule(id: "a")]),
            policy: RoutingPolicy(minLength: 1, maxLength: 5)
        )
        await assertThrows(RoutingRejection.tooLong(maxLength: 5)) {
            try await router.route(TextInput(text: "way too long"))
        }
    }

    func testRejectsWhenNoEnabledModule() async {
        let router = TextRouter(registry: ModuleRegistry([FakeModule(id: "off", isEnabled: false)]))
        await assertThrows(RoutingRejection.noEnabledModule) {
            try await router.route(TextInput(text: "hi"))
        }
    }

    func testCapturesModuleFailuresWithoutAborting() async throws {
        let ok = FakeModule(id: "ok")
        let router = TextRouter(registry: ModuleRegistry([FailingModule(), ok]))
        let outcome = try await router.route(TextInput(text: "hi"))
        XCTAssertEqual(outcome.handledBy, ["ok"])
        XCTAssertEqual(outcome.failures.map(\.moduleID), ["boom"])
    }

    func testRegistryRegisterAndLookup() {
        let registry = ModuleRegistry()
        let m = FakeModule(id: "m")
        registry.register(m)
        XCTAssertNotNil(registry.module(withID: "m"))
        XCTAssertEqual(registry.enabledModules.count, 1)
    }

    // MARK: - Helper

    private func assertThrows<E: Error & Equatable>(
        _ expected: E, _ block: () async throws -> Void,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            try await block()
            XCTFail("expected error \(expected)", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }
}
