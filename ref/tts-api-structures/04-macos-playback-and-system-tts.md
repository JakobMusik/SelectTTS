# macOS Playback & System TTS

> Written in the **pass-2 gap-fill** (deep-research wf_011ff0d2-367, **2026-06-13**). Every
> structural/API claim verified against strong primary sources (OpenAI TTS guide, Apple
> AVFoundation/AVSpeechSynthesis docs + the `AVSpeechSynthesis.h` SDK header, Apple Dev Forums,
> minimp3, AudioStreaming, the dev.to "sub-200 ms time-to-first-audio" StreamTTS write-up).
> Zero claims refuted; soft spots flagged inline. See [`sources.md`](./sources.md) for provenance.

This covers two things SelectTTS needs that aren't HTTP-API shapes: (a) **how to play** TTS audio
on macOS — especially progressively, as bytes arrive — and (b) **AVSpeechSynthesizer**, the
built-in offline system voice used as the zero-config default provider.

---

## Part A — Playback (AVFoundation)

### AVAudioPlayer can't stream — use AVAudioEngine + AVAudioPlayerNode

**AVAudioPlayer** plays only *fully-available* audio: you init it with `contentsOf: URL` or
`data: Data`, both of which need the complete payload, and there is **no append-bytes API**.
Apple recommends it for playback *unless* you're streaming from a network stream or need very low
I/O latency — i.e. exactly the streaming-TTS case it's a **poor fit** for.
[sources: developer.apple.com/documentation/avfaudio/avaudioplayer,
monkeybreadsoftware.net/class-avaudioplayermbs.shtml,
learn.microsoft.com/.../xamarin/mac/app-fundamentals/sounds]

**AVAudioEngine is a push model** and is the low-latency progressive path:

1. Create an `AVAudioEngine`, attach an `AVAudioPlayerNode`, connect the node to the engine's
   **main mixer**.
2. As audio bytes arrive, build `AVAudioPCMBuffer`s and call `scheduleBuffer()` on the player
   node (or `scheduleFile()` with an `AVAudioFile`).
3. Schedule buffers **sequentially** so audio plays as it arrives with **no inter-chunk gaps**.

[sources: syedharisali.com/articles/streaming-audio-with-avaudioengine/,
dev.to/joostmbakker/how-i-got-sub-200ms-time-to-first-audio…,
developer.apple.com/documentation/avfaudio/avaudioplayernode]

### Request PCM (or WAV) — raw PCM has no decoder state

OpenAI's **`pcm`** format is raw **24 kHz, 16-bit signed, little-endian, mono, with NO header**
("Similar to WAV but contains the raw samples in 24kHz (16-bit signed, low-endian), without the
header"). OpenAI recommends `wav` or `pcm` for the fastest response times. (Full supported list:
mp3, opus, aac, flac, wav, pcm — the same spec is reused by the Realtime API.)
[sources: developers.openai.com/api/docs/guides/text-to-speech,
platform.openai.com/docs/guides/text-to-speech]

This is the load-bearing reason to prefer PCM/WAV: raw PCM has **no decoder state and no
frame-boundary alignment problem** (and for OpenAI `pcm`, no header to strip), so HTTP byte slices
can be turned into playable buffers immediately.

### The Int16 → Float32 buffer recipe

AVAudioEngine processes **32-bit float, non-interleaved** PCM internally, so raw Int16 TTS PCM
**must be converted to Float32** before scheduling. Wrong format → silence or exception (Int16
buffers throw on `AVAudioPlayerNode`; *interleaved* Float32 also crashes — non-interleaved works).
[sources: dev.to StreamTTS, developer.apple.com/forums/thread/747009]

```swift
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                           sampleRate: 24000,
                           channels: 1,
                           interleaved: false)!
// frameLength = byteCount / 2   (2 bytes per Int16 sample)
// reinterpret the incoming bytes as Int16 little-endian, then for each sample:
//   floatChannelData[0][i] = Float32(int16Sample) / 32768.0
```

`int16ChannelData` on an `AVAudioPCMBuffer` is non-nil only for an Int16-format buffer; here we
write into `floatChannelData[0]`. The divisor **32768.0 vs 32767.0** (`Int16.max`) is unsettled
in practice — both are used and the difference is negligible.
[sources: developer.apple.com/documentation/avfaudio/avaudiopcmbuffer, dev.to StreamTTS]

**No manual resample is required.** The engine's main mixer (`AVAudioMixerNode`) auto-converts
24 kHz → the hardware rate *if* you connect the player node using the 24 kHz format.
`AVAudioConverter` is the explicit alternative but is callback-based and error-prone (can emit
silent output with no error). These are **two valid paths** — the cited reference build actually
chose explicit `AVAudioConverter`, and note a mixer-to-mixer connection at a non-session rate may
not pass audio unless another source is also playing.
[sources: developer.apple.com/forums/thread/111726, developer.apple.com/forums/thread/703410,
dev.to StreamTTS]

