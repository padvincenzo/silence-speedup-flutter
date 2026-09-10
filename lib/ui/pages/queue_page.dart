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
import '../../state/queue_store.dart';
import '../widgets/entry_list.dart';
import '../widgets/log_console.dart';
import '../widgets/progress_footer.dart';

/// Room left below the queue so the floating action button never sits on top
/// of the last row.
const double kQueueBottomInset = 88;

/// The main screen: import, destination and the queue.
///
/// Starting and stopping live on the shell's floating action button, which is
/// where Material puts the one action a screen is for. Progress and the log
/// live in [QueueStatusBar], which the shell puts in the Scaffold's bottom
/// slot so the button has somewhere to float that covers nothing. The rates
/// and the way into the encoding settings are one control in the app bar, so
/// this page carries neither.
class QueuePage extends StatelessWidget {
  const QueuePage({
    super.key,
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onRevealOutput,
    required this.onPreview,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final void Function(MediaEntry entry) onRevealOutput;
  final void Function(MediaEntry entry) onPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Toolbar(onOpenFiles: onOpenFiles, onOpenFolder: onOpenFolder),
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

/// What goes into the queue, and what empties it.
///
/// Kept to what acts on the queue itself. The export destination was here
/// too, in a row of its own with a path field across the whole window; it is
/// a setting about exporting, so it moved to the encoding settings beside
/// the container and the quality. Emptying the queue is an icon: it is done
/// once in a while, and it was an icon in the app bar before it came here.
///
/// A [Wrap] rather than a [Row]: at the smallest window the app allows the
/// labels may not fit on one line, and they should fold rather than overflow.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onOpenFiles, required this.onOpenFolder});

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final QueueStore queue = context.watch<QueueStore>();

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
          IconButton(
            onPressed: queue.canImport && !queue.isEmpty
                ? context.read<QueueStore>().clear
                : null,
            icon: const Icon(Icons.playlist_remove),
            tooltip: strings.menuClearQueue,
          ),
          if (queue.entries.isNotEmpty)
            Text(
              strings.queueCount(queue.entries.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
