// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/ffmpeg_runner.dart';
import '../../services/update_checker.dart';

/// Credits, the licence notice GPLv3 asks a program to display, and the
/// update check.
class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.version,
    required this.onOpenLink,
    this.update,
  });

  final String version;
  final void Function(String url) onOpenLink;
  final AvailableUpdate? update;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            children: <Widget>[
              Image.asset('assets/icons/icon.png', width: 72, height: 72),
              const SizedBox(height: 12),
              Text('Silence SpeedUp', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                strings.menuVersion(version),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                strings.aboutBuiltWith,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        if (update != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              color: scheme.tertiaryContainer,
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  Icons.system_update_alt,
                  color: scheme.onTertiaryContainer,
                ),
                title: Text(
                  strings.menuUpdate,
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
                subtitle: Text(
                  strings.updateAvailable(update!.version),
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
                trailing: FilledButton.icon(
                  onPressed: () => onOpenLink(update!.url),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(strings.updateDownload),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(strings.helpIntro, style: theme.textTheme.bodyMedium),
        ),

        _Heading(strings.helpCredits),
        ListTile(
          leading: const Icon(Icons.memory),
          title: const _FFmpegVersion(),
          subtitle: Text(strings.helpFfmpegNotice),
        ),
        ListTile(
          leading: const Icon(Icons.brush_outlined),
          title: Text(strings.helpIcons),
          subtitle: Text(strings.helpIconsCredit),
          onTap: () => onOpenLink('https://creazilla.com/'),
        ),

        _Heading(strings.menuLicense),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.aboutCopyright,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                strings.helpGplNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => onOpenLink(
                      'https://www.gnu.org/licenses/gpl-3.0.html',
                    ),
                    icon: const Icon(Icons.gavel_outlined, size: 18),
                    label: Text(strings.helpReadLicense),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Silence SpeedUp',
                      applicationVersion: version,
                    ),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: Text(strings.menuThirdPartyLicenses),
                  ),
                ],
              ),
            ],
          ),
        ),

        _Heading(strings.menuReferences),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(strings.menuSourceCode),
          subtitle: const Text('github.com/padvincenzo/silence-speedup-flutter'),
          onTap: () => onOpenLink(
            'https://github.com/padvincenzo/silence-speedup-flutter',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.movie_filter_outlined),
          title: const Text('FFmpeg'),
          subtitle: const Text('ffmpeg.org'),
          onTap: () => onOpenLink('https://ffmpeg.org/'),
        ),
        ListTile(
          leading: const Icon(Icons.flutter_dash),
          title: const Text('Flutter'),
          subtitle: const Text('flutter.dev'),
          onTap: () => onOpenLink('https://flutter.dev/'),
        ),
      ],
    );
  }
}

/// A section heading.
class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Reports the FFmpeg build actually embedded in this app.
class _FFmpegVersion extends StatefulWidget {
  const _FFmpegVersion();

  @override
  State<_FFmpegVersion> createState() => _FFmpegVersionState();
}

class _FFmpegVersionState extends State<_FFmpegVersion> {
  late final Future<String?> _version = FFmpegKitRunner.version();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _version,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String value = switch (snapshot.connectionState) {
          ConnectionState.done => snapshot.data ?? '—',
          _ => '…',
        };
        return Text('FFmpeg $value');
      },
    );
  }
}
