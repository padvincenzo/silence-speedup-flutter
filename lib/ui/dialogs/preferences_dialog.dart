// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/app_paths.dart';
import '../../state/preferences_store.dart';

/// The settings that are not part of a run: where scratch space lives, and
/// what the app does with it.
///
/// The export folder is deliberately absent — it lives on the main window,
/// where the batch is started. The Electron version also asked for a path to
/// `ffmpeg`; there is nothing to ask, because FFmpeg ships inside the app.
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
  late final TextEditingController _working;
  int? _scratchBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _working = TextEditingController(
      text: context.read<PreferencesStore>().workingDirectory,
    );
    _refreshScratchSize();
  }

  @override
  void dispose() {
    _working.dispose();
    super.dispose();
  }

  Future<void> _refreshScratchSize() async {
    final int bytes = await AppPaths.directoryBytes(
      context.read<PreferencesStore>().workingDirectory,
    );
    if (!mounted) return;
    setState(() => _scratchBytes = bytes);
  }

  Future<void> _browse() async {
    final String? chosen = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).preferenceChooseWorkingDir,
      initialDirectory: _working.text.isEmpty ? null : _working.text,
    );
    if (chosen == null || !mounted) return;
    setState(() => _working.text = chosen);
  }

  Future<void> _clearScratch() async {
    setState(() => _clearing = true);
    await AppPaths.emptyDirectory(
      context.read<PreferencesStore>().workingDirectory,
    );
    if (!mounted) return;
    setState(() => _clearing = false);
    await _refreshScratchSize();
  }

  Future<void> _save() async {
    final PreferencesStore preferences = context.read<PreferencesStore>();
    final String directory = _working.text.trim();

    if (directory.isEmpty) {
      await preferences.resetWorkingDirectory();
    } else if (!await AppPaths.ensureDirectory(directory)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).logOutputDirError(directory, ''),
          ),
        ),
      );
      return;
    } else {
      await preferences.setWorkingDirectory(directory);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: const Icon(Icons.settings_outlined),
      title: Text(strings.menuPreferences),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.preferenceWorkingDir,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _working,
                    decoration: InputDecoration(
                      hintText: strings.preferenceWorkingDir,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _browse,
                  icon: const Icon(Icons.folder_open_outlined),
                  tooltip: strings.preferenceChooseWorkingDir,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              strings.preferenceWorkingDirHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
                            strings.preferenceBundledFfmpeg,
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
                            strings.preferenceTemporaryFiles(
                              _scratchBytes == null
                                  ? '…'
                                  : _formatBytes(_scratchBytes!),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              _clearing ||
                                  _scratchBytes == null ||
                                  _scratchBytes == 0
                              ? null
                              : _clearScratch,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 18,
                          ),
                          label: Text(strings.preferenceClearTemporary),
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
            await context.read<PreferencesStore>().resetWorkingDirectory();
            if (!context.mounted) return;
            setState(() {
              _working.text = context.read<PreferencesStore>().workingDirectory;
            });
          },
          child: Text(strings.preferenceReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.uiClose),
        ),
        FilledButton(onPressed: _save, child: Text(strings.preferenceSave)),
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
