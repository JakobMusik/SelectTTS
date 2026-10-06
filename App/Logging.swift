import os

/// Unified-logging channels (`log stream --predicate 'subsystem == "com.selecttts.app"'`). Never log
/// the captured text itself — only its length and where it came from.
enum Log {
    static let speak = Logger(subsystem: "com.selecttts.app", category: "speak")
    static let capture = Logger(subsystem: "com.selecttts.app", category: "capture")
}
