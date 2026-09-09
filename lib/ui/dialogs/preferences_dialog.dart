// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translator_context.dart';
import '../../services/app_paths.dart';
import '../../state/preferences_store.dart';

/// Where finished files land, and what to do with the scratch space.
///
/// The Electron version also asked for a path to `ffmpeg`; there is nothing to
/// ask here, because FFmpeg ships inside the app.
class PreferencesDialog extends StatefulWidget {
  const PreferencesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => const PreferencesDialog(),
    );
  }

  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  late final TextEditingController _directory;
  int? _temporaryBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _directory = TextEditingController(
      text: context.read<PreferencesStore>().outputDirectory,
    );
    _refreshTemporarySize();
  }

  @override
  void dispose() {
    _directory.dispose();
    super.dispose();
  }

  Future<void> _refreshTemporarySize() async {
    final int bytes = await AppPaths.temporaryBytes(
      context.read<PreferencesStore>().outputDirectory,
    );
    if (!mounted) return;
    setState(() => _temporaryBytes = bytes);
  }

  Future<void> _browse() async {
    final String? chosen = await FilePicker.getDirectoryPath(
      dialogTitle: context.translator.t('preference.chooseExportDir'),
      initialDirectory: _directory.text.isEmpty ? null : _directory.text,
    );
    if (chosen == null || !mounted) return;
    setState(() => _directory.text = chosen);
  }

  Future<void> _clearTemporary() async {
    setState(() => _clearing = true);
    await AppPaths.clearTemporary(
      context.read<PreferencesStore>().outputDirectory,
    );
    if (!mounted) return;
    setState(() => _clearing = false);
    await _refreshTemporarySize();
  }

  Future<void> _save() async {
    final String directory = _directory.text.trim();
    final PreferencesStore preferences = context.read<PreferencesStore>();

    if (directory.isEmpty) {
      await preferences.resetOutputDirectory();
    } else if (!await AppPaths.ensureDirectory(directory)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.translator.t('log.outputDirError', <String, Object?>{
              'path': directory,
              'error': '',
            }),
          ),
        ),
      );
      return;
    } else {
      await preferences.setOutputDirectory(directory);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.settings_outlined),
      title: Text(context.t('menu.preferences')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.t('preference.exportDir'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _directory,
                    decoration: InputDecoration(
                      hintText: context.t('preference.exportDir'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _browse,
                  icon: const Icon(Icons.folder_open_outlined),
                  tooltip: context.t('preference.chooseExportDir'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.memory, size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('preference.bundledFfmpeg'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.t('preference.temporaryFiles', <String, Object?>{
                              'size': _temporaryBytes == null
                                  ? '…'
                                  : _formatBytes(_temporaryBytes!),
                            }),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              _clearing ||
                                  _temporaryBytes == null ||
                                  _temporaryBytes == 0
                              ? null
                              : _clearTemporary,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: Text(context.t('preference.clearTemporary')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await context.read<PreferencesStore>().resetOutputDirectory();
            if (!context.mounted) return;
            setState(() {
              _directory.text = context
                  .read<PreferencesStore>()
                  .outputDirectory;
            });
          },
          child: Text(context.t('preference.reset')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('ui.close')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(context.t('preference.save')),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
    double value = bytes / 1024;
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
  }
}
