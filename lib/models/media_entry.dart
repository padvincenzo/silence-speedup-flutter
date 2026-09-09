// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'options.dart';

/// A closed quiet range in the source file, in seconds.
@immutable
class SilenceRange {
  const SilenceRange(this.start, this.end);

  final double start;
  final double end;

  double get duration => end - start;
}

/// Where an entry is in its lifecycle. The UI maps each value to a label and a
/// colour, so the engine never has to hand around display strings.
enum EntryStatus {
  probing,
  ready,
  queued,
  analyzing,
  exporting,
  concatenating,
  completed,
  failed,
  interrupted,
}

/// One queued media file.
///
/// Mutable and observable: rows update in place as a run progresses, the way
/// the Electron version mutated its table cells.
class MediaEntry extends ChangeNotifier {
  MediaEntry(this.path)
    : name = p.basename(path),
      extension = p.extension(path).replaceFirst('.', '').toLowerCase();

  /// Absolute path of the source file.
  final String path;

  /// File name with extension, and the queue's identity: importing the same
  /// name twice is refused, as in the Electron app.
  final String name;

  /// Lowercase extension without the dot.
  final String extension;

  Duration? _duration;
  EntryStatus _status = EntryStatus.probing;
  String? _detail;
  List<SilenceRange> _silences = const <SilenceRange>[];
  String? _outputPath;

  Duration? get duration => _duration;

  EntryStatus get status => _status;

  /// Extra text shown next to the status: a duration, an error, a percentage.
  String? get detail => _detail;

  List<SilenceRange> get silences => _silences;

  /// Where the finished file landed, once it has.
  String? get outputPath => _outputPath;

  bool get hasSilences => _silences.isNotEmpty;

  /// Source length in seconds, or 0 when probing failed.
  double get seconds =>
      _duration == null ? 0 : _duration!.inMilliseconds / 1000.0;

  /// True once the entry can take part in a run.
  bool get isProcessable => _duration != null && seconds > 0;

  set duration(Duration? value) {
    _duration = value;
    notifyListeners();
  }

  void setStatus(EntryStatus status, {String? detail}) {
    _status = status;
    _detail = detail;
    notifyListeners();
  }

  void setSilences(List<SilenceRange> silences) {
    _silences = silences;
    notifyListeners();
  }

  void setOutputPath(String? value) {
    _outputPath = value;
    notifyListeners();
  }

  /// Resets the per-run state so a re-run starts from a clean slate.
  void prepare() {
    _silences = const <SilenceRange>[];
    _outputPath = null;
    setStatus(EntryStatus.queued);
  }

  /// Total seconds detected as silence.
  double get silenceSeconds => _silences.fold<double>(
    0,
    (double sum, SilenceRange range) => sum + range.duration,
  );

  /// Share of the source detected as silence, or null when unknown.
  double? get silenceRatio {
    if (!isProcessable) return null;
    return silenceSeconds / seconds;
  }

  /// File name to write, honouring the chosen container.
  String outputNameFor(String format) {
    if (format == kKeepFormat) return name;
    return '${p.basenameWithoutExtension(name)}.$format';
  }

  /// Extension the fragments must use, since they are concatenated without
  /// re-encoding and therefore have to share the output's container.
  String outputExtensionFor(String format) =>
      format == kKeepFormat ? extension : format;

  static bool isSupported(String path) {
    final String extension = p
        .extension(path)
        .replaceFirst('.', '')
        .toLowerCase();
    return kImportableExtensions.contains(extension);
  }
}
