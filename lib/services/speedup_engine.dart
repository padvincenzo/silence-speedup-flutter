// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../l10n/translator.dart';
import '../models/media_entry.dart';
import '../models/options.dart';
import '../models/processing_settings.dart';
import '../state/log_store.dart';
import 'ffmpeg_runner.dart';
import 'fragment_planner.dart';

/// Where the run is, for the progress bar and the compact window.
@immutable
class RunProgress {
  const RunProgress({
    this.entryName = '',
    this.completed = 0,
    this.total = 0,
    this.position,
    this.speed,
    this.fraction,
  });

  /// File being worked on.
  final String entryName;

  /// Files finished so far, and how many there are in total.
  final int completed;
  final int total;

  /// Position reached inside the current file.
  final Duration? position;

  /// Encoding rate FFmpeg last reported.
  final double? speed;

  /// Progress through the current file, 0..1, or null when not yet known.
  final double? fraction;

  /// Progress across the whole queue, 0..1.
  double get queueFraction {
    if (total == 0) return 0;
    return ((completed + (fraction ?? 0)) / total).clamp(0.0, 1.0);
  }
}

/// Turns a queue of files into shortened copies of themselves.
///
/// The pipeline keeps the Electron app's shape: find the silences with
/// `silencedetect`, re-encode each stretch at its own rate, then stitch the
/// pieces back together with the concat demuxer. The arguments themselves come
/// from [FragmentPlanner]; what lives here is sequencing, progress and I/O.
class SpeedupEngine {
  SpeedupEngine({
    required FFmpegRunner runner,
    required LogStore log,
    required Translator translator,
    required void Function(RunProgress progress) onProgress,
  }) : _runner = runner,
       _log = log,
       _t = translator,
       _onProgress = onProgress;

  final FFmpegRunner _runner;
  final LogStore _log;
  final Translator _t;
  final void Function(RunProgress progress) _onProgress;

  bool _stopRequested = false;
  MediaEntry? _current;

  bool get isStopping => _stopRequested;

  /// Asks the run to wind down and kills the FFmpeg process behind it.
  Future<void> stop() async {
    if (_stopRequested) return;
    _stopRequested = true;
    _log.error(_t.t('log.stopping'));
    await _runner.cancel();
  }

  /// Processes [entries] in order.
  ///
  /// With [detectOnly] set, silences are measured and reported but nothing is
  /// encoded — the cheap way to judge the detection settings before committing
  /// to a full run.
  Future<void> run({
    required List<MediaEntry> entries,
    required ProcessingSettings settings,
    required String outputDirectory,
    bool detectOnly = false,
  }) async {
    _stopRequested = false;

    if (entries.isEmpty) {
      _log.warning(_t.t('log.queueEmpty'));
      return;
    }

    final Directory workRoot = Directory(p.join(outputDirectory, 'tmp'));
    try {
      await Directory(outputDirectory).create(recursive: true);
      await workRoot.create(recursive: true);
    } on FileSystemException catch (error) {
      _log.error(
        _t.t('log.outputDirError', <String, Object?>{
          'path': outputDirectory,
          'error': error.osError?.message ?? error.message,
        }),
      );
      return;
    }

    final int total = entries.length;
    for (final MediaEntry entry in entries) {
      entry.prepare();
    }

    for (int index = 0; index < total && !_stopRequested; index++) {
      final MediaEntry entry = entries[index];
      _current = entry;
      _emit(entry: entry, completed: index, total: total);

      await _processEntry(
        entry: entry,
        settings: settings,
        outputDirectory: outputDirectory,
        workRoot: workRoot,
        detectOnly: detectOnly,
        completed: index,
        total: total,
      );

      _current = null;
    }

    if (_stopRequested) {
      _emit(completed: 0, total: total);
      return;
    }

    _onProgress(RunProgress(completed: total, total: total, fraction: 0));
    _log.success(_t.t('log.allDone'));
  }

