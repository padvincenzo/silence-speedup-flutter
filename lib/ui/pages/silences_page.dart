// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/media_entry.dart';
import '../../models/processing_settings.dart';
import '../../services/fragment_planner.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import '../format.dart';
import '../widgets/collapsible_group.dart';

/// What the detection found in one video, drawn.
///
/// A percentage in the queue says how much of a file is silence; it does not
/// say whether the silences are three long pauses or four hundred gaps
/// between words, and those want different settings. This shows where they
/// fall, what the run will do to each one, and how long the result will be.
///
/// A route rather than a second window: Flutter desktop has one window — the
/// compact strip shrinks this one rather than opening another — and a
/// timeline wants the full width anyway.
class SilencesPage extends StatelessWidget {
  const SilencesPage({super.key, required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    // The entry is listened to directly rather than through a provider: this
    // is a route of its own, so there is no queue row above it to inherit
    // from, and a re-detection started from here has to redraw the page.
    return ListenableBuilder(
      listenable: entry,
      builder: (BuildContext context, Widget? child) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final ProcessingSettings settings = context
        .watch<PreferencesStore>()
        .settings;

    final List<SilenceRange> ranges = entry.silences;
    final ProcessingSettings? detectedWith = entry.detectedWith;
    final bool stale =
        detectedWith != null && !detectedWith.detectsLike(settings);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              strings.silencesTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ranges.isEmpty
          ? _Empty(message: strings.silencesEmpty)
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: <Widget>[
                if (stale) _StaleNotice(entry: entry),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SilenceTimeline(
                    ranges: ranges,
                    sourceSeconds: entry.seconds,
                  ),
                ),
                _Figures(entry: entry, settings: settings),
                const SizedBox(height: 8),
                _RangeList(entry: entry, settings: settings),
              ],
            ),
    );
  }
}

/// The source as a track, with the silences marked on it.
///
/// Public so a test can find it, and because it is the piece most likely to
/// be wanted somewhere else — a row in the queue, say.
class SilenceTimeline extends StatelessWidget {
  const SilenceTimeline({
    super.key,
    required this.ranges,
    required this.sourceSeconds,
    this.height = 56,
  });

  final List<SilenceRange> ranges;
  final double sourceSeconds;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final TextStyle? scale = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TimelinePainter(
              ranges: ranges,
              sourceSeconds: sourceSeconds,
              track: scheme.surfaceContainerHighest,
              silence: scheme.primary,
              border: scheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(formatDuration(Duration.zero), style: scale),
            Text(
              formatDuration(
                Duration(milliseconds: (sourceSeconds * 1000).round()),
              ),
              style: scale,
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.ranges,
    required this.sourceSeconds,
    required this.track,
    required this.silence,
    required this.border,
  });

  final List<SilenceRange> ranges;
  final double sourceSeconds;
  final Color track;
  final Color silence;
  final Color border;

  /// Narrowest a silence may be drawn.
  ///
  /// A tenth of a second in an hour-long video is a third of a pixel, which
  /// paints as nothing at all. A short pause is exactly what someone opens
  /// this page to look for, so it is widened to stay visible; the numbers
  /// beside it are what to read for the real figure.
  static const double _minimumBlock = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );

    canvas.drawRRect(body, Paint()..color = track);

    if (sourceSeconds > 0) {
      canvas.save();
      canvas.clipRRect(body);

      final Paint fill = Paint()..color = silence;
      for (final SilenceRange range in ranges) {
        final double left = (range.start / sourceSeconds) * size.width;
        final double width = (range.duration / sourceSeconds) * size.width;
        canvas.drawRect(
          Rect.fromLTWH(
            left.clamp(0, size.width),
            0,
            width.clamp(_minimumBlock, size.width),
            size.height,
          ),
          fill,
        );
      }

      canvas.restore();
    }

    canvas.drawRRect(
      body,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.ranges != ranges ||
      old.sourceSeconds != sourceSeconds ||
      old.silence != silence ||
      old.track != track;
}

/// The numbers worth knowing before starting a run.
class _Figures extends StatelessWidget {
  const _Figures({required this.entry, required this.settings});

  final MediaEntry entry;
  final ProcessingSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);

    final double output = FragmentPlanner.outputSeconds(
      silences: entry.silences,
      sourceSeconds: entry.seconds,
      settings: settings,
    );
    final double saved = (entry.seconds - output).clamp(0, entry.seconds);
    final double? share = entry.silenceRatio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: <Widget>[
          _Figure(
            label: strings.silencesTotal,
            value: _duration(entry.silenceSeconds),
          ),
          if (share != null)
            _Figure(
              label: strings.silencesShare,
              value: strings.silencesPercent(share * 100),
            ),
          _Figure(
            label: strings.silencesOutput,
            value: _duration(output),
          ),
          _Figure(label: strings.silencesSaved, value: _duration(saved)),
        ],
      ),
    );
  }

  static String _duration(double seconds) =>
      formatDuration(Duration(milliseconds: (seconds * 1000).round()));
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Every range, behind a heading that reports on them.
///
/// Closed by default: the drawing above answers "how are they spread" in one
/// look, and the list is for when the answer is "one of them is wrong".
class _RangeList extends StatefulWidget {
  const _RangeList({required this.entry, required this.settings});

  final MediaEntry entry;
  final ProcessingSettings settings;

  @override
  State<_RangeList> createState() => _RangeListState();
}

class _RangeListState extends State<_RangeList> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final List<SilenceRange> ranges = widget.entry.silences;

    return CollapsibleGroup(
      icon: Icons.list_alt,
      title: strings.silencesRanges(ranges.length),
      summary: <String>[
        '${strings.silencesTotal} '
            '${formatDuration(Duration(milliseconds: (widget.entry.silenceSeconds * 1000).round()))}',
      ],
      expanded: _open,
      onExpanded: (bool value) => setState(() => _open = value),
      children: <Widget>[
        for (int i = 0; i < ranges.length; i++)
          _RangeTile(
            index: i,
            range: ranges[i],
            settings: widget.settings,
          ),
      ],
    );
  }
}

/// One detected silence.
///
/// A widget of its own because this is where per-range editing will go —
/// nudging a boundary, or excluding one range from the run. `setSilences`
/// already accepts a replacement list, so that is a matter of building the
/// controls, not of changing the model.
class _RangeTile extends StatelessWidget {
  const _RangeTile({
    required this.index,
    required this.range,
    required this.settings,
  });

  final int index;
  final SilenceRange range;
  final ProcessingSettings settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Text(
              '${index + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${_at(range.start)}  →  ${_at(range.end)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          Text(
            strings.settingsSecondsValue(range.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // What the run will do to this one, in the same words the settings
          // use for it.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              speedText(settings.silenceSpeed, strings),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _at(double seconds) =>
      formatDuration(Duration(milliseconds: (seconds * 1000).round()));
}

/// Says the drawing no longer matches the settings, and offers to fix it.
class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.entry});

  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool running = context.watch<ProcessStore>().isRunning;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.update, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.silencesStale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: running
                ? null
                : () => context.read<ProcessStore>().analyze(entry),
            child: Text(strings.silencesRedetect),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
