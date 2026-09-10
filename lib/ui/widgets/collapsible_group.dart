// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Height of an open group's heading.
///
/// Fixed, and that is what lets it stick: a pinned sliver has to state its
/// extent up front. An open heading can promise one because it shows only
/// its title — the summary is for when the group is shut, and a shut group
/// has nothing underneath it to stick above.
const double kGroupHeaderHeight = 48;

/// The heading of a group of settings: what it is, and what was changed
/// inside it while it is shut.
///
/// A panel beside the queue cannot afford to show thirteen controls at once,
/// and most of them are set once and never touched again. Shut, a group says
/// what it is and what was changed inside it; open, it hands over the
/// controls and the summary goes away, because what is inside already shows
/// its own values.
class CollapsibleGroupHeader extends StatelessWidget {
  const CollapsibleGroupHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onExpanded,
  });

  final IconData icon;
  final String title;

  /// What the shut group says about itself: for a settings group, what
  /// differs from the shipped defaults. Empty draws one word instead.
  final List<String> summary;

  final bool expanded;
  final ValueChanged<bool> onExpanded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool changed = summary.isNotEmpty;

    return InkWell(
      onTap: () => onExpanded(!expanded),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          expanded ? 0 : 12,
          8,
          expanded ? 0 : 12,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
            // A dot rather than a count: the summary beside it already says
            // what changed, so this only has to survive the moment the group
            // is open and the summary is gone.
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
    );
  }
}

/// The slivers of one group: its heading, and its controls when it is open.
///
/// An open group's heading is pinned, so it stays at the top while the
/// controls it belongs to are still on screen and is pushed off by the next
/// one when they are not — which is the only way to scroll a long panel and
/// still know what is being changed. A shut group is a plain box: there is
/// nothing under it to stick above.
///
/// The pinning is scoped by a [SliverMainAxisGroup] deliberately. Pinned
/// slivers of a viewport *accumulate*: left to themselves, opening every
/// group ends with five headings stacked at the top and no room for the
/// controls. Inside a group the header can only be pinned for as long as
/// that group is on screen, which is what makes the next one push it off.
List<Widget> collapsibleGroupSlivers({
  required BuildContext context,
  required IconData icon,
  required String title,
  required List<String> summary,
  required bool expanded,
  required ValueChanged<bool> onExpanded,
  required List<Widget> children,
  bool lifted = false,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;

  final CollapsibleGroupHeader header = CollapsibleGroupHeader(
    icon: icon,
    title: title,
    summary: summary,
    expanded: expanded,
    onExpanded: onExpanded,
  );

  if (!expanded) {
    return <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            header,
            Divider(height: 1, color: scheme.outlineVariant),
          ],
        ),
      ),
    ];
  }

  return <Widget>[
    SliverMainAxisGroup(
      slivers: <Widget>[
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedGroupHeader(
            child: header,
            background: scheme,
            lifted: lifted,
          ),
        ),
        SliverList(delegate: SliverChildListDelegate(children)),
      ],
    ),
    SliverToBoxAdapter(child: Divider(height: 1, color: scheme.outlineVariant)),
  ];
}

class _PinnedGroupHeader extends SliverPersistentHeaderDelegate {
  const _PinnedGroupHeader({
    required this.child,
    required this.background,
    required this.lifted,
  });

  final Widget child;
  final ColorScheme background;

  /// Whether the list this heading belongs to has been scrolled at all.
  ///
  /// Told from outside, because a pinned header is never told from inside.
  /// The `overlapsContent` the framework hands the delegate means something
  /// else entirely — that *another* pinned sliver is over this one — and it
  /// is false in the case that matters here, which is a group's own controls
  /// sliding beneath its heading.
  final bool lifted;

  @override
  double get minExtent => kGroupHeaderHeight;

  @override
  double get maxExtent => kGroupHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Opaque, and the same colour as the panel: pinned means the controls
    // pass behind it. The shadow is drawn only while something actually is —
    // at the top of an unscrolled panel a heading has content below it, not
    // under it, and a shadow over nothing is not a seam.
    return Material(
      color: background.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: background.shadow,
      elevation: lifted || overlapsContent ? 3 : 0,
      // Filled to the extent the delegate promises. A pinned header reports
      // paintExtent from what its child actually measures and layoutExtent
      // from maxExtent, so a child that does not fill the height it was
      // given makes the two disagree — and the framework asserts.
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(_PinnedGroupHeader old) =>
      old.child != child ||
      old.background != background ||
      old.lifted != lifted;
}