  Future<void> _processEntry({
    required MediaEntry entry,
    required ProcessingSettings settings,
    required String outputDirectory,
    required Directory workRoot,
    required bool detectOnly,
    required int completed,
    required int total,
  }) async {
    _log.info(_t.t('log.started', <String, Object?>{'name': entry.name}));

    if (!await File(entry.path).exists()) {
      _fail(
        entry,
        _t.t('log.fileMissing', <String, Object?>{'name': entry.name}),
      );
      return;
    }

    entry.duration ??= await _runner.probeDuration(entry.path);
    if (!entry.isProcessable) {
      _fail(
        entry,
        _t.t('ffmpeg.silencedetectError', <String, Object?>{
          'name': entry.name,
        }),
      );
      return;
    }

    final bool analysed = await _detectSilences(
      entry: entry,
      settings: settings,
      completed: completed,
      total: total,
    );
    if (!analysed || _stopRequested) return;

    if (!entry.hasSilences) {
      _log.info(_t.t('log.noSilenceDetected'));
      entry.setStatus(EntryStatus.completed);
      return;
    }

    if (detectOnly) {
      entry.setStatus(EntryStatus.completed, detail: _percentageLabel(entry));
      return;
    }

    // Each entry gets its own scratch directory, so a leftover from a previous
    // version or an interrupted run cannot poison this concatenation.
    final Directory workDir = Directory(
      p.join(workRoot.path, 'run_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await workDir.create(recursive: true);

    try {
      final List<String> fragments = await _exportFragments(
        entry: entry,
        settings: settings,
        workDir: workDir,
        completed: completed,
        total: total,
      );
      if (fragments.isEmpty) {
        if (!_stopRequested && entry.status != EntryStatus.failed) {
          _fail(entry, _t.t('log.skipNoSilences'));
        }
        return;
      }

      final String? output = await _concatenate(
        entry: entry,
        settings: settings,
        fragments: fragments,
        workDir: workDir,
        outputDirectory: outputDirectory,
        completed: completed,
        total: total,
      );
      if (output == null) return;

      entry
        ..setOutputPath(output)
        ..setStatus(EntryStatus.completed, detail: _percentageLabel(entry));
      _log.success(
        _t.t('log.completed', <String, Object?>{'name': p.basename(output)}),
      );
    } finally {
      // Kept on failure: the fragments are the only evidence of what went
      // wrong, and the log says where they are.
      if (entry.status == EntryStatus.completed) {
        await _deleteQuietly(workDir);
      } else if (await workDir.exists()) {
        _log.info(
          _t.t('log.fragmentsKept', <String, Object?>{'path': workDir.path}),
        );
      }
    }
  }

  /// Runs `silencedetect` and turns its output into ranges on the entry.
  ///
  /// Returns false when the entry could not be analysed.
  Future<bool> _detectSilences({
    required MediaEntry entry,
    required ProcessingSettings settings,
    required int completed,
    required int total,
  }) async {
    entry.setStatus(EntryStatus.analyzing);

    final List<double> starts = <double>[];
    final List<double> ends = <double>[];

    final FFmpegResult result = await _runner.run(
      FragmentPlanner.detectArguments(
        input: entry.path,
        settings: settings,
      ),
      onLine: (String line) {
        for (final RegExpMatch match
            in FragmentPlanner.silencePattern.allMatches(line)) {
          final double? value = double.tryParse(match.group(2)!);
          if (value == null) continue;
          if (match.group(1) == 'start') {
            starts.add(value);
          } else {
            ends.add(value);
          }
        }
        _reportFfmpegLine(line);
      },
      onProgress: (FFmpegProgress progress) => _emit(
        entry: entry,
        completed: completed,
        total: total,
        position: progress.position,
        speed: progress.speed,
        fraction: progress.position.inMilliseconds / 1000.0 / entry.seconds,
      ),
    );

    if (result.cancelled || _stopRequested) return false;

    if (!result.succeeded) {
      _fail(entry, _t.t('log.skipNoSilences'), detail: result.failure);
      return false;
    }

    final SilenceParseResult parsed = FragmentPlanner.buildRanges(
      starts: starts,
      ends: ends,
      margin: settings.silenceMargin,
      mediaSeconds: entry.seconds,
    );

    if (parsed.boundariesMismatched) {
      _fail(entry, _t.t('log.dataError'));
      return false;
    }

    entry.setSilences(parsed.ranges);

    if (entry.hasSilences) {
      _log.info(
        _t.t('log.silencePercentage', <String, Object?>{
          'percentage': ((entry.silenceRatio ?? 0) * 100).toStringAsFixed(2),
        }),
      );
    }
    return true;
  }

  /// Encodes every stretch of the file at its own rate.
  ///
  /// Returns an empty list when the run was stopped or a fragment failed.
  Future<List<String>> _exportFragments({
    required MediaEntry entry,
    required ProcessingSettings settings,
    required Directory workDir,
    required int completed,
    required int total,
  }) async {
    entry.setStatus(EntryStatus.exporting);

    final String extension = entry.outputExtensionFor(settings.outputFormat);
    final List<Fragment> plan = FragmentPlanner.plan(
      silences: entry.silences,
      mediaSeconds: entry.seconds,
      dropSilence: settings.dropsSilence,
    );
    final List<String> written = <String>[];

    for (int i = 0; i < plan.length && !_stopRequested; i++) {
      final Fragment fragment = plan[i];
      final String output = p.join(
        workDir.path,
        'f_${i.toString().padLeft(6, '0')}.$extension',
      );
      final SpeedOption speed = fragment.speed(settings);

      final FFmpegResult result = await _runner.run(
        FragmentPlanner.exportArguments(
          input: entry.path,
          output: output,
          fragment: fragment,
          settings: settings,
        ),
        onLine: _reportFfmpegLine,
        onProgress: (FFmpegProgress progress) {
          // FFmpeg reports output time; scale it back up by the rate to land
          // on a position in the source file.
          final double sourceSeconds =
              fragment.start +
              progress.position.inMilliseconds / 1000.0 * speed.factor;
          _emit(
            entry: entry,
            completed: completed,
            total: total,
            position: Duration(milliseconds: (sourceSeconds * 1000).round()),
            speed: progress.speed,
            fraction: sourceSeconds / entry.seconds,
          );
        },
      );

      if (result.cancelled || _stopRequested) return const <String>[];

      if (!result.succeeded) {
        _log.warning(
          _t.t('log.fragmentError', <String, Object?>{
            'start': fragment.start.toStringAsFixed(2),
            'end': fragment.end.toStringAsFixed(2),
          }),
        );
        _fail(entry, _t.t('status.failed'), detail: result.failure);
        return const <String>[];
      }

      written.add(output);
    }

    return _stopRequested ? const <String>[] : written;
  }

  /// Stitches the fragments together without re-encoding.
  Future<String?> _concatenate({
    required MediaEntry entry,
    required ProcessingSettings settings,
    required List<String> fragments,
    required Directory workDir,
    required String outputDirectory,
    required int completed,
    required int total,
  }) async {
    entry.setStatus(EntryStatus.concatenating);

    final File listFile = File(p.join(workDir.path, 'list.txt'));
    await listFile.writeAsString(
      fragments.map(FragmentPlanner.concatListEntry).join('\n'),
      flush: true,
    );

    final String output = await _resolveOutputPath(
      directory: outputDirectory,
      fileName: entry.outputNameFor(settings.outputFormat),
      source: entry.path,
    );

    final FFmpegResult result = await _runner.run(
      FragmentPlanner.concatArguments(
        listPath: listFile.path,
        output: output,
      ),
      onLine: _reportFfmpegLine,
      onProgress: (FFmpegProgress progress) => _emit(
        entry: entry,
        completed: completed,
        total: total,
        position: progress.position,
        speed: progress.speed,
        fraction: 1,
      ),
    );

    if (result.cancelled || _stopRequested) return null;

    if (!result.succeeded) {
      _fail(entry, _t.t('log.concatenationError'), detail: result.failure);
      return null;
    }

    return output;
  }

  /// Picks a free name rather than overwriting.
  ///
  /// The Electron app passed `-y` and clobbered whatever was already there,
  /// which destroys the source outright when the export directory happens to
  /// be the folder the file came from.
  Future<String> _resolveOutputPath({
    required String directory,
    required String fileName,
    required String source,
  }) async {
    final String stem = p.basenameWithoutExtension(fileName);
    final String extension = p.extension(fileName);

    String candidate = p.join(directory, fileName);
    int suffix = 1;
    while (await File(candidate).exists() || p.equals(candidate, source)) {
      candidate = p.join(directory, '$stem ($suffix)$extension');
      suffix++;
    }
    return candidate;
  }

  void _emit({
    MediaEntry? entry,
    required int completed,
    required int total,
    Duration? position,
    double? speed,
    double? fraction,
  }) {
    _onProgress(
      RunProgress(
        entryName: entry?.name ?? '',
        completed: completed,
        total: total,
        position: position,
        speed: speed,
        fraction: fraction?.clamp(0.0, 1.0),
      ),
    );
  }

  /// Surfaces the FFmpeg chatter worth reading and drops the rest.
  void _reportFfmpegLine(String line) {
    if (_stopRequested) return;
    if (line.contains('silence_start') ||
        line.contains('silence_end') ||
        line.startsWith('[silencedetect') ||
        line.startsWith('frame=') ||
        line.startsWith('size=') ||
        line.contains('Press [q] to stop')) {
      return;
    }
    if (RegExp(
      r'error|failed|invalid|unable',
      caseSensitive: false,
    ).hasMatch(line)) {
      _log.warning(line);
    } else {
      debugPrint('ffmpeg: $line');
    }
  }

  void _fail(MediaEntry entry, String message, {String? detail}) {
    entry.setStatus(EntryStatus.failed, detail: message);
    _log.error(
      detail == null || detail.isEmpty ? message : '$message — $detail',
    );
  }

  String? _percentageLabel(MediaEntry entry) {
    final double? ratio = entry.silenceRatio;
    if (ratio == null) return null;
    return _t.t('status.silenceShare', <String, Object?>{
      'percentage': (ratio * 100).toStringAsFixed(1),
    });
  }

  Future<void> _deleteQuietly(Directory directory) async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      debugPrint('Could not remove ${directory.path}: $error');
    }
  }

  /// Marks the entry the user stopped on, so its row does not stay spinning.
  void markInterrupted() {
    _current?.setStatus(EntryStatus.interrupted);
    _current = null;
  }
}
