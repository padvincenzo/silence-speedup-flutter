# Architecture

How the app is put together, and why it is put together that way.

---

## The shape of the problem

The app has one job: given a media file and some settings, produce a shorter
copy of it. Everything hard about that job lives in FFmpeg. What the app
contributes is:

1. Deciding **where** the silences are.
2. Deciding **what rate** each stretch should play at.
3. Building the FFmpeg invocations that realise those decisions.
4. Sequencing dozens of invocations while showing honest progress and staying
   interruptible.

Steps 1–3 are pure computation over numbers and strings. Step 4 is all I/O,
timing and cancellation. The codebase is split along exactly that seam, because
step 3 is where mistakes are expensive and invisible — a wrong flag yields a
file that plays but drifts out of sync — and pure code is the only kind you can
cheaply assert against.

---

## Layers

```
        ┌─────────────────────────────────────────────┐
  UI    │  home_page · widgets/ · dialogs/            │
        │  reads stores, calls stores, renders        │
        └───────────────────┬─────────────────────────┘
                            │ provider
        ┌───────────────────┴─────────────────────────┐
 State  │  PreferencesStore  QueueStore               │
        │  ProcessStore      LogStore                 │
        └───────────────────┬─────────────────────────┘
                            │
        ┌───────────────────┴─────────────────────────┐
Service │  SpeedupEngine ──── sequencing, progress    │
        │       │                                     │
        │       ├── FragmentPlanner  (pure)           │
        │       └── FFmpegRunner     (interface)      │
        └───────────────────┬─────────────────────────┘
                            │
        ┌───────────────────┴─────────────────────────┐
Platform│  FFmpegKitRunner → ffmpeg_kit_flutter_new   │
        │  AppPaths        → filesystem locations     │
        └─────────────────────────────────────────────┘
```

Dependencies point downward only. A widget never imports a platform package;
the engine never imports a widget.

---

## The FFmpeg boundary

`FFmpegRunner` ([lib/services/ffmpeg_runner.dart](../lib/services/ffmpeg_runner.dart))
is the app's entire dependency on FFmpeg, expressed as three operations:

```dart
abstract class FFmpegRunner {
  Future<Duration?> probeDuration(String path);
  Future<FFmpegResult> run(List<String> arguments, {onLine, onProgress});
  Future<void> cancel();
}
```

`FFmpegKitRunner` implements it over `ffmpeg_kit_flutter_new`. **Nothing else in
the app imports that package.** Two things follow:

- **The Android port is a UI-and-storage problem, not an encoding problem.** The
  plugin already runs on Android, iOS, macOS, Windows and Linux behind one
  API, so the engine, the planner and the models are already portable. What
  needs replacing is the desktop chrome (menu bar, drag-and-drop, resizable
  window) and `AppPaths`, since an Android app cannot write to an arbitrary
  folder in the user's home.
- **A fake runner can drive the whole engine** without an encoder present.

### Why bundled, not a system binary

The Electron app asked the user to point a preference at `ffmpeg.exe`, and
refused to work until they did. That is a support burden and a bad first run.
The plugin ships a full-GPL FFmpeg build (which is what provides `libx264`), so
there is no path to configure and no binary in `assets/`. Windows libraries are
fetched at build time; see [development.md](development.md).

### Log parsing

FFmpeg's log callback fires once per `av_log` write, which is **not** reliably
one line. `FFmpegKitRunner` buffers partial output and only hands complete lines
to `onLine`, so the `silence_start` / `silence_end` regex never sees half a
number. The remainder is flushed when the session ends.

---

## The pure core: FragmentPlanner

[lib/services/fragment_planner.dart](../lib/services/fragment_planner.dart)
holds every FFmpeg argument list the app runs, plus the two pieces of geometry
that decide what gets encoded:

| Function | Responsibility |
| --- | --- |
| `detectArguments` | The `silencedetect` pass |
| `buildRanges` | Pair up detected boundaries, apply the margin |
| `plan` | Walk the timeline into alternating fragments |
| `exportArguments` | Encode one fragment at its rate |
| `concatArguments` | Join the fragments without re-encoding |
| `concatListEntry` | One line of the concat list file, correctly escaped |