### WAV header is NOT always 44 bytes

The canonical WAV header is a 44-byte RIFF/WAVE/fmt/data structure that must be skipped or parsed,
but it is **not guaranteed to be exactly 44 bytes** — an extended `fmt ` chunk or extra chunks make
it longer. **Don't hardcode 44**: parse chunk sizes / scan for the `data` chunk. OpenAI's `wav`
output is standard RIFF and needs the same handling.
[source: github.com/faiface/beep/issues/2]

### The MP3-frame-boundary problem (why we avoid MP3 for streaming)

MP3 and other compressed formats **cannot be fed arbitrary HTTP byte slices** — data must align to
whole MP3 frames. Frame sizes vary by bitrate (~417 bytes @ 128 kbps, ~626 @ 192 kbps); the
decoder reports the consumed-byte count (`frame_bytes`) that you must remove before the next call.
Short or misaligned buffers cause false sync + squealing artifacts (minimp3 recommends buffering
~10 frames / ~16 KB). Hence compressed streaming needs **Audio File Stream Services** to parse
packets first.
[sources: github.com/lieff/minimp3, syedharisali.com/…]

For a compressed format the full stack is: **Audio File Stream Services** (parse to packets) →
**Audio Converter Services** / `AudioConverterFillComplexBuffer` (decode to LPCM) → schedule LPCM
on `AVAudioPlayerNode`. The **AudioStreaming** library (dimitris-c) packages this — "An
AudioPlayer/Streaming library for iOS written in Swift using AVAudioEngine," supporting MP3, AAC,
FLAC, WAVE, CAF, AIFF/AIFC, ADTS, M4A, NeXT, Ogg Vorbis + Shoutcast/ICY.
[sources: github.com/dimitris-c/AudioStreaming, syedharisali.com/…]

### scheduleBuffer completion types + backpressure

`scheduleBuffer`'s completion **type** matters:

- **`.dataPlayedBack`** (default) — fires when audio is *actually output*, accounting for
  downstream + device latency.
- **`.dataRendered`** — fires earlier, when the player node has rendered the buffer (before
  downstream/device latency) — useful for low-latency chaining/backpressure.

The dev.to build uses completion callbacks + a `CheckedContinuation` to apply **backpressure** when
buffered audio exceeds **~3 s**, so synthesis doesn't race far ahead of playback.
[sources: medium.com/@mehsamadi/mastering-avaudioplayernode…, dev.to StreamTTS]

### Real-world latency

A documented real build hit **~180 ms time-to-first-audio** on an iPhone 15 Pro using PCM/WAV +
AVAudioEngine + AVAudioPlayerNode (Int16→Float32, scheduling buffers as bytes arrive), with a
~0.5 s start watermark and the ~3 s backpressure cap.
[source: dev.to StreamTTS]

> Caveat: even raw PCM needs a **byte accumulator emitting 2-byte-aligned chunks** — a 16-bit
> sample can split across two HTTP chunks. PCM has no *decoder-frame* problem (the load-bearing
> point), but it is not totally alignment-free.

### Honest uncertainty (playback)

- Apple's AVAudioPlayer / AVAudioPlayerNode / AVAudioPCMBuffer / AVAudioMixerNode reference pages
  are JS-rendered; the AVAudioPlayer "unless network stream / very low I/O latency" wording +
  completion-callback semantics were confirmed via mirrors/the SDK header — confirm against live
  Apple pages.
- Int16→Float32 divisor (32768.0 vs 32767.0) varies; no authoritative Apple prescription.
- Whether mixer-based 24 kHz → 48 kHz conversion quality suffices vs explicit `AVAudioConverter`
  (pitch/gap artifacts reported by some).
- Whether OpenAI's `wav` header is exactly 44 bytes or carries extra chunks was not verified
  against a captured response — treat as variable-length, parse the `data` chunk.

### Implications for SelectTTS

