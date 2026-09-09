// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/foundation.dart';

import '../l10n/translator.dart';
import '../models/media_entry.dart';
import '../services/app_paths.dart';
import '../services/ffmpeg_runner.dart';
import '../services/speedup_engine.dart';
import 'log_store.dart';
import 'preferences_store.dart';
import 'queue_store.dart';

/// Drives a run and exposes its progress to the UI.
///
/// Owns the [SpeedupEngine] and is the only thing that locks the queue, so the
/// UI never has to reason about who is allowed to change what.
class ProcessStore extends ChangeNotifier {
  ProcessStore({
    required FFmpegRunner runner,
    required QueueStore queue,
    required PreferencesStore preferences,
    required LogStore log,
    required Translator translator,
  }) : _queue = queue,
       _preferences = preferences,
       _log = log,
       _t = translator {
    _engine = SpeedupEngine(
      runner: runner,
      log: log,
      translator: translator,
      onProgress: _handleProgress,
    );
  }

  final QueueStore _queue;
  final PreferencesStore _preferences;
  final LogStore _log;
  final Translator _t;

  late final SpeedupEngine _engine;

  bool _running = false;
  bool _compactMode = false;
  RunProgress _progress = const RunProgress();

  bool get isRunning => _running;

  /// True while the window is shrunk to the slim progress strip.
  bool get compactMode => _compactMode;

  RunProgress get progress => _progress;

  bool get canStart => !_running && _queue.hasProcessableEntries;

  /// Processes the whole queue.
  Future<void> start() => _run(_queue.processableEntries, detectOnly: false);

  /// Measures the silences of one file without encoding anything, so detection
  /// settings can be judged before committing to a full run.
  Future<void> analyze(MediaEntry entry) =>
      _run(<MediaEntry>[entry], detectOnly: true);

  Future<void> stop() async {
    if (!_running) return;
    await _engine.stop();
    _engine.markInterrupted();
  }

  void setCompactMode(bool compact) {
    if (_compactMode == compact) return;
    _compactMode = compact;
    notifyListeners();
  }

  Future<void> _run(
    List<MediaEntry> entries, {
    required bool detectOnly,
  }) async {
    if (_running) {
      _log.warning(_t.t('ffmpeg.alreadyRunning'));
      return;
    }
    if (entries.isEmpty) {
      _log.warning(_t.t('log.queueEmpty'));
      return;
    }

    final String directory = _preferences.outputDirectory;
    if (!await AppPaths.ensureDirectory(directory)) {
      _log.error(
        _t.t('log.outputDirError', <String, Object?>{
          'path': directory,
          'error': '',
        }),
      );
      return;
    }

    _running = true;
    _queue.setLocked(true);
    notifyListeners();

    try {
      await _engine.run(
        entries: entries,
        settings: _preferences.settings,
        outputDirectory: directory,
        detectOnly: detectOnly,
      );
    } finally {
      _running = false;
      _queue.setLocked(false);
      _compactMode = false;
      notifyListeners();
    }
  }

  void _handleProgress(RunProgress progress) {
    _progress = progress;
    notifyListeners();
  }
}
