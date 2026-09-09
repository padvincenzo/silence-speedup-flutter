# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this project is

**Silence SpeedUp** is a desktop app that shortens videos by detecting silent
stretches and either speeding them up or cutting them out. FFmpeg does the
work; this app decides *what* to ask FFmpeg for.

This repository is the **Flutter rewrite** of
[padvincenzo/silence-speedup](https://github.com/padvincenzo/silence-speedup),
an Electron app. The Electron version is still the released one; treat it as
the reference for intended behaviour, not as code to imitate.

Primary target is **Windows**. Android is a deliberate future target and the
architecture is arranged for it — see [docs/architecture.md](docs/architecture.md).

## Commands

```bash
flutter pub get                     # after touching pubspec.yaml
flutter analyze                     # must be clean before committing
flutter test                        # unit tests, no encoder needed
flutter run -d windows              # debug run
flutter build windows --release     # release build
```

The first Windows build downloads prebuilt FFmpeg libraries; it is slow and
needs network. Later builds reuse them.

## Rules that matter here

### FFmpeg is bundled, never configured

FFmpeg comes from the `ffmpeg_kit_flutter_new` plugin (full-GPL, includes
`libx264`). **Do not** add a preference for an FFmpeg path, shell out to a
system `ffmpeg`, or ship a binary in `assets/`. The Electron app asked the user
to locate `ffmpeg.exe`; removing that was a deliberate product decision.

Everything that touches an encoder goes through the `FFmpegRunner` interface in
[lib/services/ffmpeg_runner.dart](lib/services/ffmpeg_runner.dart). Nothing else
in the app may import `ffmpeg_kit_flutter_new`.

### FFmpeg argument lists belong in FragmentPlanner

[lib/services/fragment_planner.dart](lib/services/fragment_planner.dart) is pure:
no I/O, no `BuildContext`, no progress plumbing. Every argument list the app
runs is built there and asserted in
[test/fragment_planner_test.dart](test/fragment_planner_test.dart).

If you change how a fragment is encoded, change it there and add a test. A wrong
flag here produces a file that is subtly desynced rather than an error, so tests
are the only cheap way to catch it.

Two invariants that are easy to break:

- **Fragments must stay concat-compatible.** They are joined with `-c copy`, so
  every fragment needs the same codecs, container and frame rate. That is why
  `-vsync cfr` and the `fps` filter are on every fragment.
- **Muting keeps `atempo`.** When silences are muted, `volume=0` is *appended*
  to the tempo chain, not substituted for it. Dropping `atempo` leaves the audio
  longer than the sped-up video and desyncs everything downstream.

### Strings are translated, always

UI text comes from `assets/locales/en.json` and `it.json`, flat dotted keys with
`{{placeholder}}` interpolation — the format the Electron app fed to i18next, so
translation work carries across.

- In `build`, use `context.t('some.key')` from
  [lib/l10n/translator_context.dart](lib/l10n/translator_context.dart) — it
  subscribes the widget to language changes.
- In callbacks and async code, use `context.translator.t(...)`; `context.t`
  watches and will throw outside `build`.
- Services take a `Translator` in their constructor. Never hardcode English.
- **Add every new key to both catalogues.** A missing key falls back to English
  and then renders as the raw key.

### State lives in four stores

`PreferencesStore`, `QueueStore`, `ProcessStore`, `LogStore` — all
`ChangeNotifier`, wired up in [lib/main.dart](lib/main.dart) and read with
`provider`. `ProcessStore` is the only thing that starts a run and the only
thing that locks the queue; widgets never reason about who may change what.

### Code style

- Explicit types on locals, fields and collection literals. The codebase reads
  `final List<String> paths = <String>[]`, not `var paths = []`. Match it.
- Comments explain *why*, and are worth writing where a reader would otherwise
  wonder. Do not narrate what the next line does.
- `flutter analyze` clean, no new `// ignore:`. `prefer_initializing_formals` is
  off project-wide with a reason stated in `analysis_options.yaml`.

## Where things are

```
lib/
├── main.dart               # bootstrap: translations, prefs, window, stores
├── app.dart                # MaterialApp, theme, locale
├── l10n/                   # JSON translation loader + BuildContext extension
├── models/
│   ├── options.dart        # option catalogues (was config.json)
│   ├── processing_settings.dart
│   └── media_entry.dart
├── services/
│   ├── ffmpeg_runner.dart  # the only door to FFmpeg
│   ├── fragment_planner.dart  # pure argument construction
│   ├── speedup_engine.dart # sequencing, progress, I/O
│   ├── app_paths.dart      # the part Android will have to change
│   └── update_checker.dart
├── state/                  # the four stores
└── ui/                     # home_page, widgets/, dialogs/
```

## Deliberate differences from the Electron app

These are fixes, not oversights. Do not "restore" them; see
[docs/porting-notes.md](docs/porting-notes.md) for the full list with reasoning.

- The silence margin applies to **every** detected range. The original skipped
  the first boundary of each list.
- Muting a silence chains `volume=0` onto `atempo` instead of replacing it.
- Output files never overwrite: a name collision gets ` (1)` appended.
- Temporary fragments are deleted after a successful run, kept after a failure.
- Version comparison is per-component, not "strip the dots and parse".

## Not implemented yet

The demo player — the Electron app's video.js preview that plays a file with the
silences sped up live — is not ported. It is the main open item in
[ROADMAP.md](ROADMAP.md). Do not start it without asking; it pulls in a video
playback stack.
