// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../models/media_entry.dart';
import '../../state/log_store.dart';
import '../../state/preferences_store.dart';
import '../../state/queue_store.dart';
import '../widgets/entry_list.dart';
import '../widgets/log_console.dart';
import '../widgets/output_path_bar.dart';
import '../widgets/progress_footer.dart';

/// Room left below the queue so the floating action button never sits on top
/// of the last row.
const double kQueueBottomInset = 88;

/// The main screen: import, destination and the queue.
///
/// Starting and stopping live on the shell's floating action button, which is
/// where Material puts the one action a screen is for. Progress and the log
/// live in [QueueStatusBar], which the shell puts in the Scaffold's bottom
/// slot so the button has somewhere to float that covers nothing.
class QueuePage extends StatelessWidget {
  const QueuePage({
    super.key,
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onOpenEncoding,
    required this.onRevealOutput,
    required this.onPreview,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenEncoding;
  final void Function(MediaEntry entry) onRevealOutput;
  final void Function(MediaEntry entry) onPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ImportBar(
          onOpenFiles: onOpenFiles,
          onOpenFolder: onOpenFolder,
          onOpenEncoding: onOpenEncoding,
        ),
        const OutputPathBar(),
        const Divider(),
        Expanded(
          child: EntryList(
            onRevealOutput: onRevealOutput,
            onPreview: onPreview,
          ),
        ),
      ],
    );
  }
}

/// The status strip pinned under the queue: progress, and the log when it is
/// showing.
class QueueStatusBar extends StatelessWidget {
  const QueueStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bool logVisible = context.watch<LogStore>().visible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Divider(),
        const ProgressFooter(),
        if (logVisible) const LogConsole(),
      ],
    );
  }
}

/// Import buttons, plus the current rates as a way into the settings.
class _ImportBar extends StatelessWidget {
  const _ImportBar({
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onOpenEncoding,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenEncoding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final QueueStore queue = context.watch<QueueStore>();
    final PreferencesStore preferences = context.watch<PreferencesStore>();

    final String silence = preferences.settings.silenceSpeed.isRemove
        ? strings.settingsSpeedRemoveShort
        : preferences.settings.silenceSpeed.label;
    final String playback = preferences.settings.playbackSpeed.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: queue.canImport ? onOpenFiles : null,
            icon: const Icon(Icons.movie_outlined),
            label: Text(strings.menuOpenFile),
          ),
          OutlinedButton.icon(
            onPressed: queue.canImport ? onOpenFolder : null,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(strings.menuOpenFolder),
          ),
          const SizedBox(width: 4),
          // Glanceable state that doubles as the way into the encoding
          // settings: the two rates are what a user checks before every run.
          // It stays live during a run, when reading them still helps even
          // though the panel will not let them be changed.
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: Text('$silence / $playback'),
            tooltip: strings.settingsEncodingTitle,
            onPressed: onOpenEncoding,
          ),
          if (queue.entries.isNotEmpty)
            Text(
              strings.queueCount(queue.entries.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
