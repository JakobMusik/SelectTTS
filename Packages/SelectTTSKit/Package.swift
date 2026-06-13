// swift-tools-version:5.9
import PackageDescription

// SelectTTSKit — the pure, UI-free, headless-testable cores of SelectTTS.
//
// Per decision D10 (refining D6) these live as ONE local SPM package with one
// target per core; module boundaries are enforced by per-target dependencies.
// Per D11 the package depends ONLY on the Apple SDK (no remote SPM deps) so
// `swift test` is hermetic and network-free. The .xcodeproj app target injects
// the remote-backed implementations (SelectedTextKit, Defaults, …) through the
// protocols defined here (SelectionCapturing, SecretStore, SettingsStore, …).

let package = Package(
    name: "SelectTTSKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SelectTTSKit",
            targets: [
                "SpeechCore",
                "TextRouting",
                "SelectionCapture",
                "Providers",
                "AudioPlayback",
                "AppSettings",
                "TTSModule",
            ]
        )
    ],
    targets: [
        // Pure domain cores (no inter-target deps)
        .target(name: "SpeechCore"),
        .target(name: "TextRouting"),
        .target(name: "SelectionCapture"),

        // Cores layered on SpeechCore
        .target(name: "Providers", dependencies: ["SpeechCore"]),
        .target(name: "AudioPlayback", dependencies: ["SpeechCore"]),
        .target(name: "AppSettings", dependencies: ["SpeechCore"]),

        // The flagship module: wires text → chunk → speech → sink. Depends only on the
        // abstractions (SpeechProvider, AudioSink in SpeechCore; TextModule in TextRouting);
        // concrete providers/players are injected by the app.
        .target(
            name: "TTSModule",
            dependencies: ["SpeechCore", "TextRouting"]
        ),

        // Tests
        .testTarget(name: "SpeechCoreTests", dependencies: ["SpeechCore"]),
        .testTarget(name: "TextRoutingTests", dependencies: ["TextRouting"]),
        .testTarget(name: "SelectionCaptureTests", dependencies: ["SelectionCapture"]),
        .testTarget(name: "ProvidersTests", dependencies: ["Providers"]),
        .testTarget(name: "AudioPlaybackTests", dependencies: ["AudioPlayback"]),
        .testTarget(name: "AppSettingsTests", dependencies: ["AppSettings"]),
        .testTarget(name: "TTSModuleTests", dependencies: ["TTSModule", "SpeechCore", "TextRouting"]),
    ]
)
