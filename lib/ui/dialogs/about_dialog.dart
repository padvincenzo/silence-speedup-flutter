// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

import '../../l10n/translator_context.dart';
import '../../services/ffmpeg_runner.dart';

/// Credits, and the licence notice GPLv3 asks a program to display.
class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({
    super.key,
    required this.version,
    required this.onOpenLink,
  });

  final String version;
  final void Function(String url) onOpenLink;

  static Future<void> show(
    BuildContext context, {
    required String version,
    required void Function(String url) onOpenLink,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          AppAboutDialog(version: version, onOpenLink: onOpenLink),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Image.asset('assets/icons/icon.png', width: 40, height: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Silence SpeedUp'),
                Text(
                  context.t('menu.version', <String, Object?>{
                    'version': version,
                  }),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(context.t('help.intro'), style: text.bodyMedium),
              const SizedBox(height: 12),
              Text(
                'Copyright (C) 2025-2026 Vincenzo Padula',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(context.t('help.license'), style: text.bodySmall),
              const SizedBox(height: 16),
              Text(context.t('help.credits'), style: text.titleSmall),
              const SizedBox(height: 8),
              const _FFmpegVersion(),
              const SizedBox(height: 8),
              Text(
                context.t('help.ffmpegNotice'),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(context.t('help.icons'), style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                context.t('help.iconsCredit'),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _LinkChip(
                    label: 'GitHub',
                    icon: Icons.code,
                    onPressed: () => onOpenLink(
                      'https://github.com/padvincenzo/silence-speedup-flutter',
                    ),
                  ),
                  _LinkChip(
                    label: 'FFmpeg',
                    icon: Icons.movie_filter_outlined,
                    onPressed: () => onOpenLink('https://ffmpeg.org/'),
                  ),
                  _LinkChip(
                    label: 'Flutter',
                    icon: Icons.flutter_dash,
                    onPressed: () => onOpenLink('https://flutter.dev/'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Silence SpeedUp',
            applicationVersion: version,
          ),
          child: Text(context.t('menu.thirdPartyLicenses')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('ui.close')),
        ),
      ],
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
        return Text(
          'FFmpeg $value',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

/// The GPLv3 notice, with a link out to the full text.
class LicenseNoticeDialog extends StatelessWidget {
  const LicenseNoticeDialog({super.key, required this.onOpenLink});

  final void Function(String url) onOpenLink;

  static Future<void> show(
    BuildContext context, {
    required void Function(String url) onOpenLink,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          LicenseNoticeDialog(onOpenLink: onOpenLink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.gavel_outlined),
      title: Text(context.t('menu.license')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Silence SpeedUp — Copyright (C) 2025-2026 Vincenzo Padula',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.t('help.gplNotice'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => onOpenLink('https://www.gnu.org/licenses/gpl-3.0.html'),
          child: Text(context.t('help.readLicense')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('ui.close')),
        ),
      ],
    );
  }
}
