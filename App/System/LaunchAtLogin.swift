import ServiceManagement

/// "Open at login" via `SMAppService.mainApp` (macOS 13+): registers this app bundle as a login item
/// with Background Task Management, so no helper app is needed. The user can also flip it in System
/// Settings ▸ General ▸ Login Items, which is why the state is re-read rather than stored.
enum LaunchAtLogin {
    enum State: Equatable {
        case enabled
        case disabled
        /// Registered, but the user must allow it in System Settings ▸ General ▸ Login Items.
        case requiresApproval
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