1. **This is the engineering backing for D5** ("LCD streaming = request `wav`/`pcm` over plain HTTP
   chunked transfer"). Request **PCM or WAV, never MP3, for streaming** — MP3's frame-boundary
   alignment is exactly the complexity D5 avoids.
2. **Playback engine = AVAudioEngine + AVAudioPlayerNode**, not AVAudioPlayer (which can't stream).
   Convert Int16→Float32 into `AVAudioPCMBuffer`s and `scheduleBuffer` as bytes arrive.
3. **Parse WAV headers, don't assume 44 bytes**; for OpenAI `pcm` there's no header to strip but
   keep a **2-byte-aligned byte accumulator** because samples can split across HTTP chunks.
4. **Apply backpressure** (~3 s buffered cap via completion callbacks) so synthesis doesn't outrun
   playback; this also gives a natural pause/stop point.
5. If a compressed format is ever unavoidable (e.g. a provider that only emits MP3), reach for the
   **AudioStreaming** library rather than hand-rolling Audio File Stream Services.

---

## Part B — System TTS: AVSpeechSynthesizer (zero-config offline default)

`AVSpeechSynthesizer` (AVFAudio / AVFoundation) is Apple's **built-in, on-device, no-key** TTS.
For SelectTTS it is the **zero-config offline default provider** — it ships with macOS, needs no
API key, no billing, and works with no network. The main limitation is that the *best-sounding*
voices require a one-time user download.

### Availability & no key

`AVSpeechSynthesizer` + `AVSpeechUtterance` are **macOS 10.14+** (iOS 7.0+, iPadOS 7.0+, Mac
Catalyst 13.1+, visionOS 1.0+, watchOS 2.0+, tvOS). The SDK header's rate constants carry
`API_AVAILABLE(ios(7.0), watchos(1.0), tvos(7.0), macos(10.14))`. No API key — it's a bundled
framework.
[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesizer,
developer.apple.com/documentation/avfaudio/avspeechutterance,
xybp888/iOS-SDKs …/AVSpeechSynthesis.h]

### Configuring an utterance — rate / pitch / volume

You configure an `AVSpeechUtterance` (text, voice, rate, pitchMultiplier, volume, pre/post delays)
and `speak(_:)` it aloud.

| Property | Range / default | Notes |
|----------|-----------------|-------|
| `rate` | pinned between `AVSpeechUtteranceMinimumSpeechRate` and `AVSpeechUtteranceMaximumSpeechRate`; default `AVSpeechUtteranceDefaultSpeechRate` | All three are `extern const float` globals (macOS 10.14). **rate is non-linear** in perceived speed. ⚠️ numeric values below are **not** Apple-confirmed. |
| `pitchMultiplier` | **[0.5 – 2.0], default 1.0** | Verbatim header: `// [0.5 - 2] Default = 1` |
| `volume` | **[0.0 – 1.0], default 1.0** | Verbatim header: `// [0-1] Default = 1` |
| `preUtteranceDelay` / `postUtteranceDelay` | `TimeInterval` | Pauses before / after the utterance |

[sources: AVSpeechSynthesis.h header,
developer.apple.com/documentation/avfaudio/avspeechutterance/preutterancedelay,
…/postutterancedelay, …/avspeechutterancemaximumspeechrate, …/minimumspeechrate,
…/defaultspeechrate]

> ⚠️ **Honest flag:** the *numeric* rate values widely cited (min 0.0 / max 1.0 / default ~0.5) are
> **NOT stated in any primary Apple source** — only the existence of the three constants is
> documented. Read the constants at runtime; don't hardcode `0.5`.

### Voice enumeration & quality tiers

Enumerate installed voices with the class method
`AVSpeechSynthesisVoice.speechVoices() -> [AVSpeechSynthesisVoice]` ("Retrieves all available
voices on the device"). Each voice exposes `identifier` (unique String), `language` (BCP-47),
`name`, `quality`, `gender`, `voiceTraits`, and `audioFileSettings`; `currentLanguageCode()`
returns the user's locale. `AVSpeechSynthesisVoice` is macOS 10.14+.
[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice, …/speechvoices()]

`AVSpeechSynthesisVoiceQuality`:

| Case | Meaning | Since |
|------|---------|-------|
| `.default` | "A basic quality voice that's available on the device by default" | iOS 9.0 / macOS 10.14 |
| `.enhanced` | "must download to use" | iOS 9.0 / macOS 10.14 |
| `.premium` | "must download to use" | iOS 16.0 / **macOS 13.0** (also watchOS 9.0+, visionOS 1.0+) |

[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesisvoicequality, …/premium]

Enhanced + premium voices are **not preinstalled** — the user downloads them once via System
Settings (Accessibility > Spoken Content > System Voice; exact current-macOS path unverified).
`speechVoices()` returns **only installed voices**, so apps should fall back to `.default`.
Default-quality voices run fully on-device/offline, bundled, with no install/key/billing.
[sources: …/avspeechsynthesisvoicequality/enhanced, …/premium]

### Rendering to a buffer — `write(_:toBufferCallback:)`

Instead of speaking aloud, you can render an utterance to audio buffers via
`write(_:toBufferCallback:)` (**macOS 10.15+**, iOS 13.0+, watchOS 6.0+, visionOS 1.0+) — abstract:
"Generates speech for the utterance and invokes the callback with the audio buffer." The callback
type is `AVSpeechSynthesizer.BufferCallback`
(`typedef void (^AVSpeechSynthesizerBufferCallback)(AVAudioBuffer *buffer)`); it receives an
`AVAudioBuffer` (in practice `AVAudioPCMBuffer`), writable to disk via `AVAudioFile` using
`AVSpeechSynthesisVoice.audioFileSettings`.

Two important operational facts:

- **You must strongly retain the synthesizer** until synthesis concludes — the system does **not**
  auto-retain it. (This *is* documented.)
- End-of-synthesis is signaled by a **final zero-frame-length buffer**; the API was **buggy on
  macOS 10.15 (Catalina)** and **fixed in macOS 11**.

[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesizer/write(_:tobuffercallback:),
AVSpeechSynthesis.h header, developer.apple.com/forums/thread/678287,
developer.apple.com/forums/thread/684419, developer.apple.com/forums/thread/731624]

> ⚠️ **Honest flag:** the **zero-length-buffer end-of-stream convention** and the Catalina-bug /
> macOS-11-fix detail are **forum-only**, not in Apple reference docs. The must-retain fact itself
> is documented.

### Word highlighting via the delegate

`AVSpeechSynthesizerDelegate` provides `didStart`, `didFinish`, `didPause`, `didContinue`,
`didCancel`, `willSpeak` (marker), and crucially
`speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)` — which delivers an **NSRange** of
the text about to be spoken. This is the standard hook for **live word highlighting**.
[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate,
…/speechsynthesizer(_:willspeakrangeofspeechstring:utterance:)]

### Personal Voice (macOS 14+)

Personal Voice is **macOS 14.0+** (iOS 17.0+). Request access with the class method
`requestPersonalVoiceAuthorization(completionHandler:)` (also `async -> PersonalVoiceAuthorizationStatus`)
and read `personalVoiceAuthorizationStatus`. `PersonalVoiceAuthorizationStatus` cases:
`notDetermined`, `denied`, `unsupported` ("The device doesn't support personal voices"),
`authorized`. The user must create a voice in Settings > Accessibility > Personal Voice and enable
"Allow Apps to Request to Use" (~150 prompts, on-device); once authorized the voice appears in
`speechVoices()` flagged by the `isPersonalVoice` voiceTrait.
[sources: developer.apple.com/documentation/avfaudio/avspeechsynthesizer/requestpersonalvoiceauthorization(completionhandler:),
…/personalvoiceauthorizationstatus, developer.apple.com/videos/play/wwdc2023/10033/,
bendodson.com/weblog/2024/04/03/using-your-personal-voice-in-an-ios-app/]

> ⚠️ **Honest flag:** **no special entitlement / Info.plist usage key for Personal Voice is
> documented** — this is *absence-of-evidence*, not independently proven. Re-check whether a
> sandboxed/MAS build needs one.

### Honest uncertainty (system TTS)

- Exact numeric value of `AVSpeechUtteranceDefaultSpeechRate` (widely reported ~0.5, not confirmed
  from a primary Apple source); min/max (0.0/1.0) come from secondary summaries.
- The `write()` zero-length end-of-stream convention + macOS 10.15 bug / macOS 11 fix are
  forum-only.
- Whether any entitlement / Info.plist key / sandbox exception is required for Personal Voice on a
  sandboxed/MAS macOS app.
- Exact current macOS (Sequoia/Tahoe 2025–2026) System Settings path to download enhanced/premium
  voices.
- "Default voices sound robotic vs cloud TTS" is subjective.

### Implications for SelectTTS

1. **AVSpeechSynthesizer is the offline, zero-config, key-less default provider** (D3) — always
   available, no network, ships with macOS. Use it as the fallback when no cloud/local profile is
   configured or reachable.
2. **Build a voice picker from `speechVoices()`** (it only returns *installed* voices) and **fall
   back to `.default` quality**; surface that enhanced/premium/Personal voices need a one-time
   download in System Settings.
3. **Word highlighting comes for free** via `willSpeakRangeOfSpeechString` — wire it to the same
   highlight UI the streaming providers would use.
4. **Strongly retain the synthesizer** for the lifetime of speech (and especially when using
   `write(_:toBufferCallback:)`), or audio cuts off / the callback never completes.
5. Read `rate` bounds from the runtime constants; **don't hardcode `0.5`**.
6. Personal Voice (macOS 14+) is a nice optional upsell, but verify entitlement/sandbox needs
   before relying on it in a notarized build.
