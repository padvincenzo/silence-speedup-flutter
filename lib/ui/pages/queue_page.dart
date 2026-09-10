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
import '../widgets/output_destination.dart';
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

/// What goes into the queue, what comes out of it, and where.
///
/// One row: the imports, emptying the queue, and the export destination. They
/// were two rows, the second of them given over entirely to a path field that
/// stretched the width of the window — which said the destination mattered
/// more than the queue. It does not.
///
/// A [Wrap] rather than a [Row]: at the smallest window the app allows this
/// does not fit on one line, and it should fold rather than overflow.
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
          TextButton.icon(
            onPressed: queue.canImport && !queue.isEmpty
                ? context.read<QueueStore>().clear
                : null,
            icon: const Icon(Icons.playlist_remove),
            label: Text(strings.menuClearQueue),
          ),
          const OutputDestination(),
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
