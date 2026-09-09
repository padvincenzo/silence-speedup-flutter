// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/speedup_engine.dart';
import '../../state/log_store.dart';
import '../../state/process_store.dart';

/// The status strip pinned to the bottom: elapsed position, encoder speed and
/// percentage over a progress bar, with the log toggle on the left.
class ProgressFooter extends StatelessWidget {
  const ProgressFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final ProcessStore process = context.watch<ProcessStore>();
    final LogStore log = context.watch<LogStore>();
    final RunProgress progress = process.progress;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LinearProgressIndicator(
          value: process.isRunning ? progress.queueFraction : 0,
          minHeight: 4,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: context.read<LogStore>().toggleVisible,
                icon: Icon(log.visible ? Icons.terminal : Icons.terminal_outlined),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: log.visible
                    ? AppLocalizations.of(context).menuHideShell
                    : AppLocalizations.of(context).menuShowShell,
              ),
              if (progress.total > 0)
                Expanded(
                  child: _Metric(
                    label: '${progress.completed}/${progress.total}',
                    value: progress.entryName,
                    flexible: true,
                  ),
                )
              else
                const Spacer(),
              _Metric(
                label: AppLocalizations.of(context).ffmpegTime,
                value: _formatPosition(progress.position),
              ),
              const SizedBox(width: 16),
              _Metric(
                label: AppLocalizations.of(context).ffmpegSpeed,
                value: progress.speed == null || progress.speed == 0
                    ? '-'
                    : '${progress.speed!.toStringAsFixed(1)}x',
              ),
              const SizedBox(width: 16),
              Text(
                progress.fraction == null
                    ? '-.-- %'
                    : '${(progress.fraction! * 100).toStringAsFixed(2)} %',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatPosition(Duration? position) {
    if (position == null) return '--:--:--.--';
    final String hours = position.inHours.toString().padLeft(2, '0');
    final String minutes = position.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = position.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String hundredths = (position.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds.$hundredths';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.flexible = false,
  });

  final String label;
  final String value;

  /// Long values (a file name) get to shrink instead of overflowing.
  final bool flexible;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget valueText = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelMedium?.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        if (flexible) Flexible(child: valueText) else valueText,
      ],
    );
  }
}
