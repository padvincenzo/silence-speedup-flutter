// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/media_entry.dart';
import '../models/options.dart';
import '../services/update_checker.dart';
import '../state/log_store.dart';
import '../state/process_store.dart';
import '../state/queue_store.dart';
import 'dialogs/about_dialog.dart';
import 'dialogs/preferences_dialog.dart';
import 'dialogs/settings_dialog.dart';
import 'dialogs/update_dialog.dart';
import 'platform.dart';
import 'widgets/app_menu_bar.dart';
import 'widgets/compact_progress_view.dart';
import 'widgets/entry_list.dart';
import 'widgets/log_console.dart';
import 'widgets/output_path_bar.dart';
import 'widgets/progress_footer.dart';
import 'widgets/queue_toolbar.dart';

/// Window size restored when leaving compact mode, if nothing else is known.
const Size _defaultWindowSize = Size(780, 820);
const Size _minimumWindowSize = Size(640, 480);
const Size _compactWindowSize = Size(760, 56);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _version = '';
  AvailableUpdate? _update;
  bool _dragging = false;

  /// Compact state already pushed to the window, so the reconciliation in
  /// `build` does not fire the same resize on every rebuild.
  bool _compactApplied = false;
  Size? _restoreSize;

  @override
  void initState() {
    super.initState();
    _loadVersionAndCheckUpdates();
  }

  Future<void> _loadVersionAndCheckUpdates() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);

    final AvailableUpdate? update = await const UpdateChecker().check(
      info.version,
    );
    if (!mounted || update == null) return;
    setState(() => _update = update);
  }

  MenuActions get _actions => MenuActions(
    openFiles: _openFiles,
    openFolder: _openFolder,
    preferences: () => PreferencesDialog.show(context),
    quit: _quit,
    start: () => context.read<ProcessStore>().start(),
    stop: () => context.read<ProcessStore>().stop(),
    compactMode: () => context.read<ProcessStore>().setCompactMode(true),
    settings: () => SettingsDialog.show(context),
    about: () => AppAboutDialog.show(
      context,
      version: _version,
      onOpenLink: _openLink,
    ),
    license: () => LicenseNoticeDialog.show(context, onOpenLink: _openLink),
    showUpdate: () {
      final AvailableUpdate? update = _update;
      if (update == null) return;
      UpdateDialog.show(context, update: update, onOpenLink: _openLink);
    },
    openLink: _openLink,
  );

  Future<void> _openFiles() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles(
      dialogTitle: AppLocalizations.of(context).fileOpenFile,
      type: FileType.custom,
      allowedExtensions: kImportableExtensions.toList(),
    );
    if (picked.isEmpty || !mounted) return;

    final List<String> paths = picked
        .map((PlatformFile file) => file.path)
        .whereType<String>()
        .toList();
    await context.read<QueueStore>().addFiles(paths);
  }

  Future<void> _openFolder() async {
    final String? directory = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).fileOpenDir,
    );
    if (directory == null || !mounted) return;
    await context.read<QueueStore>().addDirectory(directory);
  }

  Future<void> _openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showMessage(
        AppLocalizations.of(context).logLinkError(url),
      );
    }
  }

  /// Builds a short sample of [entry] and plays it.
  ///
  /// The point of a preview is to hear the result, so the file is opened as
  /// soon as it exists rather than merely reported in the log.
  Future<void> _preview(MediaEntry entry) async {
    final ProcessStore process = context.read<ProcessStore>();
    await process.preview(entry);

    final MediaEntry? finished = process.takeFinishedPreview();
    final String? output = finished?.outputPath;
    if (output == null || !mounted) return;
    await launchUrl(Uri.file(output));
  }

  /// Opens the folder the finished file was written to.
  Future<void> _revealOutput(MediaEntry entry) async {
    final String? output = entry.outputPath;
    if (output == null) return;
    final Uri uri = Uri.file(p.dirname(output));
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      _showMessage(
        AppLocalizations.of(context).logLinkError(p.dirname(output)),
      );
    }
  }

  Future<void> _quit() async {
    final ProcessStore process = context.read<ProcessStore>();
    if (process.isRunning) {
      await process.stop();
    }
    if (isDesktop) {
      await windowManager.destroy();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final QueueStore queue = context.read<QueueStore>();
    if (!queue.canImport) return;

    // desktop_drop tells files and folders apart, so a dropped folder can be
    // walked exactly as Open folder does.
    final List<String> files = <String>[];
    final List<String> directories = <String>[];
    for (final DropItem item in details.files) {
      if (item.path.isEmpty) continue;
      if (item is DropItemDirectory) {
        directories.add(item.path);
      } else {
        files.add(item.path);
      }
    }

    if (files.isNotEmpty) {
      await queue.addFiles(files);
    }
    for (final String directory in directories) {
      await queue.addDirectory(directory);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Shrinks the window to the progress strip, or puts it back.
  Future<void> _applyCompact(bool compact) async {
    if (!isDesktop) return;
    if (compact) {
      _restoreSize = await windowManager.getSize();
      await windowManager.setMinimumSize(const Size(420, 48));
      await windowManager.setSize(_compactWindowSize);
      await windowManager.setResizable(false);
      await windowManager.setAlwaysOnTop(true);
    } else {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(_minimumWindowSize);
      await windowManager.setSize(_restoreSize ?? _defaultWindowSize);
      await windowManager.center();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProcessStore process = context.watch<ProcessStore>();
    final LogStore log = context.watch<LogStore>();

    // Keep the OS window in step with the mode the store reports.
    if (process.compactMode != _compactApplied) {
      _compactApplied = process.compactMode;
      final bool target = _compactApplied;
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration _) => _applyCompact(target),
      );
    }

    if (process.compactMode) {
      return CompactProgressView(
        onExpand: () => context.read<ProcessStore>().setCompactMode(false),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _openFiles,
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          control: true,
          shift: true,
        ): _openFolder,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (process.isRunning) context.read<ProcessStore>().stop();
        },
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): _quit,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: DropTarget(
            enable: context.watch<QueueStore>().canImport,
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (DropDoneDetails details) {
              setState(() => _dragging = false);
              _handleDrop(details);
            },
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    AppMenuBar(
                      actions: _actions,
                      version: _version,
                      update: _update,
                    ),
                    const Divider(),
                    QueueToolbar(actions: _actions),
                    const OutputPathBar(),
                    const Divider(),
                    Expanded(
                      child: EntryList(
                        onRevealOutput: _revealOutput,
                        onPreview: _preview,
                      ),
                    ),
                    if (_update != null) _UpdateBanner(onShow: _actions.showUpdate),
                    const Divider(),
                    const ProgressFooter(),
                    if (log.visible) const LogConsole(),
                  ],
                ),
                if (_dragging) const _DropOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-surface hint shown while a drag is over the window.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: scheme.primary.withValues(alpha: 0.12),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.file_download_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context).uiDropVideo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.onShow});

  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.system_update_alt,
              size: 18,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).menuUpdate,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onShow,
              child: Text(AppLocalizations.of(context).updateDetails),
            ),
          ],
        ),
      ),
    );
  }
}
