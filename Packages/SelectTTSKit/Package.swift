// swift-tools-version:5.9
import PackageDescription

// SelectTTSKit — the pure, UI-free, headless-testable cores of SelectTTS.
//
// ONE local SPM package with one target per core, rather than a package per
// core: module boundaries are still enforced by per-target dependencies. The
// package depends ONLY on the Apple SDK (no remote SPM deps) so `swift test` is
// hermetic and network-free. Anything backed by a remote package lives in the
// .xcodeproj app target and is injected through a protocol defined here (e.g.
// the SelectedTextKit-backed `SelectionCapturing`).

let package = Package(
    name: "SelectTTSKit",
    platforms: [
        .macOS(.v13),
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
                "AppCore",
            ]
        ),
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

        // Composition root (the headless "brain"): builds providers from config and wires
        // capture → route → speak. The app target adds only UI + remote-dep implementations.
        .target(
            name: "AppCore",
            dependencies: [
                "SpeechCore", "TextRouting", "SelectionCapture",
                "Providers", "AudioPlayback", "AppSettings", "TTSModule",
            ]
        ),

        // Tests
        .testTarget(name: "SpeechCoreTests", dependencies: ["SpeechCore"]),
        .testTarget(name: "TextRoutingTests", dependencies: ["TextRouting"]),
        .testTarget(name: "SelectionCaptureTests", dependencies: ["SelectionCapture"]),
        .testTarget(name: "ProvidersTests", dependencies: ["Providers"]),
        .testTarget(name: "AudioPlaybackTests", dependencies: ["AudioPlayback"]),
        .testTarget(name: "AppSettingsTests", dependencies: ["AppSettings"]),
        .testTarget(name: "TTSModuleTests", dependencies: ["TTSModule", "SpeechCore", "TextRouting"]),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore", "SpeechCore", "TextRouting", "SelectionCapture", "AppSettings"]
        ),
    ]
)
