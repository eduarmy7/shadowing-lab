# Vendored fork of `audio_waveforms` 2.0.2

This is a local copy of the [audio_waveforms](https://pub.dev/packages/audio_waveforms)
package (originally at `~/.pub-cache/hosted/pub.dev/audio_waveforms-2.0.2`),
vendored into this project on 2026-08-08 to patch a real performance bug.
`example/`, `doc/`, and `preview/` were deleted from the copy — not needed to build.

## The bug

`extractWaveformData(path, noOfSamples)` decodes the whole audio file and, for
**every single one** of `noOfSamples` data points, calls
`methodChannel.invokeMethod(...)` (Android: `WaveformExtractor.kt`'s
`sendProgress`; iOS: `WaveformExtractor.swift`'s `sendWaveformDataToFlutter`)
re-sending the **entire accumulated waveform array so far** across the Flutter
platform channel — not just the new point.

That's an O(N²) cost in `noOfSamples`. This app requests up to 150,000 samples
(for 100ms-resolution silence detection on long files — see
`lib/core/audio/silence_detector.dart`), and confirmed on a real device this
turned a multi-minute native decode into 30+ minutes.

## Why it's safe to throttle

The awaited Dart `Future<List<double>> extractWaveformData(...)` does **not**
depend on that per-point channel call at all:
- Android: resolved via `ExtractorCallBack.onProgress(value)` hitting `1.0`,
  which is called unconditionally in `sendProgress` *before* the (now
  throttled) `invokeMethod` call.
- iOS: resolved via the `onExtractionComplete` closure, called once *after*
  the whole extraction loop finishes, entirely separate from
  `sendWaveformDataToFlutter`.

That per-point channel call only feeds the package's `onCurrentExtractedWaveformData`
/`onExtractionProgress` **live-update streams**, which this app never listens
to (`silence_detector.dart` only awaits the final result).

## The patch

Both platforms: throttle the per-point channel broadcast to at most ~200 sends
over the whole extraction (always including the very last point), instead of
one send per data point. `sampleData`/`waveformStorage` accumulation and the
actual completion callback are untouched — only the redundant live-stream
broadcast frequency changed. Anyone who *does* listen to the live stream still
gets ~200 updates over the extraction (plenty for a progress bar), they just
don't get literally every single point.

## Re-vendoring / upgrading

If you ever bump this dependency, re-apply the two throttle edits (search for
"2026-08-08 patch" in `android/src/.../WaveformExtractor.kt` and
`ios/Classes/WaveformExtractor.swift`) or check if upstream has fixed this —
worth filing an issue/PR at the source repo either way.
