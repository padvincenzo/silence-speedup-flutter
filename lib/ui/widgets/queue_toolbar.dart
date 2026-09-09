// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/options.dart';
import '../../models/processing_settings.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import '../../state/queue_store.dart';
import 'app_menu_bar.dart';

/// The action strip under the menu: import on the left, run controls on the
/// right, with the current speed pair doubling as the way into Settings.
class QueueToolbar extends StatelessWidget {
  const QueueToolbar({super.key, required this.actions});

  final MenuActions actions;

  @override
  Widget build(BuildContext context) {
    final QueueStore queue = context.watch<QueueStore>();
    final ProcessStore process = context.watch<ProcessStore>();
    final PreferencesStore preferences = context.watch<PreferencesStore>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: queue.canImport ? actions.openFiles : null,
            icon: const Icon(Icons.movie_outlined),
            label: Text(AppLocalizations.of(context).menuOpenFile),
          ),
          IconButton.outlined(
            onPressed: queue.canImport ? actions.openFolder : null,
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: AppLocalizations.of(context).menuOpenFolder,
          ),
          const _ToolbarGap(),
          _SpeedSummaryButton(
            settings: preferences.settings,
            onPressed: process.isRunning ? null : actions.settings,
          ),
          if (process.isRunning)
            FilledButton.icon(
              onPressed: actions.stop,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.stop),
              label: Text(AppLocalizations.of(context).processStop),
            )
          else
            FilledButton.icon(
              onPressed: process.canStart ? actions.start : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(AppLocalizations.of(context).processStart),
            ),
          IconButton.outlined(
            onPressed: process.isRunning ? actions.compactMode : null,
            icon: const Icon(Icons.minimize),
            tooltip: AppLocalizations.of(context).menuProgress,
          ),
        ],
      ),
    );
  }
}

class _ToolbarGap extends StatelessWidget {
  const _ToolbarGap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 8);
}

/// Shows the silence and playback rates as `8x / 1x`, the same shorthand the
/// Electron toolbar used, and opens the settings sheet when tapped.
class _SpeedSummaryButton extends StatelessWidget {
  const _SpeedSummaryButton({required this.settings, required this.onPressed});

  final ProcessingSettings settings;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SpeedOption silence = settings.silenceSpeed;
    final SpeedOption playback = settings.playbackSpeed;
    final TextTheme text = Theme.of(context).textTheme;

    final String silenceLabel = silence.isRemove
        ? AppLocalizations.of(context).settingsSpeedRemoveShort
        : silence.label;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.tune),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(silenceLabel, style: text.labelLarge),
          Text(' / ', style: text.labelSmall),
          Text(playback.label, style: text.labelLarge),
        ],
      ),
    );
  }
}
