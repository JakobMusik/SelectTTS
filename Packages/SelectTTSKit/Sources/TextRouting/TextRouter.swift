import Foundation

/// Centralized input policy applied before any module runs.
public struct RoutingPolicy: Sendable, Equatable {
    /// Minimum length (after trimming) for input to be routed.
    public var minLength: Int
    /// Hard cap; longer input is rejected (modules like TTS chunk *within* their own limits).
    public var maxLength: Int

    public init(minLength: Int = 1, maxLength: Int = 1_000_000) {
        self.minLength = minLength
        self.maxLength = maxLength
    }

    public static let `default` = RoutingPolicy()
}

/// Why an input was not routed to any module.
public enum RoutingRejection: Error, Equatable, Sendable {
    case empty
    case tooShort(minLength: Int)
    case tooLong(maxLength: Int)
    case noEnabledModule
}

/// The result of routing one input.
public struct RouteOutcome: Sendable, Equatable {
    /// IDs of modules whose `perform` was invoked (in order).
    public let handledBy: [ModuleID]
    /// Per-module failures captured during `perform` (module id → error description).
    public let failures: [ModuleFailure]

    public struct ModuleFailure: Sendable, Equatable {
        public let moduleID: ModuleID
        public let message: String
    }
}

/// Routes a `TextInput` to every enabled module that can handle it.
///
/// v1 default has a single enabled module (TTS), so routing is effectively "speak it" — but the
/// indirection is what lets new modules be added without touching the capture layer.
public final class TextRouter: Sendable {
    private let registry: ModuleRegistry
    private let policy: RoutingPolicy

    public init(registry: ModuleRegistry, policy: RoutingPolicy = .default) {
        self.registry = registry
        self.policy = policy
    }

    /// Validates `input` against the policy, then performs each enabled, willing module.
    /// Throws `RoutingRejection` if the input is filtered out or there is nothing enabled, and
    /// rethrows `CancellationError` when the routing task was cancelled (e.g. the user hit Stop).
    @discardableResult
    public func route(_ input: TextInput) async throws -> RouteOutcome {
        let trimmed = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw RoutingRejection.empty }
        if trimmed.count < policy.minLength { throw RoutingRejection.tooShort(minLength: policy.minLength) }
        if trimmed.count > policy.maxLength { throw RoutingRejection.tooLong(maxLength: policy.maxLength) }

        let modules = registry.enabledModules.filter { $0.canHandle(input) }
        if modules.isEmpty { throw RoutingRejection.noEnabledModule }

        var handled: [ModuleID] = []
        var failures: [RouteOutcome.ModuleFailure] = []
        for module in modules {
            do {
                try await module.perform(input)
                handled.append(module.id)
            } catch let cancellation as CancellationError {
                // A user stop is not a module failure — propagate it so the caller can tell.
                throw cancellation
            } catch {
                failures.append(.init(moduleID: module.id, message: String(describing: error)))
            }
        }
        return RouteOutcome(handledBy: handled, failures: failures)
    }
}
