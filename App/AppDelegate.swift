import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // LSUIElement already makes this an accessory; assert it in case of an atypical launch.
        NSApp.setActivationPolicy(.accessory)
    }
}
