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
flutter gen-l10n                    # after editing lib/l10n/arb/*.arb
flutter analyze                     # must be clean before committing
flutter test                        # unit tests, no encoder needed
flutter run -d windows              # debug run
flutter build windows --release     # release build
```

```powershell
.\installer\build-installer.ps1     # release build + Inno Setup package into dist\
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
[test/fragment_planner_test.dart](test/fragment_planner_test.dart) and
[test/preview_and_audio_test.dart](test/preview_and_audio_test.dart).

If you change how a fragment is encoded, change it there and add a test. A wrong
flag here produces a file that is subtly desynced rather than an error, so tests
are the only cheap way to catch it.

Four invariants that are easy to break:

- **Fragments must stay concat-compatible.** They are joined with `-c copy`, so
  every fragment needs the same codecs, container and frame rate. That is why
  `-vsync cfr` and the `fps` filter are on every fragment.
- **Muting keeps `atempo`.** When silences are muted, `volume=0` is *appended*
  to the tempo chain, not substituted for it. Dropping `atempo` leaves the audio
  longer than the sped-up video and desyncs everything downstream.
- **Stream mapping is explicit.** Fragments map `0:v:0?` plus either `0:a?`
  (all tracks) or `0:a:0?`, and the concat step maps `0`. Leave those out and
  FFmpeg's default selection silently keeps one audio track and drops the rest.
- **Detection always reads `0:a:0`.** Even when every track is exported, the
  pauses come from the first track — the voice track in a multi-track recording.

### Positions are absolute source seconds

`Fragment` and `SilenceRange` are in seconds from the start of the source file,
never relative to anything. A preview processes a `TimeWindow` rather than the
whole file, and `silencedetect` reports relative to its own seek, so
`buildRanges` adds the window's start back. Keep that conversion in one place.

### The version is bumped on every build

`version:` in [pubspec.yaml](pubspec.yaml) is the one place the version is
stated, and it is a plain `x.y.z` — **no `+build` suffix**. It ends up verbatim
in the executable's `FileVersion`, and `0.9.0+1` there reads like a leftover.

**Raise the patch number before every build that gets packaged or installed.**
Two builds must never carry the same version: the installer names its output
after it, the in-app update check compares against it, and a bug report that
says 0.9.4 has to mean one specific binary. A plain `x.y.z` also becomes the
`x.y.z.0` an MSIX package needs, which is the other reason there is no `+`.

### A Store build is not allowed to update itself

The app is heading for the Microsoft Store as well as GitHub, from this same
source. `kStoreBuild` in [lib/build_config.dart](lib/build_config.dart) —
set with `--dart-define=STORE_BUILD=true` — switches the update check off,
because a Store app must not look for its own updates or point anyone at an
executable to download. Anything new that fetches or launches code has to
respect the same flag. Links to pages are fine.

The packaging itself is not wired up yet; what exists and what is still
missing is in [docs/microsoft-store.md](docs/microsoft-store.md).

### Strings come from ARB, always

UI and log text is generated from `lib/l10n/arb/app_en.arb` (the template) and
`app_it.arb` by `flutter gen-l10n`, configured in [l10n.yaml](l10n.yaml).

- In widgets: `AppLocalizations.of(context).someKey`.
- In services and stores: they hold a `LocaleController` and read
  `_locales.strings.someKey`, which needs no `BuildContext`.
- Model enums are turned into text only in [lib/l10n/labels.dart](lib/l10n/labels.dart),
  so `models/` never imports the generated class.
- **Add every new message to both catalogues, then run `flutter gen-l10n`.** A
  test asserts the two key sets match, so a missing translation fails the suite
  rather than silently falling back to English.
- Use ARB placeholders and plurals rather than string concatenation. Numbers
  declared as `double` with `decimalPatternDigits` get a locale-correct decimal
  separator, which matters: Italian writes `12,50`, not `12.50`.
- The generated files in `lib/l10n/gen/` are committed so a fresh clone
  analyses without a codegen step. Regenerate them in the same commit as an ARB
  change; never hand-edit them.

### Language follows the system

[lib/l10n/locale_controller.dart](lib/l10n/locale_controller.dart) resolves the
first system language the app supports and falls back to English. A user can
pin one from App settings → Application, and "System" puts it back. `resolve`
takes an optional `systemLocales` so the order can be tested.

### The UI is Material, not a ported menu bar

`AppShell` is the frame: an `AppBar`, a `NavigationDrawer`, and one of three
pages (`lib/ui/pages/`). There is deliberately **no** `MenuBar` — do not
reintroduce one, and do not add a "File" or "View" menu. New actions go where
they belong:

- something you do to the queue → a button on the queue page, or an app bar
  action;
- the one primary action of a screen → the floating action button;
- a setting that changes how a video is encoded → a tile in the right group of
  `EncodingSettingsView`, **with a description**, and an entry in that group's
  summary in [lib/l10n/labels.dart](lib/l10n/labels.dart);
- a setting about the application itself → a tile on `AppSettingsPage`, again
  with a description, since both surfaces explain themselves in place;
- something application-level → the drawer.

