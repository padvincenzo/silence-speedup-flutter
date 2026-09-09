// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import '../models/media_entry.dart';
import '../models/options.dart';
import 'gen/app_localizations.dart';

/// Turns the models' enums into text.
///
/// This is the only place that maps a model value to a translated string, so
/// `models/` stays free of any dependency on the generated localizations. Every
/// switch here is exhaustive: adding an enum value breaks the build rather than
/// silently rendering nothing.

/// Text for one of the labels that is a word rather than a technical token.
String localizedLabel(OptionLabel label, AppLocalizations strings) {
  return switch (label) {
    OptionLabel.keep => strings.optionKeep,
    OptionLabel.none => strings.optionNone,
    OptionLabel.noiseLow => strings.noiseLow,
    OptionLabel.noiseMid => strings.noiseMid,
    OptionLabel.noiseHigh => strings.noiseHigh,
    OptionLabel.removeSilence => strings.settingsSpeedRemove,
  };
}

/// Label for a dropdown or slider entry, translated when it needs to be.
String optionText(LabeledOption option, AppLocalizations strings) {
  final OptionLabel? translated = option.translatedLabel;
  return translated == null ? option.label : localizedLabel(translated, strings);
}

/// Label for a playback rate: the rate itself, or the word for "remove".
String speedText(SpeedOption option, AppLocalizations strings) {
  final OptionLabel? translated = option.translatedLabel;
  return translated == null ? option.label : localizedLabel(translated, strings);
}

/// Status shown in the queue.
String statusText(EntryStatus status, AppLocalizations strings) {
  return switch (status) {
    EntryStatus.probing => strings.statusLoading,
    EntryStatus.ready => strings.statusReady,
    EntryStatus.queued => strings.statusQueued,
    EntryStatus.analyzing => strings.statusAnalyzing,
    EntryStatus.exporting => strings.statusExporting,
    EntryStatus.concatenating => strings.statusConcatenating,
    EntryStatus.completed => strings.statusCompleted,
    EntryStatus.failed => strings.statusFailed,
    EntryStatus.interrupted => strings.statusInterrupted,
  };
}
