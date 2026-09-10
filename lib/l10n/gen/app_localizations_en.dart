// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutBuiltWith => 'Built with Flutter, powered by FFmpeg';

  @override
  String get aboutCopyright => 'Copyright (C) 2025-2026 Vincenzo Padula';

  @override
  String get aboutLicenseSection => 'Licence';

  @override
  String get aboutOpenInBrowser => 'Opens in your browser';

  @override
  String get appIntro =>
      'Import some videos, choose the configuration and then press Start to speed up (or remove) their silences.';

  @override
  String get ffmpegAlreadyRunning =>
      'FFmpeg is still running; cannot start another process.';

  @override
  String ffmpegDurationError(String name) {
    return 'Could not read the duration of $name.';
  }

  @override
  String get ffmpegSpeed => 'Speed';

  @override
  String get ffmpegTime => 'Time';

  @override
  String get fileAnalyze => 'Measure the silences without exporting';

  @override
  String get fileOpenDir => 'Select a folder';

  @override
  String get fileOpenFile => 'Select one or more videos';

  @override
  String get filePreview => 'Generate a short preview sample';

  @override
  String get filePreviewSuffix => ' (preview)';

  @override
  String get fileRemove => 'Remove this video from the list';

  @override
  String get fileReveal => 'Show the exported file';

  @override
  String get helpAudioRate =>
      'Resample the audio. Keep leaves it exactly as it is, which is almost always right.';

  @override
  String get helpAudioTracks =>
      'Carry every audio track of the source into the output. Silences are still detected on the first track only, which is the voice track in a multi-track recording.';

  @override
  String get helpBackgroundNoise =>
      'How loud the room is. Raise it when a quiet hiss is being mistaken for speech.';

  @override
  String get helpCredits => 'Credits';

  @override
  String get helpCrf =>
      'Constant Rate Factor: lower means better quality and a bigger file. 23 is a good default.';

  @override
  String get helpFfmpegNotice =>
      'FFmpeg is bundled with this app under the GPLv3 licence. There is nothing to install or configure.';

  @override
  String get helpFormat =>
      'Container for the exported file. Keep reuses the source container.';

  @override
  String get helpFps =>
      'Frame rate every fragment is normalised to, so the pieces can be joined without re-encoding.';

  @override
  String get helpGplNotice =>
      'This program comes with absolutely no warranty. It is free software, and you are welcome to redistribute it under the conditions of the GNU General Public License version 3 or later.';

  @override
  String get helpIcons => 'Icons';

  @override
  String get helpIconsCredit =>
      'Icons from creazilla.com under the CC BY 4.0 licence.';

  @override
  String get helpIntro =>
      'Speed up your videos by speeding up (or removing) silences, using FFmpeg. Built with Flutter.';

  @override
  String get helpLanguage =>
      'Follows the system language, falling back to English. Pin one to override it.';

  @override
  String get helpLicense =>
      'This program comes with absolutely no warranty. It is free software, and you are welcome to redistribute it under certain conditions; see the licence for details.';

  @override
  String get helpMuteSilences =>
      'Silence the audio of the quiet parts instead of letting the sped-up hiss through.';

  @override
  String get helpPlaybackSpeed =>
      'Rate for the parts where someone is speaking. Leave at 1x to keep speech natural.';

  @override
  String get helpPreset =>
      'How hard x264 works. Slower presets give smaller files for the same quality.';

  @override
  String get helpPreviewDuration =>
      'How much of the video a preview samples. It is taken from a third of the way in, where the recording is most representative.';

  @override
  String get helpReadLicense => 'Read the licence';

  @override
  String get helpSilenceMargin =>
      'Time kept on each side of every silence, so words are not clipped.';

  @override
  String get helpSilenceMinDuration =>
      'How long a pause must last before it counts as silence.';

  @override
  String get helpSilenceSpeed =>
      'Rate for the quiet parts. Pick Remove to cut them out entirely.';

  @override
  String get helpTheme => 'Follow the system, or pin light or dark.';

  @override
  String get helpTune =>
      'A hint to x264 about the kind of content: Still image for slides, Film for camera footage.';

  @override
  String get logAllDone => 'All done.';

  @override
  String logAlreadyExists(String name) {
    return 'Cannot load $name: that file name is already queued.';
  }

  @override
  String logCompleted(String name) {
    return '$name completed.';
  }

  @override
  String get logConcatenationError => 'Error while joining the fragments.';

  @override
  String get logDataError => 'Data error: silence boundaries do not pair up.';

  @override
  String logFileMissing(String name) {
    return '$name is no longer where it was; skipping it.';
  }

  @override
  String logFilesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files added.',
      one: '1 file added.',
      zero: 'No files added.',
    );
    return '$_temp0';
  }

  @override
  String logFragmentError(double start, double end) {
    final intl.NumberFormat startNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String startString = startNumberFormat.format(start);
    final intl.NumberFormat endNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String endString = endNumberFormat.format(end);

    return 'Fragment [$startString - $endString] failed to encode.';
  }

  @override
  String logFragmentsKept(String path) {
    return 'Fragments left in $path for inspection.';
  }

  @override
  String logLinkError(String url) {
    return 'Could not open $url';
  }

  @override
  String get logNoSilenceDetected =>
      'No silences detected, moving on to the next.';

  @override
  String logOutputDirError(String path, String error) {
    return 'Cannot write to $path. $error';
  }

  @override
  String logPreviewReady(String name) {
    return 'Preview ready: $name';
  }

  @override
  String logPreviewTooShort(String name) {
    return '$name is shorter than the preview length; sampling all of it.';
  }

  @override
  String get logQueueEmpty => 'No video queued.';

  @override
  String logSilencePercentage(double percentage) {
    final intl.NumberFormat percentageNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 2,
        );
    final String percentageString = percentageNumberFormat.format(percentage);

    return '$percentageString % of the video detected as silence.';
  }

  @override
  String get logSkipNoSilences => 'Analysis failed, moving on to the next.';

  @override
  String logStarted(String name) {
    return 'Started working on $name.';
  }

  @override
  String get logStopping => 'Stopping...';

  @override
  String get menuAbout => 'About';

  @override
  String get menuCleanShell => 'Clear log';

  @override
  String get menuClearQueue => 'Clear queue';

  @override
  String get menuDonate => 'Buy me a coffee';

  @override
  String get menuHideShell => 'Hide log';

  @override
  String get menuIssue => 'Report an issue';

  @override
  String get menuLicense => 'View licence';

  @override
  String get menuOpenFile => 'Add video(s)';

  @override
  String get menuOpenFolder => 'Add folder';

  @override
  String get menuProgress => 'Compact progress';

  @override
  String get menuQuit => 'Quit';

  @override
  String get menuReferences => 'References';

  @override
  String get menuShowShell => 'Show log';

  @override
  String get menuSourceCode => 'Source code';

  @override
  String get menuThirdPartyLicenses => 'Third-party licences';

  @override
  String get menuUpdate => 'An update is available';

  @override
  String menuVersion(String version) {
    return 'Version $version';
  }

  @override
  String get menuWindowMode => 'Back to window';

  @override
  String get navAbout => 'About';

  @override
  String get navQueue => 'Queue';

  @override
  String get navSection => 'More';

  @override
  String get navSettings => 'App settings';

  @override
  String get noiseHigh => 'High';

  @override
  String get noiseLow => 'Low';

  @override
  String get noiseMid => 'Mid';

  @override
  String get optionKeep => 'Keep';

  @override
  String get optionNone => 'None';

  @override
  String get outputAlongsideSource => 'Next to the source video';

  @override
  String get outputChooseFolder => 'Choose the export folder';

  @override
  String get outputFolder => 'Export to';

  @override
  String get outputFolderHint => 'Each video is written to its own folder';

  @override
  String get preferenceBundledFfmpeg =>
      'FFmpeg is bundled with the app: there is no path to configure.';

  @override
  String get preferenceChooseExportDir => 'Select where to export videos';

  @override
  String get preferenceChangeWorkingDir => 'Change folder';

  @override
  String get preferenceChooseWorkingDir =>
      'Select where to keep the intermediate fragments';

  @override
  String get preferenceClearTemporary => 'Clear';

  @override
  String get preferenceExportDir => 'Export directory';

  @override
  String get preferenceReset => 'Reset';

  @override
  String get preferenceSave => 'Save';

  @override
  String preferenceTemporaryFiles(String size) {
    return 'Temporary files: $size';
  }

  @override
  String get preferenceWorkingDir => 'Working directory';

  @override
  String get preferenceWorkingDirHint =>
      'Intermediate fragments are written here while a run is in progress, then removed. Put it on a fast drive with room to spare.';

  @override
  String previewSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get processStart => 'Start';

  @override
  String get processStop => 'Stop';

  @override
  String queueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: 'No videos',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvanced => 'Advanced settings';

  @override
  String get settingsAudioRate => 'Audio rate';

  @override
  String get settingsAudioTracks => 'Keep all audio tracks';

  @override
  String get settingsBackgroundNoise => 'Background noise';

  @override
  String get settingsBasic => 'Basic settings';

  @override
  String get settingsCrf => 'CRF';

  @override
  String get settingsFilterPreview => 'Detection filter';

  @override
  String get settingsFormat => 'Video format';

  @override
  String get settingsFps => 'FPS';

  @override
  String get settingsEncodingHide => 'Hide the encoding settings';

  @override
  String get settingsEncodingShow => 'Show the encoding settings';

  @override
  String get settingsEncodingTitle => 'Encoding settings';

  @override
  String get settingsGroupApp => 'Application';

  @override
  String get settingsGroupAudio => 'Audio';

  @override
  String get settingsGroupDetection => 'Silence detection';

  @override
  String get settingsGroupExport => 'Export';

  @override
  String get settingsGroupPreview => 'Preview';

  @override
  String get settingsGroupSpeed => 'Speed';

  @override
  String get settingsMuteSilences => 'Mute silences';

  @override
  String get settingsPlaybackSpeed => 'Speech speed';

  @override
  String get settingsPreset => 'Preset';

  @override
  String get settingsPreviewDuration => 'Preview length';

  @override
  String get settingsResetDone => 'Processing settings reset';

  @override
  String get settingsResetProcessing => 'Reset processing settings';

  @override
  String get settingsResetProcessingHint =>
      'Puts every speed, detection and export setting back to its default.';

  @override
  String get settingsSilence => 'Silence detection';

  @override
  String get settingsSilenceMargin => 'Silence margin';

  @override
  String get settingsSilenceMinDuration => 'Silence min duration';

  @override
  String get settingsSilenceSpeed => 'Silence speed';

  @override
  String get settingsSpeedRemove => 'Remove';

  @override
  String get settingsSpeedRemoveShort => 'cut';

  @override
  String get settingsTune => 'Tune';

  @override
  String get statusAnalyzing => 'Detecting silences...';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusConcatenating => 'Joining fragments...';

  @override
  String get statusExporting => 'Exporting...';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusInterrupted => 'Interrupted';

  @override
  String statusLoaded(String duration) {
    return 'Loaded [$duration]';
  }

  @override
  String get statusLoading => 'Loading...';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusReady => 'Ready';

  @override
  String statusSilenceShare(double percentage) {
    final intl.NumberFormat percentageNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String percentageString = percentageNumberFormat.format(percentage);

    return '$percentageString % silence';
  }

  @override
  String get uiClose => 'Close';

  @override
  String get uiDarkMode => 'Dark';

  @override
  String get uiDropVideo => 'Drop videos here';

  @override
  String get uiLanguage => 'Language';

  @override
  String get uiLightMode => 'Light';

  @override
  String get uiSystemMode => 'System';

  @override
  String get uiTheme => 'Theme';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get updateDetails => 'Details';

  @override
  String get updateDownload => 'Download';
}
