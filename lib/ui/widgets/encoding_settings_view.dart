// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/options.dart';
import '../../models/processing_settings.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import 'settings_tiles.dart';

/// Everything that decides how a video is encoded.
///
/// These are the settings someone changes between one run and the next, so
/// they are not a place to navigate to: the same view is shown docked beside
/// the queue on a wide window and as a side sheet on a narrow one. Whatever
/// is application-level — theme, language, scratch space — lives on the app
/// settings page instead, because it is set once and then forgotten.
class EncodingSettingsView extends StatelessWidget {
  const EncodingSettingsView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final ProcessingSettings settings = preferences.settings;
    final bool locked = context.watch<ProcessStore>().isRunning;

    void update(ProcessingSettings next) =>
        context.read<PreferencesStore>().updateSettings(next);

    return ListView(
      padding: padding ?? const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        if (locked) LockedNotice(message: strings.ffmpegAlreadyRunning),

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
              items: indexItems(kAudioRates, strings),
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
              items: indexItems(kFpsOptions, strings),
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
              items: indexItems(kPresets, strings),
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
              items: indexItems(kTunes, strings),
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

        // The reset belongs here rather than with the application settings:
        // what it puts back are the encoding settings above it.
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SettingTile(
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
        ),
      ],
    );
  }

  static const int _durationDivisions =
      (kSilenceDurationMax - kSilenceDurationMin) ~/ kSilenceDurationStep;

  static String _seconds(double value) => '${value.toStringAsFixed(2)} s';
}

/// Turns an option catalogue into dropdown entries addressed by index.
List<DropdownMenuItem<int>> indexItems(
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
            style: TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: const <String>[
                'Consolas',
                'Menlo',
                'monospace',
              ],
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
