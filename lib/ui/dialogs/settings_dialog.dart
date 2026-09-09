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
import '../widgets/setting_controls.dart';

/// The settings sheet: the three groups the Electron modal had, in the same
/// order — what to do with each stretch, how to find the silences, and how to
/// encode the result.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final ProcessingSettings settings = preferences.settings;

    void update(ProcessingSettings next) =>
        context.read<PreferencesStore>().updateSettings(next);

    String speedLabel(int index) => speedText(kSpeedOptions[index], strings);

    return AlertDialog(
      icon: const Icon(Icons.tune),
      title: Text(strings.settingsTitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SettingSection(
                icon: Icons.bolt,
                title: strings.settingsBasic,
                children: <Widget>[
                  SettingRow(
                    label: strings.settingsSilenceSpeed,
                    help: strings.helpSilenceSpeed,
                    child: IndexSlider(
                      value: settings.silenceSpeedIndex,
                      max: kSpeedOptions.length - 1,
                      labelAt: speedLabel,
                      onChanged: (int index) =>
                          update(settings.copyWith(silenceSpeedIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsPlaybackSpeed,
                    help: strings.helpPlaybackSpeed,
                    child: IndexSlider(
                      // Stops one short of `remove`: dropping the spoken parts
                      // would leave nothing behind.
                      value: settings.playbackSpeedIndex,
                      max: kLastKeptSpeedIndex,
                      labelAt: speedLabel,
                      onChanged: (int index) =>
                          update(settings.copyWith(playbackSpeedIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsAudioTracks,
                    help: strings.helpAudioTracks,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: settings.keepAllAudioTracks,
                        onChanged: (bool value) => update(
                          settings.copyWith(keepAllAudioTracks: value),
                        ),
                      ),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsMuteSilences,
                    help: strings.helpMuteSilences,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: settings.mutesSilence,
                        onChanged: settings.dropsSilence
                            ? null
                            : (bool value) =>
                                  update(settings.copyWith(muteSilences: value)),
                      ),
                    ),
                  ),
                ],
              ),
              SettingSection(
                icon: Icons.graphic_eq,
                title: strings.settingsSilence,
                children: <Widget>[
                  SettingRow(
                    label: strings.settingsBackgroundNoise,
                    help: strings.helpBackgroundNoise,
                    child: IndexSlider(
                      value: settings.thresholdIndex,
                      max: kThresholds.length - 1,
                      labelAt: (int index) =>
                          optionText(kThresholds[index], strings),
                      onChanged: (int index) =>
                          update(settings.copyWith(thresholdIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsSilenceMinDuration,
                    help: strings.helpSilenceMinDuration,
                    child: ValueSlider(
                      value: settings.silenceMinDuration,
                      min: kSilenceDurationMin,
                      max: kSilenceDurationMax,
                      step: kSilenceDurationStep,
                      format: _seconds,
                      onChanged: (double value) =>
                          update(settings.copyWith(silenceMinDuration: value)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsSilenceMargin,
                    help: strings.helpSilenceMargin,
                    child: ValueSlider(
                      value: settings.silenceMargin,
                      min: kSilenceDurationMin,
                      max: kSilenceDurationMax,
                      step: kSilenceDurationStep,
                      format: _seconds,
                      onChanged: (double value) =>
                          update(settings.copyWith(silenceMargin: value)),
                    ),
                  ),
                ],
              ),
              SettingSection(
                icon: Icons.build_outlined,
                title: strings.settingsAdvanced,
                children: <Widget>[
                  SettingRow(
                    label: strings.settingsCrf,
                    help: strings.helpCrf,
                    child: ValueSlider(
                      value: settings.crf.toDouble(),
                      min: kCrfMin.toDouble(),
                      max: kCrfMax.toDouble(),
                      step: 1,
                      format: (double value) => value.round().toString(),
                      onChanged: (double value) =>
                          update(settings.copyWith(crf: value.round())),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsFps,
                    help: strings.helpFps,
                    child: OptionDropdown<int>(
                      value: settings.fpsIndex,
                      items: _indexItems(kFpsOptions, strings),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(fpsIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsPreset,
                    help: strings.helpPreset,
                    child: OptionDropdown<int>(
                      value: settings.presetIndex,
                      items: _indexItems(kPresets, strings),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(presetIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsAudioRate,
                    child: OptionDropdown<int>(
                      value: settings.audioRateIndex,
                      items: _indexItems(kAudioRates, strings),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(audioRateIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsTune,
                    child: OptionDropdown<int>(
                      value: settings.tuneIndex,
                      items: _indexItems(kTunes, strings),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(tuneIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsPreviewDuration,
                    help: strings.helpPreviewDuration,
                    child: OptionDropdown<int>(
                      value: settings.previewIndex,
                      items: List<DropdownMenuItem<int>>.generate(
                        kPreviewDurations.length,
                        (int index) => DropdownMenuItem<int>(
                          value: index,
                          child: Text(
                            strings.previewSeconds(kPreviewDurations[index]),
                          ),
                        ),
                      ),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(previewIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: strings.settingsFormat,
                    help: strings.helpFormat,
                    child: OptionDropdown<String>(
                      value: settings.outputFormat,
                      items: kFormats
                          .map(
                            (LabeledOption format) => DropdownMenuItem<String>(
                              value: format.value,
                              child: Text(optionText(format, strings)),
                            ),
                          )
                          .toList(),
                      onChanged: (String? format) => format == null
                          ? null
                          : update(settings.copyWith(outputFormat: format)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FilterPreview(settings: settings),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: context.read<PreferencesStore>().resetSettings,
          child: Text(strings.preferenceReset),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.uiClose),
        ),
      ],
    );
  }

  static String _seconds(double value) => '${value.toStringAsFixed(2)}s';

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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
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
