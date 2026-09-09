// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/foundation.dart';

import '../models/media_entry.dart';
import '../models/options.dart';
import '../models/processing_settings.dart';

/// Fragments shorter than this are dropped: FFmpeg cannot usefully encode them
/// and they only add seams to the concatenation.
const double kMinFragmentSeconds = 0.002;

/// One planned output chunk of a source file.
@immutable
class Fragment {
  const Fragment({
    required this.start,
    required this.end,
    required this.isSilence,
  });

  /// Absolute position in the source, in seconds.
  final double start;
  final double end;

  /// True for a quiet stretch, which is rated and muted differently.
  final bool isSilence;

  double get duration => end - start;

  /// Rate this fragment is played back at.
  SpeedOption speed(ProcessingSettings settings) =>
      isSilence ? settings.silenceSpeed : settings.playbackSpeed;
}

/// Result of pairing up `silencedetect` output.
@immutable
class SilenceParseResult {
  const SilenceParseResult(this.ranges, {required this.boundariesMismatched});

  final List<SilenceRange> ranges;

  /// True when starts and ends could not be paired, which means the detection
  /// output was not usable.
  final bool boundariesMismatched;
}

/// Pure translation of settings and detected silences into FFmpeg invocations.
///
/// Kept free of I/O and of the engine's progress plumbing so the argument
/// lists — the part where an off-by-one is expensive and invisible — can be
/// asserted directly in tests.
class FragmentPlanner {
  const FragmentPlanner._();

  /// Matches both boundary lines `silencedetect` prints.
  static final RegExp silencePattern = RegExp(
    r'silence_(start|end):\s*(-?\d+(?:\.\d+)?)',
  );

  /// Arguments for the detection pass. Decodes audio only and writes nothing.
  static List<String> detectArguments({
    required String input,
    required ProcessingSettings settings,
  }) {
    return <String>[
      '-hide_banner',
      '-dn',
      '-vn',
      '-ss', '0',
      '-i', input,
      '-af', settings.silenceDetectFilter,
      '-f', 'null',
      '-',
    ];
  }

  /// Pairs detected boundaries and trims each range by the margin.
  ///
  /// Unlike the Electron original, which skipped the first boundary of each
  /// list, the margin applies to every range — that asymmetry left the first
  /// silence a margin too wide at both ends.
  static SilenceParseResult buildRanges({
    required List<double> starts,
    required List<double> ends,
    required double margin,
    required double mediaSeconds,
  }) {
    final List<double> closes = List<double>.of(ends);

    // A file that fades out into silence can end without a closing boundary;
    // treat the end of the media as the close rather than dropping the run.
    if (starts.isNotEmpty && closes.length == starts.length - 1) {
      closes.add(mediaSeconds);
    }

    if (starts.length != closes.length) {
      return const SilenceParseResult(
        <SilenceRange>[],
        boundariesMismatched: true,
      );
    }

    final List<SilenceRange> ranges = <SilenceRange>[];
    double previousEnd = 0;
    for (int i = 0; i < starts.length; i++) {
      final double start = (starts[i] + margin).clamp(0.0, mediaSeconds);
      final double end = (closes[i] - margin).clamp(0.0, mediaSeconds);
      if (end - start <= kMinFragmentSeconds) continue;
      // Overlapping ranges would produce fragments that replay the same audio.
      if (start < previousEnd) continue;
      ranges.add(SilenceRange(start, end));
      previousEnd = end;
    }

    return SilenceParseResult(ranges, boundariesMismatched: false);
  }

  /// Walks the timeline and emits alternating spoken and silent stretches.
  static List<Fragment> plan({
    required List<SilenceRange> silences,
    required double mediaSeconds,
    required bool dropSilence,
  }) {
    final List<Fragment> plan = <Fragment>[];
    double cursor = 0;

    void addPlayback(double start, double end) {
      if (end - start > kMinFragmentSeconds) {
        plan.add(Fragment(start: start, end: end, isSilence: false));
      }
    }

    for (final SilenceRange range in silences) {
      addPlayback(cursor, range.start);
      if (!dropSilence && range.duration > kMinFragmentSeconds) {
        plan.add(
          Fragment(start: range.start, end: range.end, isSilence: true),
        );
      }
      cursor = range.end;
    }
    addPlayback(cursor, mediaSeconds);

    return plan;
  }

  /// Arguments that encode one fragment at its own rate.
  static List<String> exportArguments({
    required String input,
    required String output,
    required Fragment fragment,
    required ProcessingSettings settings,
  }) {
    final SpeedOption speed = fragment.speed(settings);

    final List<String> arguments = <String>[
      '-hide_banner',
      '-y',
      '-loglevel', 'warning',
      '-stats',
      '-dn',
      // As input options these are absolute positions in the source, which is
      // exactly what the plan produces.
      '-ss', timestamp(fragment.start),
      '-to', timestamp(fragment.end),
      '-i', input,
      '-map_metadata', '-1',
      '-map_chapters', '-1',
      '-segment_time_metadata', '0',
      '-max_muxing_queue_size', '99999',
      '-c:a', kAudioCodec,
      '-c:v', kVideoCodec,
      '-preset', settings.preset,
      '-crf', '${settings.crf}',
      // Every fragment is normalised to one constant frame rate, which is what
      // lets the concat step copy streams instead of re-encoding them.
      '-vsync', 'cfr',
      '-fflags', '+genpts',
    ];

    if (settings.tune != kNoneValue) {
      arguments.addAll(<String>['-tune', settings.tune]);
    }
    if (settings.audioRate != kNoneValue) {
      arguments.addAll(<String>['-ar', settings.audioRate]);
    }

    arguments.addAll(<String>[
      '-vf',
      <String>[
        if (speed.videoFilter != null) speed.videoFilter!,
        'fps=${settings.fps}',
      ].join(','),
    ]);

    // Muting keeps the tempo filter in place: dropping it would leave the
    // audio longer than the sped-up video and desync everything after it.
    final List<String> audioFilters = <String>[
      if (speed.audioFilter != null) speed.audioFilter!,
      if (fragment.isSilence && settings.mutesSilence) 'volume=0',
    ];
    if (audioFilters.isNotEmpty) {
      arguments.addAll(<String>['-af', audioFilters.join(',')]);
    }

    arguments.add(output);
    return arguments;
  }

  /// Arguments that stitch the fragments together without re-encoding.
  static List<String> concatArguments({
    required String listPath,
    required String output,
  }) {
    return <String>[
      '-hide_banner',
      '-y',
      '-loglevel', 'warning',
      '-stats',
      '-segment_time_metadata', '0',
      '-vsync', 'cfr',
      '-f', 'concat',
      '-safe', '0',
      '-i', listPath,
      '-c:a', 'copy',
      '-c:v', 'copy',
      output,
    ];
  }

  /// Formats one concat-demuxer line.
  ///
  /// Paths are normalised to forward slashes because the demuxer reads a
  /// backslash as an escape character, and single quotes get the escape the
  /// format requires.
  static String concatListEntry(String path) {
    final String normalised = path.replaceAll(r'\', '/');
    final String escaped = normalised.replaceAll("'", r"'\''");
    return "file '$escaped'";
  }

  /// FFmpeg wants plain seconds; six decimals is well past frame accuracy.
  static String timestamp(double seconds) => seconds.toStringAsFixed(6);
}
