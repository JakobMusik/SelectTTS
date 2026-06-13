# Licensing — Reusing Easydict's Text-Selection Capture via SelectedTextKit

Can SelectTTS reuse Easydict's selected-text-capture logic without inheriting copyleft? The answer
turns entirely on **which** code is reused: the extracted **SelectedTextKit** package (MIT) is safe;
copying from the **Easydict** repo (GPL-3.0) is not.

> Deep-research pass on **2026-06-13** (workflow **wf_011ff0d2-367**, research →
> adversarial-verify). All 10 claims confirmed against primary sources (GitHub license API + raw
> LICENSE/`Package.swift`; gnu.org GPLv3 §5; apache.org one-way compatibility + §3 patent grant;
> mozilla.org MPL-2.0 file-level copyleft; opensource.org MIT). **No claim refuted.**
> **This is an engineering reading of license texts, not legal advice.**

## The decision

> **SelectTTS = MIT.**

SelectTTS depends on / vendors **SelectedTextKit (MIT)**, which imposes no copyleft and no
license-choice constraint, so the app is free to be MIT. MIT is chosen for maximum permissiveness
and minimal obligation (attribution only).

## The two paths (confirmed)

| Path | What you reuse | License of that code | Effect on SelectTTS |
|------|----------------|----------------------|---------------------|
| **A — clean (chosen)** | Depend on / vendor the **SelectedTextKit** package | **MIT** | Free license choice (MIT/Apache-2.0/BSD/proprietary); sole duty = reproduce MIT notices |
| **B — trap** | Copy / hand-port code from the **Easydict** repo | **GPL-3.0** | Forces the **entire** app to be GPL-3.0 + source-available |
| **C — hypothetical** | An MPL-2.0 dependency (none actually present) | MPL-2.0 | Only MPL files stay MPL; rest of the app can be MIT/Apache/proprietary |

## The facts (confirmed)

