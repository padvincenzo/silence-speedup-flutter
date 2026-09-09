// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translator_context.dart';
import '../../services/speedup_engine.dart';
import '../../state/process_store.dart';

/// The slim always-on-top strip the Electron build opened as a second window.
///
/// Flutter desktop runs one window, so instead of a new window the main one is
/// shrunk to this bar — same purpose, and it keeps the run in one place.
class CompactProgressView extends StatelessWidget {
  const CompactProgressView({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final ProcessStore process = context.watch<ProcessStore>();
    final RunProgress progress = process.progress;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // The bar fills behind the text rather than sitting above it, so the
          // strip stays readable at 48 pixels tall.
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.queueFraction.clamp(0.0, 1.0),
              child: ColoredBox(color: scheme.primary.withValues(alpha: 0.22)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                Text(
                  '${progress.completed}/${progress.total}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.entryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  progress.fraction == null
                      ? '-.-- %'
                      : '${(progress.fraction! * 100).toStringAsFixed(1)} %',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => context.read<ProcessStore>().stop(),
                  icon: const Icon(Icons.stop),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t('process.stop'),
                ),
                IconButton(
                  onPressed: onExpand,
                  icon: const Icon(Icons.open_in_full),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.t('menu.windowMode'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