### Encoding settings are a panel, application settings are a page

The two were one page once, and that made the settings people change between
runs as far away as the ones they set on the first day. They are separate now:

- `EncodingSettingsView` (`lib/ui/widgets/`) holds speed, audio, detection,
  export and preview, plus the reset that puts them back. It is shown docked
  to the right of the queue when the window is at least
  `kEncodingPanelBreakpoint` wide, and as an end-drawer side sheet when it is
  not. The app bar's button and Ctrl+, reach it; the sheet closes on Escape,
  the scrim, or its own button.
- **The groups collapse, and a closed one shows only what differs from the
  default.** The summaries are the `*Changes` functions in
  [labels.dart](lib/l10n/labels.dart), each comparing against
  `const ProcessingSettings()` — never against a written-out copy of the
  defaults, which would go stale. A setting with no entry there is invisible
  once its group is closed, so adding one is part of adding a setting. Which
  groups are open is remembered in `PreferencesStore`; only the speeds start
  open.
- **The rates live on the button that opens the panel, and nowhere else.**
  They were also a chip on the queue, which meant two controls doing one job.
  Do not add a second indicator: if the app bar button needs to say more, say
  it there.
- Docking is remembered in `PreferencesStore.encodingPanelDocked`, so leaving
  the panel open is a durable choice rather than per-session state.
- `AppSettingsPage` (`lib/ui/pages/`) holds the theme, the language and the
  working directory, and is a drawer destination.

Neither one navigates away from the queue, which is the point: the list stays
where it is, and the settings arrive beside it.

Three layout constraints that are easy to undo:

- The queue's status strip is the Scaffold's `bottomNavigationBar`, not the last
  row of the page. That is what keeps the floating action button off the
  percentage readout, together with `kQueueBottomInset` on the list.
- With the panel docked, the floating action button is moved inwards by
  `_ShiftedFabLocation` so it floats over the queue and not over a setting.
- Every settings surface has to fit 640x480, the smallest window the app
  allows, and the encoding tiles also have to fit `kEncodingPanelWidth`. Tests
  assert both; that is why `DropdownSettingTile` puts its field under the label
  when it runs out of room.

`test/ui_smoke_test.dart` builds the shell and each page against a
`FakeFFmpegRunner` and fails on an overflow. Run it after touching the UI; it
is the only thing watching the layout.

### State lives in four stores

`PreferencesStore`, `QueueStore`, `ProcessStore`, `LogStore` — all
`ChangeNotifier`, wired up in [lib/main.dart](lib/main.dart) and read with
`provider`. `ProcessStore` is the only thing that starts a run and the only
thing that locks the queue; widgets never reason about who may change what.

### Output and scratch space are separate

The export folder can follow each source file, so there is no single output
directory. `PreferencesStore.outputDirectoryFor(entry)` answers per entry, and
the engine takes that resolver rather than a path. Intermediate fragments go to
`PreferencesStore.workingDirectory` (system temp by default), never under the
export folder.

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
├── main.dart               # bootstrap: prefs → locale → window → stores
├── app.dart                # MaterialApp, theme, locale
├── l10n/
│   ├── arb/                # app_en.arb (template), app_it.arb
│   ├── gen/                # generated, committed, never hand-edited
│   ├── locale_controller.dart
│   └── labels.dart         # enum → text, the only bridge from models/
├── models/
│   ├── options.dart        # option catalogues (was config.json)
│   ├── processing_settings.dart
│   ├── media_entry.dart
│   └── time_window.dart
├── services/
│   ├── ffmpeg_runner.dart     # the only door to FFmpeg
│   ├── fragment_planner.dart  # pure argument construction
│   ├── speedup_engine.dart    # sequencing, progress, I/O
│   ├── app_paths.dart         # the part Android will have to change
│   └── update_checker.dart
├── state/                  # the four stores
└── ui/
    ├── app_shell.dart      # app bar, drawer, encoding panel, destinations
    ├── theme.dart          # one ThemeData for both brightnesses
    ├── pages/              # queue, app settings, about
    └── widgets/            # incl. the encoding settings view and panel
installer/                  # Inno Setup script + build script
```

## Deliberate differences from the Electron app

These are fixes, not oversights. Do not "restore" them; see
[docs/porting-notes.md](docs/porting-notes.md) for the full list with reasoning.

- The silence margin applies to **every** detected range. The original skipped
  the first boundary of each list.
- Muting a silence chains `volume=0` onto `atempo` instead of replacing it.
- Every audio track can be carried through; the original always kept one.
- Output files never overwrite: a name collision gets ` (1)` appended. This
  matters more now that the export folder can be the source folder.
- Temporary fragments live outside the export folder, are per-run, and are
  deleted after a successful run.
- Version comparison is per-component, not "strip the dots and parse".

## Not implemented yet

The demo player — a live preview that *plays* a file with the silences sped up
as you watch — is not ported. The per-file preview action is a different thing:
it encodes a short sample through the real pipeline. The live player is the main
open item in [ROADMAP.md](ROADMAP.md); do not start it without asking, as it
pulls in a video playback stack.
