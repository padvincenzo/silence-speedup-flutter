// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// A group that collapses to a line about itself.
///
/// A panel beside the queue cannot afford to show thirteen controls at once,
/// and most of them are set once and never touched again. Closed, a group
/// says what it is and what was changed inside it; open, it hands over the
/// controls. The summary disappears while the group is open, because what is
/// inside already shows its own values.
///
/// Shared with the silence list, which is the same idea: a heading that
/// reports, and detail on request.
class CollapsibleGroup extends StatelessWidget {
  const CollapsibleGroup({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onExpanded,
    required this.children,
  });

  final IconData icon;
  final String title;

  /// What the closed group says about itself: for a settings group, what
  /// differs from the shipped defaults. Empty draws one word instead.
  final List<String> summary;

  final bool expanded;
  final ValueChanged<bool> onExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool changed = summary.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: () => onExpanded(!expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!expanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            changed
                                ? summary.join('  ·  ')
                                : strings.settingsDefault,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: changed
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // A dot rather than a count: the summary beside it already
                // says what changed, so this only has to survive the moment
                // the group is open and the summary is gone.
                if (changed && expanded)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.circle, size: 8, color: scheme.primary),
                  ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...children,
        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}