- **Easydict (`tisfeng/Easydict`) = GPL-3.0.** License API `spdx_id` "GPL-3.0"; the raw LICENSE
  begins "GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007", "Copyright (c) 2023 Tisfeng."
  Sources:
  [Easydict/LICENSE](https://github.com/tisfeng/Easydict/blob/dev/LICENSE),
  [api.github.com/repos/tisfeng/Easydict/license](https://api.github.com/repos/tisfeng/Easydict/license).
- **SelectedTextKit (`tisfeng/SelectedTextKit`) = MIT.** Raw LICENSE "MIT License / Copyright (c)
  2024 tisfeng"; `spdx_id` "MIT". It is a SwiftPM library, `swift-tools-version 5.9`, `.macOS(.v11)`.
  Sources:
  [SelectedTextKit/LICENSE](https://github.com/tisfeng/SelectedTextKit/blob/main/LICENSE),
  [SelectedTextKit/Package.swift](https://github.com/tisfeng/SelectedTextKit/blob/main/Package.swift),
  [api license](https://api.github.com/repos/tisfeng/SelectedTextKit/license).
- **Transitive deps = MIT:** AXSwift (tisfeng fork, from 0.3.6) and KeySender
  (`jordanbaird/KeySender`, from 0.0.5) are both MIT (upstream `tmandry/AXSwift` is also MIT).
  **Vendoring SelectedTextKit pulls only MIT code.**
  Sources: SelectedTextKit/Package.swift, tisfeng/AXSwift/LICENSE, jordanbaird/KeySender/LICENSE.
- **Sparkle 2.x = MIT-style core** (Andy Matuschak et al. + a verbatim MIT grant) **+ an "EXTERNAL
  LICENSES" section**: `bspatch.c`/`bsdiff.c` BSD-2-Clause (Colin Percival), sais-lite MIT, ed25519
  zlib-style, `SUSignatureVerifier` BSD. The GitHub API shows NOASSERTION / "Other" *only* because
  of the appended external section; **all parts are permissive**.
  Sources:
  [Sparkle 2.x LICENSE](https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE), api license.
- **KeyboardShortcuts, Defaults** (sindresorhus), **KeychainAccess** (kishikawakatsumi) are all
  **MIT** (`spdx_id` "MIT" each). Sources: each repo's license file.

## Why MIT here imposes no constraint (confirmed)

Because SelectedTextKit is **MIT (permissive, non-copyleft)**, depending on / vendoring it does
**NOT** force SelectTTS open-source or copyleft — the app could be MIT, Apache-2.0, BSD, or even
proprietary/closed-source. MIT grants "use, copy, modify, merge, publish, distribute, sublicense,
and/or sell" with no reciprocal disclosure; the only condition is including the copyright +
permission notice.
Sources: SelectedTextKit/LICENSE, [opensource.org/license/mit](https://opensource.org/license/mit).

**Sole obligation = attribution.** Reproduce the MIT copyright + permission notices for
SelectedTextKit, AXSwift, KeySender (plus Sparkle's BSD/external notices) in the distribution — a
bundled `NOTICES` file or an in-app "About > Licenses" screen.
Sources: opensource.org/license/mit, Sparkle 2.x LICENSE.

## The GPL trap (confirmed)

**GPL-3.0 is whole-program (strong) copyleft.** Copying or linking Easydict's GPL code forces the
**entire combined app** to be GPL-3.0 (or GPL-3.0-compatible) with corresponding source — it
**cannot** be MIT/Apache-2.0 or proprietary. GPLv3 §5: "...to the whole of the work, and all its
parts." Apache-2.0 is **one-way compatible** (Apache code may go *into* a GPLv3 project; the
combined result is GPLv3, not Apache).
Sources:
[gnu.org/licenses/gpl-3.0.en.html](https://www.gnu.org/licenses/gpl-3.0.en.html),
[gnu.org/licenses/quick-guide-gplv3.html](https://www.gnu.org/licenses/quick-guide-gplv3.html),
[apache.org/licenses/GPL-compatibility.html](https://www.apache.org/licenses/GPL-compatibility.html).

The real trap is **copying / hand-porting GPL code directly from the Easydict repo.** Note: the
"SelectedTextKit was extracted from GPL Easydict" narrative is **provenance, not a license fact** —
tisfeng owns both repos and may relicense their own code, so the MIT grant on SelectedTextKit stands
on its own.

## MIT vs Apache-2.0 vs MPL-2.0 (confirmed)

| License | Copyleft scope | Notable feature |
|---------|----------------|-----------------|
| **MIT** | None (permissive) | Minimal; attribution only |
| **Apache-2.0** | None (permissive) | Adds an **express patent grant** (§3); one-way compatible into GPLv3 |
| **MPL-2.0** | **File-level** (weak) | Only MPL-covered files + your modifications stay MPL/source-disclosed; the rest of the "Larger Work" can be MIT/Apache/proprietary (MPL §3.3) |

- **MPL-2.0 = file-level (weak) copyleft.** An MPL-2.0 dep would NOT force the whole app copyleft —
  only the MPL-covered files (and your modifications to them) stay MPL/source-disclosed. **None of
  the actual deps are MPL-2.0.**
  Sources:
  [mozilla.org/en-US/MPL/2.0](https://www.mozilla.org/en-US/MPL/2.0/),
  [mozilla.org/MPL/2.0/FAQ](https://www.mozilla.org/MPL/2.0/FAQ/).

## Per-scenario recommendation (confirmed)

- **(A) Depend on / vendor SelectedTextKit** (MIT — the actual case): free license choice. Pick MIT
  or Apache-2.0 (Apache-2.0 if you want the express patent grant, §3), or stay proprietary; just
  ship the attribution notices.
- **(B) Copy GPL-3.0 Easydict code:** you must GPL the whole app + publish source — avoid unless
  intended.
- **(C) Hypothetical MPL-2.0 dep:** the app can be MIT/Apache/proprietary, but keep the MPL files
  under MPL with source disclosed.
  Sources: SelectedTextKit/LICENSE, Easydict/LICENSE,
  [apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0).

## Open questions / caveats (honest)

- This is an **engineering reading, not legal advice**; confirm with a licensing attorney for any
  code copied from GPL-3.0 Easydict.
- **Hand-porting** Easydict's GPL source (vs calling the MIT package) could still create a GPL
  derivative-work argument; **calling the MIT SelectedTextKit package is the clean path.**
- Reproduce Sparkle's full external-license notices **verbatim** before shipping.
- Re-verify SPDX status at integration time (branches as of 2026-06-13: Easydict `dev`,
  SelectedTextKit / AXSwift / KeySender `main`, Sparkle `2.x`, KeychainAccess `master`).
- SelectedTextKit's Accessibility / simulated-copy approach is a **separate functional/entitlement
  consideration** (Accessibility permission, sandbox/App Store review) — not a license question;
  see [`04-…`](./04-distribution-signing-ci.md).

## Implications for SelectTTS

- **License SelectTTS as MIT.** The dependency on SelectedTextKit (MIT, with MIT transitive deps)
  imposes no copyleft, so MIT is a free, low-obligation choice.
- **Consume SelectedTextKit as a package; never copy code from the Easydict repo.** The MIT package
  is the clean path; hand-porting from GPL-3.0 Easydict would force the whole app to GPL-3.0.
- **Ship a `NOTICES` / "About > Licenses" screen** reproducing the MIT notices for SelectedTextKit,
  AXSwift, KeySender, the sindresorhus libraries, and Sparkle's full external-license section.
