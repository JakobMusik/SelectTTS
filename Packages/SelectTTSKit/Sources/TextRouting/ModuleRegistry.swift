import Foundation

/// Static-but-open registry: modules are compiled in and registered in exactly one place. Adding a
/// module = a new type + one registration line (no dynamic plugin loading in v1).
public final class ModuleRegistry: @unchecked Sendable {
    private var modules: [TextModule]
    private let lock = NSLock()

    public init(_ modules: [TextModule] = []) {
        self.modules = modules
    }

    public func register(_ module: TextModule) {
        lock.lock(); defer { lock.unlock() }
        modules.append(module)
    }

    public var all: [TextModule] {
        lock.lock(); defer { lock.unlock() }
        return modules
    }

    public var enabledModules: [TextModule] {
        all.filter { $0.isEnabled }
    }

    public func module(withID id: ModuleID) -> TextModule? {
        all.first { $0.id == id }
    }
}
