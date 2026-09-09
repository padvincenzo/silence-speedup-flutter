// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';

/// The export destination, on the main window rather than behind Preferences.
///
/// Changing where files go is something that happens between one batch and the
/// next, so it belongs where the batch is started — the same place every other
/// remuxer puts it.
class OutputPathBar extends StatefulWidget {
  const OutputPathBar({super.key});

  @override
  State<OutputPathBar> createState() => _OutputPathBarState();
}

class _OutputPathBarState extends State<OutputPathBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// The value last written to the store, so a rebuild does not fight the user
  /// while they are typing.
  String _committed = '';

  @override
  void initState() {
    super.initState();
    _committed = context.read<PreferencesStore>().fixedDirectory;
    _controller.text = _committed;
    // A typed path is committed when the field loses focus as well as on
    // Enter: leaving the field and pressing Start should not lose the edit.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final String typed = _controller.text.trim();
    if (typed.isEmpty) {
      _controller.text = _committed;
      return;
    }
    if (typed == _committed) return;
    _committed = typed;
    context.read<PreferencesStore>().setFixedDirectory(typed);
  }

  Future<void> _browse() async {
    final PreferencesStore preferences = context.read<PreferencesStore>();
    final String? chosen = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).outputChooseFolder,
      initialDirectory: _committed.isEmpty ? null : _committed,
    );
    if (chosen == null) return;
    _committed = chosen;
    _controller.text = chosen;
    await preferences.setFixedDirectory(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final bool locked = context.watch<ProcessStore>().isRunning;
    final bool alongside = preferences.exportsAlongsideSource;

    // Keep in step with changes made elsewhere, but never mid-edit.
    if (!_focus.hasFocus && preferences.fixedDirectory != _committed) {
      _committed = preferences.fixedDirectory;
      _controller.text = _committed;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.drive_file_move_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            strings.outputFolder,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(strings.outputAlongsideSource),
            selected: alongside,
            onSelected: locked
                ? null
                : (bool selected) =>
                      context.read<PreferencesStore>().setOutputMode(
                        selected
                            ? OutputMode.alongsideSource
                            : OutputMode.fixedDirectory,
                      ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              enabled: !alongside && !locked,
              onSubmitted: (_) => _commit(),
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                hintText: alongside ? strings.outputFolderHint : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: alongside || locked ? null : _browse,
            icon: const Icon(Icons.folder_open_outlined),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: strings.outputChooseFolder,
          ),
        ],
      ),
    );
  }
}
