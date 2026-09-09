// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/options.dart';
import '../../models/processing_settings.dart';
import '../../services/app_paths.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import '../widgets/settings_tiles.dart';

/// Everything configurable, on one page.
///
/// The Electron app split this across a cramped modal and a second
/// preferences window. Grouping it into one scrollable page leaves room for
/// each setting to explain itself, which is the difference between a control
/// someone adjusts and one they leave alone because they cannot tell what it
/// does.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final ProcessingSettings settings = preferences.settings;
    final bool locked = context.watch<ProcessStore>().isRunning;

    void update(ProcessingSettings next) =>
        context.read<PreferencesStore>().updateSettings(next);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        if (locked) _LockedBanner(message: strings.ffmpegAlreadyRunning),

        SettingsGroup(
          icon: Icons.bolt,
          title: strings.settingsGroupSpeed,
          children: <Widget>[
            SliderSettingTile(
              title: strings.settingsSilenceSpeed,
              description: strings.helpSilenceSpeed,
              valueLabel: speedText(settings.silenceSpeed, strings),
              enabled: !locked,
              slider: IndexSlider(
                value: settings.silenceSpeedIndex,
                max: kSpeedOptions.length - 1,
                label: speedText(settings.silenceSpeed, strings),
                onChanged: locked
                    ? null
                    : (int index) =>
                          update(settings.copyWith(silenceSpeedIndex: index)),
              ),
            ),
            SliderSettingTile(
              title: strings.settingsPlaybackSpeed,
              description: strings.helpPlaybackSpeed,
              valueLabel: speedText(settings.playbackSpeed, strings),
              enabled: !locked,
              slider: IndexSlider(
                // Stops one short of `remove`: dropping the spoken parts would
                // leave nothing behind.
                value: settings.playbackSpeedIndex,
                max: kLastKeptSpeedIndex,
                label: speedText(settings.playbackSpeed, strings),
                onChanged: locked
                    ? null
                    : (int index) =>
                          update(settings.copyWith(playbackSpeedIndex: index)),
              ),
            ),
          ],
        ),

        SettingsGroup(
          icon: Icons.headphones_outlined,
          title: strings.settingsGroupAudio,
          children: <Widget>[
            SwitchSettingTile(
              title: strings.settingsAudioTracks,
              description: strings.helpAudioTracks,
              value: settings.keepAllAudioTracks,
              onChanged: locked
                  ? null
                  : (bool value) =>
                        update(settings.copyWith(keepAllAudioTracks: value)),
            ),
            SwitchSettingTile(
              title: strings.settingsMuteSilences,
              description: strings.helpMuteSilences,
              value: settings.mutesSilence,
              onChanged: locked || settings.dropsSilence
                  ? null
                  : (bool value) =>
                        update(settings.copyWith(muteSilences: value)),
            ),
            DropdownSettingTile<int>(
              title: strings.settingsAudioRate,
              description: strings.helpAudioRate,
              value: settings.audioRateIndex,
              items: _indexItems(kAudioRates, strings),
              onChanged: locked
                  ? null
                  : (int? index) => index == null
                        ? null
                        : update(settings.copyWith(audioRateIndex: index)),
            ),
          ],
        ),

        SettingsGroup(
          icon: Icons.graphic_eq,
          title: strings.settingsGroupDetection,
          children: <Widget>[
            SliderSettingTile(
              title: strings.settingsBackgroundNoise,
              description: strings.helpBackgroundNoise,
              valueLabel: optionText(
                kThresholds[settings.thresholdIndex],
                strings,
              ),
              enabled: !locked,
              slider: IndexSlider(
                value: settings.thresholdIndex,
                max: kThresholds.length - 1,
                label: optionText(kThresholds[settings.thresholdIndex], strings),
                onChanged: locked
                    ? null
                    : (int index) =>
                          update(settings.copyWith(thresholdIndex: index)),
              ),
            ),
            SliderSettingTile(
              title: strings.settingsSilenceMinDuration,
              description: strings.helpSilenceMinDuration,
              valueLabel: _seconds(settings.silenceMinDuration),
              enabled: !locked,
              slider: Slider(
                value: settings.silenceMinDuration.clamp(
                  kSilenceDurationMin,
                  kSilenceDurationMax,
                ),
                min: kSilenceDurationMin,
                max: kSilenceDurationMax,
                divisions: _durationDivisions,
                label: _seconds(settings.silenceMinDuration),
                onChanged: locked
                    ? null
                    : (double value) =>
                          update(settings.copyWith(silenceMinDuration: value)),
              ),
            ),
            SliderSettingTile(
              title: strings.settingsSilenceMargin,
              description: strings.helpSilenceMargin,
              valueLabel: _seconds(settings.silenceMargin),
              enabled: !locked,
              slider: Slider(
                value: settings.silenceMargin.clamp(
                  kSilenceDurationMin,
                  kSilenceDurationMax,
                ),
                min: kSilenceDurationMin,
                max: kSilenceDurationMax,
                divisions: _durationDivisions,
                label: _seconds(settings.silenceMargin),
                onChanged: locked
                    ? null
                    : (double value) =>
                          update(settings.copyWith(silenceMargin: value)),
              ),
            ),
            _FilterPreview(settings: settings),
          ],
        ),

        SettingsGroup(
          icon: Icons.movie_creation_outlined,
          title: strings.settingsGroupExport,
          children: <Widget>[
            DropdownSettingTile<String>(
              title: strings.settingsFormat,
              description: strings.helpFormat,
              value: settings.outputFormat,
              items: kFormats
                  .map(
                    (LabeledOption format) => DropdownMenuItem<String>(
                      value: format.value,
                      child: Text(optionText(format, strings)),
                    ),
                  )
                  .toList(),
              onChanged: locked
                  ? null
                  : (String? format) => format == null
                        ? null
                        : update(settings.copyWith(outputFormat: format)),
            ),
            SliderSettingTile(
              title: strings.settingsCrf,
              description: strings.helpCrf,
              valueLabel: '${settings.crf}',
              enabled: !locked,
              slider: Slider(
                value: settings.crf.toDouble(),
                min: kCrfMin.toDouble(),
                max: kCrfMax.toDouble(),
                divisions: kCrfMax - kCrfMin,
                label: '${settings.crf}',
                onChanged: locked
                    ? null
                    : (double value) =>
                          update(settings.copyWith(crf: value.round())),
              ),
            ),
            DropdownSettingTile<int>(
              title: strings.settingsFps,
              description: strings.helpFps,
              value: settings.fpsIndex,
              items: _indexItems(kFpsOptions, strings),
              onChanged: locked
                  ? null
                  : (int? index) => index == null
                        ? null
                        : update(settings.copyWith(fpsIndex: index)),
            ),
            DropdownSettingTile<int>(
              title: strings.settingsPreset,
              description: strings.helpPreset,
              value: settings.presetIndex,
              items: _indexItems(kPresets, strings),
              onChanged: locked
                  ? null
                  : (int? index) => index == null
                        ? null
                        : update(settings.copyWith(presetIndex: index)),
            ),
            DropdownSettingTile<int>(
              title: strings.settingsTune,
              description: strings.helpTune,
              value: settings.tuneIndex,
              items: _indexItems(kTunes, strings),
              onChanged: locked
                  ? null
                  : (int? index) => index == null
                        ? null
                        : update(settings.copyWith(tuneIndex: index)),
            ),
          ],
        ),

        SettingsGroup(
          icon: Icons.play_circle_outline,
          title: strings.settingsGroupPreview,
          children: <Widget>[
            DropdownSettingTile<int>(
              title: strings.settingsPreviewDuration,
              description: strings.helpPreviewDuration,
              value: settings.previewIndex,
              width: 120,
              items: List<DropdownMenuItem<int>>.generate(
                kPreviewDurations.length,
                (int index) => DropdownMenuItem<int>(
                  value: index,
                  child: Text(strings.previewSeconds(kPreviewDurations[index])),
                ),
              ),
              onChanged: locked
                  ? null
                  : (int? index) => index == null
                        ? null
                        : update(settings.copyWith(previewIndex: index)),
            ),
          ],
        ),

        SettingsGroup(
          icon: Icons.tune,
          title: strings.settingsGroupApp,
          children: <Widget>[
            SegmentedSettingTile<ThemeMode>(
              title: strings.uiTheme,
              description: strings.helpTheme,
              selected: preferences.themeMode,
              segments: <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text(strings.uiSystemMode),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text(strings.uiLightMode),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text(strings.uiDarkMode),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
              ],
              onChanged: (ThemeMode mode) =>
                  context.read<PreferencesStore>().setThemeMode(mode),
            ),
            SegmentedSettingTile<String>(
              title: strings.uiLanguage,
              description: strings.helpLanguage,
              // The empty string stands for "no pinned language".
              selected: preferences.preferredLocale?.languageCode ?? '',
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: '',
                  label: Text(strings.uiSystemMode),
                  icon: const Icon(Icons.language),
                ),
                const ButtonSegment<String>(
                  value: 'en',
                  label: Text('English'),
                ),
                const ButtonSegment<String>(
                  value: 'it',
                  label: Text('Italiano'),
                ),
              ],
              onChanged: (String code) => context
                  .read<PreferencesStore>()
                  .setPreferredLocale(code.isEmpty ? null : Locale(code)),
            ),
            const _WorkingDirectoryTile(),
            SettingTile(
              title: strings.settingsResetProcessing,
              description: strings.settingsResetProcessingHint,
              enabled: !locked,
              trailing: const Icon(Icons.restart_alt),
              onTap: locked
                  ? null
                  : () async {
                      await context.read<PreferencesStore>().resetSettings();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).settingsResetDone,
                          ),
                        ),
                      );
                    },
            ),
          ],
        ),
      ],
    );
  }

  static const int _durationDivisions =
      (kSilenceDurationMax - kSilenceDurationMin) ~/ kSilenceDurationStep;

  static String _seconds(double value) => '${value.toStringAsFixed(2)} s';

  static List<DropdownMenuItem<int>> _indexItems(
    List<LabeledOption> options,
    AppLocalizations strings,
  ) {
    return List<DropdownMenuItem<int>>.generate(
      options.length,
      (int index) => DropdownMenuItem<int>(
        value: index,
        child: Text(optionText(options[index], strings)),
      ),
    );
  }
}

