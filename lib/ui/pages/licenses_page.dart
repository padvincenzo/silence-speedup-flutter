// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// The licences of everything the app is built out of.
///
/// Flutter ships a `LicensePage`, and this replaces it. That one scrolls its
/// own heading — the app's name and version — off the top and never brings it
/// back, and there is no way in to change that. Here the heading is a large
/// title that shrinks into the bar as the list moves under it, so what you
/// are reading the licences *of* stays on screen the whole way down.
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key, required this.version});

  /// Shown beside the name, and the reason this page is worth a route of its
  /// own: a licence list is evidence, and evidence needs to say what it is
  /// evidence about.
  final String version;

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<List<_Package>> _packages = _load();

  /// Collects the registry into one entry per package name.
  ///
  /// A single [LicenseEntry] can cover several packages, and one package can
  /// carry several licences, so neither side is a plain list.
  static Future<List<_Package>> _load() async {
    final Map<String, List<LicenseEntry>> byPackage =
        <String, List<LicenseEntry>>{};

    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      for (final String package in entry.packages) {
        byPackage.putIfAbsent(package, () => <LicenseEntry>[]).add(entry);
      }
    }

    final List<String> names = byPackage.keys.toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return names
        .map((String name) => _Package(name, byPackage[name]!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);

    return Scaffold(
      body: FutureBuilder<List<_Package>>(
        future: _packages,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<_Package>> snapshot,
            ) {
              final List<_Package>? packages = snapshot.data;

              return CustomScrollView(
                slivers: <Widget>[
                  _Heading(
                    title: 'Silence SpeedUp ${widget.version}',
                    subtitle: strings.menuThirdPartyLicenses,
                  ),
                  if (packages == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (packages.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(message: strings.licensesEmpty),
                    )
                  else
                    SliverList.separated(
                      itemCount: packages.length + 1,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == packages.length) {
                          return _Count(
                            label: strings.licensesPackages(packages.length),
                          );
                        }
                        final _Package package = packages[index];
                        return ListTile(
                          title: Text(package.name),
                          subtitle: Text(
                            strings.licensesCount(package.entries.length),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  _PackagePage(package: package),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
      ),
    );
  }
}

/// One package and the licences that apply to it.
@immutable
class _Package {
  const _Package(this.name, this.entries);

  final String name;
  final List<LicenseEntry> entries;
}

/// The large title that collapses into the bar instead of scrolling away.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SliverAppBar.large(
      pinned: true,
      // The subtitle rides in the title slot so that both shrink together;
      // it is dropped from the collapsed bar, where there is room for the
      // name and the version and nothing else.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports how much the list holds, under the list.
class _Count extends StatelessWidget {
  const _Count({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
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

/// The licence text of one package, laid out as the registry describes it.
class _PackagePage extends StatelessWidget {
  const _PackagePage({required this.package});

  final _Package package;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          _Heading(
            title: package.name,
            subtitle: strings.licensesCount(package.entries.length),
          ),
          SliverList.builder(
            itemCount: package.entries.length,
            itemBuilder: (BuildContext context, int index) => _LicenseText(
              entry: package.entries[index],
              // A rule between licences, never above the first one.
              separated: index > 0,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _LicenseText extends StatelessWidget {
  const _LicenseText({required this.entry, required this.separated});

  final LicenseEntry entry;
  final bool separated;

  /// Indent step the registry's paragraph levels are drawn with.
  static const double _indent = 12;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.45,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (separated)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Divider(height: 1),
          ),
        for (final LicenseParagraph paragraph in entry.paragraphs)
          Padding(
            padding: EdgeInsets.only(
              left: 16 +
                  (paragraph.indent == LicenseParagraph.centeredIndent
                      ? 0
                      : paragraph.indent * _indent),
              right: 16,
              top: 8,
            ),
            child: Text(
              paragraph.text,
              textAlign: paragraph.indent == LicenseParagraph.centeredIndent
                  ? TextAlign.center
                  : TextAlign.start,
              style: style,
            ),
          ),
      ],
    );
  }
}
