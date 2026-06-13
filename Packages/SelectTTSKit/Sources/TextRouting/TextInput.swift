import Foundation

/// The unit that flows from the capture engine into the router.
public struct TextInput: Sendable, Equatable {
    public let text: String
    public let sourceApp: AppInfo?
    public let trigger: Trigger
    public let date: Date

    public init(text: String, sourceApp: AppInfo? = nil, trigger: Trigger = .manual, date: Date = Date()) {
        self.text = text
        self.sourceApp = sourceApp
        self.trigger = trigger
        self.date = date
    }
}

/// Identifies the app the selection came from, letting modules/providers adapt or log.
public struct AppInfo: Sendable, Equatable, Hashable {
    public let bundleID: String?
    public let name: String?

    public init(bundleID: String? = nil, name: String? = nil) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// How a capture/route was initiated.
public enum Trigger: String, Sendable, Equatable, Codable {
    case hotkey
    case menuBar
    case services
    case manual
}