/// Says why the settings are read-only, instead of leaving greyed-out
/// controls to be puzzled over.
class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the intermediate fragments go, with its size and a way to empty it.
class _WorkingDirectoryTile extends StatefulWidget {
  const _WorkingDirectoryTile();

  @override
  State<_WorkingDirectoryTile> createState() => _WorkingDirectoryTileState();
}

class _WorkingDirectoryTileState extends State<_WorkingDirectoryTile> {
  int? _bytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final int bytes = await AppPaths.directoryBytes(
      context.read<PreferencesStore>().workingDirectory,
    );
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  Future<void> _browse() async {
    final PreferencesStore preferences = context.read<PreferencesStore>();
    final String? chosen = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).preferenceChooseWorkingDir,
      initialDirectory: preferences.workingDirectory,
    );
    if (chosen == null) return;
    await preferences.setWorkingDirectory(chosen);
    await _refresh();
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    await AppPaths.emptyDirectory(
      context.read<PreferencesStore>().workingDirectory,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final bool locked = context.watch<ProcessStore>().isRunning;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.preferenceWorkingDir, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            strings.preferenceWorkingDirHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  preferences.workingDirectory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const <String>[
                      'Consolas',
                      'Menlo',
                      'monospace',
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: locked ? null : _browse,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(strings.preferenceChooseWorkingDir),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.preferenceTemporaryFiles(
                    _bytes == null ? '…' : _formatBytes(_bytes!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: locked || _busy || _bytes == null || _bytes == 0
                    ? null
                    : _clear,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(strings.preferenceClearTemporary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024;
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }
}

/// Shows the `silencedetect` filter the current settings produce.
///
/// The detection window is deliberately wider than the minimum duration — by
/// twice the margin — and seeing the real filter string makes that visible
/// instead of surprising.
class _FilterPreview extends StatelessWidget {
  const _FilterPreview({required this.settings});

  final ProcessingSettings settings;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppLocalizations.of(context).settingsFilterPreview,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            settings.silenceDetectFilter,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: <String>['Consolas', 'Menlo', 'monospace'],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
