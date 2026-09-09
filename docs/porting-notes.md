# Porting notes

What changed moving from the Electron app to Flutter, and why. Read this before
"restoring" something to match the original — several of the differences are
deliberate bug fixes.

The reference is [padvincenzo/silence-speedup](https://github.com/padvincenzo/silence-speedup)
at v2.0.0.

---

## Behaviour changes (fixes)

### The silence margin now applies to every range

The original's `Entry.appendTS` skipped the adjustment for the first element of
each boundary list:

```js
appendTS(i, ts, offset) {
    let len = this.#silenceTS[i].push(ts);
    if (len > 1) {                      // ← first boundary never adjusted
        offset = parseFloat(offset) * ((i == "start") ? 1 : -1);
        this.#silenceTS[i][len - 1] = (parseFloat(ts) + offset).toFixed(7);
    }
}
```

Since `starts[0]` and `ends[0]` belong to the *same* silence, the first silence
in every file was left a margin too wide at both ends — the one case where
clipped speech is most noticeable, at the first pause.

The port applies the margin uniformly and clamps the result to the bounds of the
media. Covered by `buildRanges trims every range by the margin, including the
first`.

### Muting a silence no longer desyncs the audio

The original replaced the tempo filter with `volume=enable=0`:

```js
"-af", SpeedUp.muteAudio ? "volume=enable=0" : speeds[i].audio
```

Two problems. `enable` is a timeline option and `enable=0` disables the filter
entirely, so nothing was muted. And losing `atempo` left the audio at full
length while the video was compressed, which — with fragments joined by stream
copy — pushed everything after that fragment out of sync.

The port appends `volume=0` to the tempo chain instead. Covered by `muting keeps
the tempo filter so audio and video stay the same length`.

### Output files are never overwritten

The original passed `-y` and wrote straight over any existing file. With the
format set to **Keep** and an export directory that happened to be the source
folder, it overwrote the original with its own sped-up version — unrecoverable.

The port appends ` (1)`, ` (2)` … to avoid a collision, and refuses to write to
the source path.

### A silence running to the end of the file no longer fails

The original required `starts.length == ends.length` and reported "indexes do
not match" otherwise. A file fading out into silence can produce a final
`silence_start` with no close, which failed the whole file. The port closes it at
the end of the media, and only reports an error for mismatches it cannot repair.

### Temporary files are cleaned up

The original shared one `tmp` directory across all runs and never emptied it —
its own docs said "these are *not* auto-deleted". Two runs interrupted at the
wrong moment could mix fragments.

The port gives each entry its own `run_<microseconds>` directory, deletes it on
success, and keeps it on failure with the path in the log. Preferences shows the
scratch size and can empty it.

### Version comparison actually compares versions

The original stripped the dots and parsed the rest as one integer:

```js
parseInt(version.replace(/v|\./g, ""))    // "2.1.0" → 210, "2.0.10" → 2010
```

which makes 2.0.10 look newer than 2.1.0. The port compares component by
component. Covered by `compares component by component, not as one number`.

### Progress reflects the playback rate

FFmpeg reports the position it reached in the **output**. A 10-second silence at
8× yields 1.25 seconds of output, so the original's bar advanced eight times too
slowly through silences. The port scales the reported position by the fragment's
rate, which is why `SpeedOption` carries a numeric `factor`.

---

## Removed

### The FFmpeg path preference

The original required the user to locate `ffmpeg.exe` and refused to work until
they did. FFmpeg is now bundled by `ffmpeg_kit_flutter_new`, so the preference,
its file picker, its validation and the "please configure FFmpeg" warning are
all gone. This was the explicit goal of the rewrite.

### `config.json`

The original copied `config.json.example` next to the executable and read the
option catalogues from it at startup. Those catalogues describe what the app can
do, not what the user chose, so they are now Dart constants in
[lib/models/options.dart](../lib/models/options.dart) — one less file to ship,
one less way for a hand-edit to break the app.

User choices moved the other way: they are now **persisted** (see below).

### Electron-specific menu items

`Restart`, `Toggle Dev Tools` and the Electron reference link have no Flutter
equivalent and are gone.

---

## Added

- **Settings persist.** The original reset every slider to `config.json`'s
  initial values on each launch. A batch run can now be repeated tomorrow
  without redialling everything. Out-of-range persisted values fall back to
  defaults rather than crashing.
- **System theme.** Light and dark were the only options; the theme now also
  follows the OS.
- **Analyse without exporting.** Per-row action that runs only the detection
  pass and reports the percentage of silence found — the cheap way to judge
  detection settings before committing to a full encode. It replaces the
  original's *demo* button, whose player is not yet ported
  ([ROADMAP.md](../ROADMAP.md)).
- **Show the exported file.** Opens the output folder for a finished row.
- **The detection filter is visible.** Settings shows the composed
  `silencedetect` string, making the margin widening explicit.
- **Tooltips** on the settings whose effect is not obvious from the label.
- **Clear the scratch directory** from Preferences, with its current size.
- **Tests.** The original had none ("no automated test suite is available").
  Argument construction and range geometry are now asserted.

---

## Structural mapping

| Electron | Flutter |
| --- | --- |
| `main.js` (window + menu + IPC) | `lib/main.dart`, `lib/app.dart`, `lib/ui/widgets/app_menu_bar.dart` |
| `src/classes/config.js` + `config.json` | `lib/models/options.dart`, `lib/state/preferences_store.dart` |
| `src/classes/entry.js` (model **and** DOM row) | `lib/models/media_entry.dart` + `lib/ui/widgets/entry_list.dart` |
| `src/classes/entrylist.js` | `lib/state/queue_store.dart` |
| `src/classes/ffmpeg.js` (spawn + progress + DOM) | `lib/services/ffmpeg_runner.dart` + `lib/ui/widgets/progress_footer.dart` |
| `src/classes/speedup.js` (pipeline + arguments) | `lib/services/speedup_engine.dart` + `lib/services/fragment_planner.dart` |
| `src/classes/interface.js` | `lib/ui/home_page.dart` + `lib/ui/widgets/` |
| `src/classes/shell.js` | `lib/state/log_store.dart` + `lib/ui/widgets/log_console.dart` |
| `src/i18n.js` + `locales/*/translation.json` | `lib/l10n/translator.dart` + `assets/locales/*.json` |
| `renderer/preferences`, `about`, `update` windows | `lib/ui/dialogs/` |
| `renderer/progress` window | `lib/ui/widgets/compact_progress_view.dart` |
| `renderer/player` (video.js) | not ported — [ROADMAP.md](../ROADMAP.md) |

The most substantial restructuring is `entry.js` and `ffmpeg.js`: both mixed
model state with direct DOM manipulation, building `<button>` elements and
writing `innerHTML` from inside what was nominally the data layer. Splitting
them is what made the pipeline testable.

---

## Platform differences to be aware of

- **One window.** Electron opened separate windows for progress, about,
  preferences, licence and update. Flutter desktop has one, so the progress
  strip is a mode of the main window and the rest are dialogs.
- **The menu bar is drawn in-app.** Flutter's `MenuBar` is a widget, not native
  window chrome. One implementation covers Windows, Linux and macOS; the
  trade-off is that it does not appear in the macOS system menu bar.
- **Keyboard shortcuts are registered separately.** `MenuItemButton.shortcut`
  only *displays* an accelerator; the bindings live in a `CallbackShortcuts` in
  `HomePage`. Adding a shortcut means touching both places.
- **No taskbar progress or completion notification.** The original set the
  Windows taskbar progress and raised a notification when a batch finished.
  Both are listed in [ROADMAP.md](../ROADMAP.md).