No I/O, no `BuildContext`, no clock. All of it is asserted in
[test/fragment_planner_test.dart](../test/fragment_planner_test.dart).

### The concat invariant

Fragments are joined with `-c:a copy -c:v copy` — no re-encoding, which is what
makes the join fast. The price is that **every fragment must be
interchangeable**: same codecs, same container, same frame rate. That is why:

- `-c:v libx264 -c:a aac` are fixed rather than user-selectable;
- the `fps` filter is applied to *every* fragment, sped-up or not;
- `-vsync cfr` is on every fragment;
- fragments use the *output* container's extension, not the input's.

Break any of those and the concat step either fails or produces a file whose
audio drifts. If you need a genuinely different encode per fragment, the concat
step has to become a re-encode, which is a much bigger change.

---

## The sequencer: SpeedupEngine

[lib/services/speedup_engine.dart](../lib/services/speedup_engine.dart) owns
what the planner deliberately does not: order, progress, the filesystem, and
stopping.

Per entry:

```
probe duration ─→ detect silences ─→ plan ─→ encode each fragment ─→ concat
                        │                                              │
                   no silences?                                   output path
                   mark done, next                             resolved to a free name
```

### Progress is corrected for playback rate

FFmpeg reports the position it has reached in the **output** stream. A 10-second
silence encoded at 8x produces 1.25 seconds of output, so taking that number at
face value makes the bar crawl. The engine scales it back by the fragment's rate:

```dart
sourceSeconds = fragment.start + outputSeconds * speed.factor;
```

which is why `SpeedOption` carries a numeric `factor` alongside its label, and
why a test asserts that the two agree for every option.

### Stopping

`stop()` sets a flag *and* cancels the running FFmpeg session. Every loop in the
engine checks the flag between steps, and every `run` result is inspected for
`cancelled`. Without both, a stop would either be ignored until the current
fragment finished or would be reported as a failure.

### Scratch space

Each entry gets its own directory under `<export>/tmp/run_<microseconds>/`.
Per-run isolation means a leftover from an interrupted run, or from an older
version of the app, cannot end up in this concatenation. The directory is
deleted after a successful run and **kept after a failure**, since the fragments
are the only evidence of what went wrong; the log says where they are.

---

## State

Four `ChangeNotifier` stores, constructed in
[lib/main.dart](../lib/main.dart) and exposed with `provider`:

| Store | Owns |
| --- | --- |
| `PreferencesStore` | Export directory, theme, language, processing settings — everything persisted |
| `QueueStore` | The list of files, their probe results, whether importing is allowed |
| `ProcessStore` | Whether a run is active, its progress, compact-window mode |
| `LogStore` | The log lines behind the terminal button |

`ProcessStore` is the only thing that starts a run and the only thing that locks
the queue. Widgets ask it questions (`canStart`, `isRunning`) rather than
working out for themselves whether an action is currently legal.

`MediaEntry` is *also* a `ChangeNotifier`, provided per row. A row rebuilds when
its own entry changes, so a status update during a long run does not rebuild the
whole list.

---

## Localization

A plain `ChangeNotifier` (`Translator`) holding a flat `Map<String, String>`,
loaded from `assets/locales/<code>.json` before the first frame.

It is deliberately **not** a `LocalizationsDelegate`. The engine logs localized
messages from deep inside async work where there is no `BuildContext`; it holds a
`Translator` directly. Flutter's own delegates are still registered, for the
strings Material widgets provide themselves.

Two entry points, and the distinction matters:

- `context.t(key)` — subscribes the widget to language changes. `build` only.
- `context.translator.t(key)` — does not subscribe. For callbacks and async code.

---

## Single window, two modes

Flutter desktop runs one window, where Electron opened several. The compact
progress bar — a slim always-on-top strip — is therefore a *mode* of the main
window rather than a second window: `ProcessStore.compactMode` flips the widget
tree, and `HomePage` reconciles the OS window (size, resizability, always-on-top)
to match in a post-frame callback, restoring the previous size on the way back.

About, Preferences, Settings, Licence and Update were separate `BrowserWindow`s
in Electron and are dialogs here. Nothing was lost: they were all modal in
practice.
