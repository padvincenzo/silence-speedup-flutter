// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translator_context.dart';
import '../../models/media_entry.dart';
import '../../state/process_store.dart';
import '../../state/queue_store.dart';
import '../theme.dart';

/// The queue, or the welcome note when there is nothing in it yet.
class EntryList extends StatelessWidget {
  const EntryList({super.key, required this.onRevealOutput});

  /// Opens the finished file's folder.
  final void Function(MediaEntry entry) onRevealOutput;

  @override
  Widget build(BuildContext context) {
    final QueueStore queue = context.watch<QueueStore>();

    if (queue.isEmpty) return const _EmptyQueueMessage();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: queue.entries.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 4),
      itemBuilder: (BuildContext context, int index) {
        final MediaEntry entry = queue.entries[index];
        return ChangeNotifierProvider<MediaEntry>.value(
          value: entry,
          child: _EntryTile(onRevealOutput: onRevealOutput),
        );
      },
    );
  }
}

class _EmptyQueueMessage extends StatelessWidget {
  const _EmptyQueueMessage();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          color: scheme.secondaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 32,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.t('app.intro'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row: name, status, and the actions that make sense right now.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.onRevealOutput});

  final void Function(MediaEntry entry) onRevealOutput;

  @override
  Widget build(BuildContext context) {
    final MediaEntry entry = context.watch<MediaEntry>();
    final QueueStore queue = context.watch<QueueStore>();
    final ProcessStore process = context.watch<ProcessStore>();
    final StatusPalette palette = StatusPalette.of(context);
    final Color accent = _accentFor(entry.status, palette);

    return Card(
      elevation: 0,
      color: switch (entry.status) {
        EntryStatus.completed || EntryStatus.failed => palette.rowTint(accent),
        _ => Theme.of(context).colorScheme.surfaceContainerLow,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            _StatusIcon(status: entry.status, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Tooltip(
                    message: entry.path,
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLine(context, entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.status == EntryStatus.completed &&
                entry.outputPath != null)
              IconButton(
                onPressed: () => onRevealOutput(entry),
                icon: const Icon(Icons.folder_outlined),
                tooltip: context.t('file.reveal'),
              ),
            if (!process.isRunning)
              IconButton(
                onPressed: entry.isProcessable
                    ? () => context.read<ProcessStore>().analyze(entry)
                    : null,
                icon: const Icon(Icons.graphic_eq),
                tooltip: context.t('file.analyze'),
              ),
            IconButton(
              onPressed: queue.canImport
                  ? () => context.read<QueueStore>().remove(entry)
                  : null,
              icon: const Icon(Icons.delete_outline),
              tooltip: context.t('file.remove'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the second line: the status, plus whatever detail fits with it.
  String _statusLine(BuildContext context, MediaEntry entry) {
    final String status = context.t(_statusKey(entry.status));

    final List<String> parts = <String>[status];

    if (entry.status == EntryStatus.ready && entry.duration != null) {
      return context.t('status.loaded', <String, Object?>{
        'duration': formatDuration(entry.duration!),
      });
    }
    if (entry.detail != null && entry.detail!.isNotEmpty) {
      parts.add(entry.detail!);
    } else if (entry.duration != null) {
      parts.add(formatDuration(entry.duration!));
    }
    return parts.join(' · ');
  }

  static String _statusKey(EntryStatus status) => switch (status) {
    EntryStatus.probing => 'status.loading',
    EntryStatus.ready => 'status.ready',
    EntryStatus.queued => 'status.queued',
    EntryStatus.analyzing => 'status.analyzing',
    EntryStatus.exporting => 'status.exporting',
    EntryStatus.concatenating => 'status.concatenating',
    EntryStatus.completed => 'status.completed',
    EntryStatus.failed => 'status.failed',
    EntryStatus.interrupted => 'status.interrupted',
  };

  static Color _accentFor(EntryStatus status, StatusPalette palette) =>
      switch (status) {
        EntryStatus.completed => palette.success,
        EntryStatus.failed => palette.failure,
        EntryStatus.interrupted => palette.warning,
        EntryStatus.analyzing ||
        EntryStatus.exporting ||
        EntryStatus.concatenating => palette.busy,
        EntryStatus.probing || EntryStatus.ready || EntryStatus.queued =>
          palette.idle,
      };
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.color});

  final EntryStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool busy = switch (status) {
      EntryStatus.probing ||
      EntryStatus.analyzing ||
      EntryStatus.exporting ||
      EntryStatus.concatenating => true,
      _ => false,
    };

    if (busy) {
      return SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    return Icon(
      switch (status) {
        EntryStatus.completed => Icons.check_circle_outline,
        EntryStatus.failed => Icons.error_outline,
        EntryStatus.interrupted => Icons.pause_circle_outline,
        _ => Icons.movie_outlined,
      },
      size: 20,
      color: color,
    );
  }
}

/// `hh:mm:ss` for anything an hour or longer, `mm:ss` otherwise.
String formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final String minutes = duration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final String seconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
