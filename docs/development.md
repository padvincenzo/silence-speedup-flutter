# Development

## Prerequisites

- **Flutter** 3.47 or newer, on the stable channel (Dart 3.13+).
- **Windows**: Visual Studio 2022 with the *Desktop development with C++*
  workload. `flutter doctor` will say if it is missing.
- Network access for the **first** Windows build — the FFmpeg libraries are
  downloaded then.

```bash
flutter doctor -v      # confirm the Windows toolchain is green
```

## Running

```bash
git clone https://github.com/padvincenzo/silence-speedup-flutter
cd silence-speedup-flutter
flutter pub get
flutter run -d windows
```

## Everyday commands

| Command | What it does |
| --- | --- |
| `flutter analyze` | Static analysis. Must be clean before committing. |
| `flutter test` | Unit tests. No encoder or media files needed; runs in seconds. |
| `flutter run -d windows` | Debug run with hot reload. |
| `flutter build windows --release` | Release build into `build/windows/x64/runner/Release/`. |
| `dart format lib test` | Formatting. |

## How FFmpeg gets into the build

`ffmpeg_kit_flutter_new` fetches prebuilt **full-GPL FFmpeg 8.1.2** libraries at
build time and copies them next to the executable. After a release build you
should see them in the output directory:

```
build/windows/x64/runner/Release/
    silence_speedup.exe
    libffmpegkit.dll
    avcodec-62.dll  avformat-62.dll  avfilter-11.dll  avutil-60.dll ...
    libx264-165.dll        ← the GPL encoder every fragment uses
```

If `libx264-*.dll` is absent, the plugin variant is wrong and every export will
fail: the app encodes exclusively with `libx264`.

To build against a locally compiled FFmpeg bundle instead, set
`FFMPEGKIT_LOCAL_DIR` to the bundle directory before running the build.

The first build is slow because of the download. Subsequent builds reuse it;
`flutter clean` throws it away.

## Project layout

```
silence-speedup-flutter/
├── CLAUDE.md            # working rules for AI assistants
├── ROADMAP.md           # what is not built yet
├── analysis_options.yaml
├── assets/
│   ├── icons/           # app icon (shared with the Electron app)
│   └── locales/         # en.json, it.json — flat dotted keys
├── docs/
├── lib/
│   ├── main.dart        # bootstrap: translations → prefs → window → stores
│   ├── app.dart         # MaterialApp, theme, locale
│   ├── l10n/            # Translator + BuildContext extension
│   ├── models/          # options catalogue, settings, queue entry
│   ├── services/        # FFmpeg boundary, planner, engine, paths, updates
│   ├── state/           # the four ChangeNotifier stores
│   └── ui/              # home_page, widgets/, dialogs/
├── test/
├── windows/             # Flutter desktop runner
└── android/             # scaffolded; UI not built yet (see ROADMAP)
```

[architecture.md](architecture.md) explains why the layers are arranged this way.

## Testing

Tests cover the pure core — the FFmpeg argument lists and the range/fragment
geometry — because that is where a mistake produces a *plausible but wrong*
file rather than an error:

- [test/fragment_planner_test.dart](../test/fragment_planner_test.dart) —
  boundary pairing, margin trimming, fragment planning, every argument list,
  concat-list escaping.
- [test/settings_and_update_test.dart](../test/settings_and_update_test.dart) —
  settings serialisation and clamping, the speed catalogue's internal
  consistency, entry naming, version comparison.

When adding a feature that changes what FFmpeg is asked to do, add the assertion
to `fragment_planner_test.dart` in the same commit. It is much cheaper than
noticing the drift in an exported file a week later.

There is no widget or integration test suite yet — see [ROADMAP.md](../ROADMAP.md).

### Manual checks worth doing before a release

The pipeline touches real files, so a few things only a real run will show:

1. A file whose **first** sound starts after a pause (checks the margin on the
   first range).
2. A file that **fades out into silence** (checks the unclosed final boundary).
3. **Silence speed = Remove** (checks that silent fragments are skipped, not
   emitted empty).
4. **Mute silences** on, at 8× (checks A/V stays in sync to the end).
5. **Stop** mid-run (checks the row is marked interrupted and fragments are
   kept).
6. A **format change**, e.g. `.mov` in, MP4 out.
7. A path containing **spaces and an apostrophe** (checks concat-list escaping).
8. Two runs of the same file into the same folder (checks ` (1)` naming).

## Adding to the app

### A new setting

1. Add the field to `ProcessingSettings`, with a default, a `copyWith` entry and
   `toJson` / `fromJson` handling. Clamp it in `fromJson`: a stale preferences
   file must never crash the app.
2. If it changes the FFmpeg call, change `FragmentPlanner` and add a test.
3. Add a `SettingRow` to `SettingsDialog`.
4. Add the label — and the tooltip, if the effect is not obvious — to **both**
   `assets/locales/en.json` and `it.json`.

### A new option in a catalogue

Append to the list in `lib/models/options.dart`. Indexes are persisted, so
**appending is safe but reordering is not** — a reorder silently changes what
existing users have selected. `ProcessingSettings.fromJson` clamps out-of-range
indexes, so shrinking a list is safe.

### A new language

1. Copy `assets/locales/en.json` to `assets/locales/<code>.json` and translate
   the values.
2. Add the locale to `Translator.supportedLocales`.
3. Add a `_LanguageItem` to the View → Language submenu.

Missing keys fall back to English, so a partial translation degrades rather than
breaks.

## Releasing

1. Bump `version:` in `pubspec.yaml`.
2. `flutter analyze && flutter test`.
3. `flutter build windows --release`.
4. Zip `build/windows/x64/runner/Release/` whole — the FFmpeg DLLs beside the
   executable are required.
5. Tag and publish a GitHub release. The in-app update check reads the
   repository's `releases.atom`, so the tag must contain the version number.

Because FFmpeg is bundled under the GPL, releases must keep carrying the GPLv3
notice and offer the corresponding source.

## Contributing

Issues and pull requests: <https://github.com/padvincenzo/silence-speedup-flutter>

Before opening a PR: `flutter analyze` clean, `flutter test` green, and new
FFmpeg behaviour covered by a test. Read [porting-notes.md](porting-notes.md)
first if the change touches the pipeline — several apparent oddities are
deliberate fixes to the Electron version.
