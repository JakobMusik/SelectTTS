# Third-Party Notices

SelectTTS is MIT-licensed. It links the following third-party packages, pinned in
`SelectTTS.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Each package's
full license text is in [`App/Licenses/`](App/Licenses/), copied verbatim from the pinned version,
and ships inside the app, where Settings ▸ About ▸ Third-Party Licenses shows it.

| Component | Use | License |
|-----------|-----|---------|
| [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) | Selection-capture chain | [MIT](App/Licenses/SelectedTextKit-LICENSE.txt) |
| [AXSwift](https://github.com/tisfeng/AXSwift) | (via SelectedTextKit) Accessibility API; a fork of [tmandry/AXSwift](https://github.com/tmandry/AXSwift) | [MIT](App/Licenses/AXSwift-LICENSE.txt) |
| [KeySender](https://github.com/jordanbaird/KeySender) | (via SelectedTextKit) synthetic key events | [MIT](App/Licenses/KeySender-LICENSE.txt) |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkey + recorder | [MIT](App/Licenses/KeyboardShortcuts-LICENSE.txt) |

Their copyright notices, as they appear in those license files:

```text
SelectedTextKit    Copyright (c) 2024 tisfeng
AXSwift            Copyright (c) 2017 Tyler Mandry
KeySender          Copyright (c) 2022 Jordan Baird - https://github.com/jordanbaird/KeySender
KeyboardShortcuts  Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)
```

> NOTE: This app **does not** use code from [Easydict](https://github.com/tisfeng/Easydict),
> which is GPL-3.0. The selection-capture logic is reused via the separately MIT-licensed
> SelectedTextKit package, which imposes no copyleft.

When a package is added, removed or re-pinned, update three places together: its license file in
`App/Licenses/` (copied from the resolved checkout), `ThirdPartyComponent.all` in
`App/Settings/LicensesView.swift`, and this file.
