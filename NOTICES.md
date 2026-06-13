# Third-Party Notices

SelectTTS is MIT-licensed. It bundles / depends on the following third-party components.
Their license notices are reproduced here (and in the app's About ▸ Licenses pane).

| Component | Use | License |
|-----------|-----|---------|
| [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) | Selection-capture chain | MIT |
| [AXSwift](https://github.com/tmandry/AXSwift) | (via SelectedTextKit) Accessibility API | MIT |
| [KeySender](https://github.com/jordanbaird/KeySender) | (via SelectedTextKit) synthetic key events | MIT |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey + recorder | MIT |
| [Defaults](https://github.com/sindresorhus/Defaults) | Typed UserDefaults | MIT |
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | Launch at login (SMAppService) | MIT |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Auto-update | MIT (core) + BSD/zlib (externals) |

> NOTE: This app **does not** use code from [Easydict](https://github.com/tisfeng/Easydict),
> which is GPL-3.0. The selection-capture logic is reused via the separately MIT-licensed
> SelectedTextKit package, which imposes no copyleft (decision D8).

Full license texts will be vendored under `Resources/Licenses/` when each dependency is added to
the app target.
