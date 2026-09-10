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

/// Width the typed path gets when there is a path to type.
///
/// Enough for a folder name and the tail of its parent, which is what anyone
/// checks; the whole path is in the tooltip. It used to take every pixel the
/// window had, which said the destination was the most important thing on the
/// screen. It is not — the queue is.
const double _kPathWidth = 240;

/// The export destination, on the main window rather than behind Preferences.
///
/// Changing where files go is something that happens between one batch and the
/// next, so it belongs where the batch is started — the same place every other
/// remuxer puts it, and on the same row as the buttons that fill the queue.
///
/// It shrink-wraps: the chip alone while exports go beside their source, and
/// the path and its browse button only once a fixed folder is what is wanted.
class OutputDestination extends StatefulWidget {
  const OutputDestination({super.key});

  @override
  State<OutputDestination> createState() => _OutputDestinationState();
}

class _OutputDestinationState extends State<OutputDestination> {
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final bool locked = context.watch<ProcessStore>().isRunning;
    final bool alongside = preferences.exportsAlongsideSource;

    // Keep in step with changes made elsewhere, but never mid-edit.
    if (!_focus.hasFocus && preferences.fixedDirectory != _committed) {
      _committed = preferences.fixedDirectory;
      _controller.text = _committed;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.drive_file_move_outlined,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          strings.outputFolder,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(strings.outputAlongsideSource),
          selected: alongside,
          // What the chip means when it is on. It used to be the hint inside
          // the path field, which is not on screen in that mode any more.
          tooltip: strings.outputFolderHint,
          onSelected: locked
              ? null
              : (bool selected) =>
                    context.read<PreferencesStore>().setOutputMode(
                      selected
                          ? OutputMode.alongsideSource
                          : OutputMode.fixedDirectory,
                    ),
        ),
        // Nothing to show while every file follows its source: a disabled
        // field holding a path that is not being used is just noise.
        if (!alongside) ...<Widget>[
          const SizedBox(width: 8),
          SizedBox(
            width: _kPathWidth,
            child: Tooltip(
              message: _committed,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !locked,
                onSubmitted: (_) => _commit(),
                style: theme.textTheme.bodySmall,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            onPressed: locked ? null : _browse,
            icon: const Icon(Icons.folder_open_outlined),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: strings.outputChooseFolder,
          ),
        ],
      ],
    );
  }
}
