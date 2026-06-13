import SwiftUI

/// Menu-bar-only SwiftUI app (decision D7): `MenuBarExtra` for the dropdown + a `Settings` scene,
/// with `LSUIElement` hiding the Dock icon. The `AppDelegate` pins the accessory activation policy.
@main
struct SelectTTSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra("SelectTTS", systemImage: "speaker.wave.2.fill") {
            MenuContent()
                .environmentObject(environment)
        }

        Settings {
            SettingsView()
                .environmentObject(environment)
        }
    }
}
