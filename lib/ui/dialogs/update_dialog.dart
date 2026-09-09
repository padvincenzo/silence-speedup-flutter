// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/update_checker.dart';

/// Tells the user a newer release exists and sends them to it.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.update,
    required this.onOpenLink,
  });

  final AvailableUpdate update;
  final void Function(String url) onOpenLink;

  static Future<void> show(
    BuildContext context, {
    required AvailableUpdate update,
    required void Function(String url) onOpenLink,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          UpdateDialog(update: update, onOpenLink: onOpenLink),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text(AppLocalizations.of(context).menuUpdate),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              update.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).updateAvailable(update.version),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).uiClose),
        ),
        FilledButton.icon(
          onPressed: () => onOpenLink(update.url),
          icon: const Icon(Icons.download),
          label: Text(AppLocalizations.of(context).updateDownload),
        ),
      ],
    );
  }
}
