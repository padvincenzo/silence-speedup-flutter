// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translator.dart';
import '../../l10n/translator_context.dart';
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
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final ProcessingSettings settings = preferences.settings;
    final Translator translator = context.watch<Translator>();

    void update(ProcessingSettings next) =>
        context.read<PreferencesStore>().updateSettings(next);

    String label(LabeledOption option) => option.labelKey == null
        ? option.label
        : translator.t(option.labelKey!);

    String speedLabel(int index) {
      final SpeedOption option = kSpeedOptions[index];
      return option.labelKey == null
          ? option.label
          : translator.t(option.labelKey!);
    }

    return AlertDialog(
      icon: const Icon(Icons.tune),
      title: Text(context.t('settings.title')),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SettingSection(
                icon: Icons.bolt,
                title: context.t('settings.basic'),
                children: <Widget>[
                  SettingRow(
                    label: context.t('settings.silenceSpeed'),
                    help: context.t('help.silenceSpeed'),
                    child: IndexSlider(
                      value: settings.silenceSpeedIndex,
                      max: kSpeedOptions.length - 1,
                      labelAt: speedLabel,
                      onChanged: (int index) =>
                          update(settings.copyWith(silenceSpeedIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.playbackSpeed'),
                    help: context.t('help.playbackSpeed'),
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
                    label: context.t('settings.muteSilences'),
                    help: context.t('help.muteSilences'),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: settings.mutesSilence,
                        onChanged: settings.dropsSilence
                            ? null
                            : (bool value) => update(
                                settings.copyWith(muteSilences: value),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              SettingSection(
                icon: Icons.graphic_eq,
                title: context.t('settings.silence'),
                children: <Widget>[
                  SettingRow(
                    label: context.t('settings.backgroundNoise'),
                    help: context.t('help.backgroundNoise'),
                    child: IndexSlider(
                      value: settings.thresholdIndex,
                      max: kThresholds.length - 1,
                      labelAt: (int index) => label(kThresholds[index]),
                      onChanged: (int index) =>
                          update(settings.copyWith(thresholdIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.silenceMinDuration'),
                    help: context.t('help.silenceMinDuration'),
                    child: ValueSlider(
                      value: settings.silenceMinDuration,
                      min: kSilenceDurationMin,
                      max: kSilenceDurationMax,
                      step: kSilenceDurationStep,
                      format: _seconds,
                      onChanged: (double value) => update(
                        settings.copyWith(silenceMinDuration: value),
                      ),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.silenceMargin'),
                    help: context.t('help.silenceMargin'),
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
                title: context.t('settings.advanced'),
                children: <Widget>[
                  SettingRow(
                    label: context.t('settings.crf'),
                    help: context.t('help.crf'),
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
                    label: context.t('settings.fps'),
                    help: context.t('help.fps'),
                    child: OptionDropdown<int>(
                      value: settings.fpsIndex,
                      items: _indexItems(kFpsOptions, label),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(fpsIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.preset'),
                    help: context.t('help.preset'),
                    child: OptionDropdown<int>(
                      value: settings.presetIndex,
                      items: _indexItems(kPresets, label),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(presetIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.audioRate'),
                    child: OptionDropdown<int>(
                      value: settings.audioRateIndex,
                      items: _indexItems(kAudioRates, label),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(audioRateIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.tune'),
                    child: OptionDropdown<int>(
                      value: settings.tuneIndex,
                      items: _indexItems(kTunes, label),
                      onChanged: (int? index) => index == null
                          ? null
                          : update(settings.copyWith(tuneIndex: index)),
                    ),
                  ),
                  SettingRow(
                    label: context.t('settings.format'),
                    help: context.t('help.format'),
                    child: OptionDropdown<String>(
                      value: settings.outputFormat,
                      items: kFormats
                          .map(
                            (LabeledOption format) =>
                                DropdownMenuItem<String>(
                                  value: format.value,
                                  child: Text(label(format)),
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
          child: Text(context.t('preference.reset')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('ui.close')),
        ),
      ],
    );
  }

  static String _seconds(double value) => '${value.toStringAsFixed(2)}s';

  static List<DropdownMenuItem<int>> _indexItems(
    List<LabeledOption> options,
    String Function(LabeledOption option) label,
  ) {
    return List<DropdownMenuItem<int>>.generate(
      options.length,
      (int index) => DropdownMenuItem<int>(
        value: index,
        child: Text(label(options[index])),
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
            context.t('settings.filterPreview'),
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
