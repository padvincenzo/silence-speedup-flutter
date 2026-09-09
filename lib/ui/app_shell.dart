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
import 'pages/about_page.dart';
import 'pages/queue_page.dart';
import 'pages/settings_page.dart';
import 'platform.dart';
import 'widgets/app_drawer.dart';
import 'widgets/compact_progress_view.dart';

/// Window size restored when leaving compact mode, if nothing else is known.
const Size _defaultWindowSize = Size(780, 820);
const Size _minimumWindowSize = Size(640, 480);
const Size _compactWindowSize = Size(760, 56);

/// The app's frame: an app bar, a navigation drawer, and one of three pages.
///
/// This replaces the Electron build's menu bar. Nothing was lost by dropping
/// it — the queue actions moved onto the queue, the settings onto a page of
/// their own, and what is genuinely application-level is in the drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _destination = AppDestination.queue;
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

  void _go(AppDestination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
  }

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
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;
      _showMessage(AppLocalizations.of(context).logLinkError(url));
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
    if (!await launchUrl(Uri.file(p.dirname(output)))) {
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

    // A drop is an import, so show it happening.
    _go(AppDestination.queue);

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
    final AppLocalizations strings = AppLocalizations.of(context);
    final ProcessStore process = context.watch<ProcessStore>();

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
          appBar: AppBar(
            title: Text(_titleFor(_destination, strings)),
            actions: _actionsFor(_destination, strings),
          ),
          drawer: AppDrawer(
            destination: _destination,
            onSelect: _go,
            onOpenLink: _openLink,
            onQuit: _quit,
            version: _version,
            update: _update,
          ),
          // The status strip is a bottom bar rather than the last row of the
          // page, which is what keeps the button clear of the readouts.
          bottomNavigationBar: _destination == AppDestination.queue
              ? const QueueStatusBar()
              : null,
          floatingActionButton: _destination == AppDestination.queue
              ? _StartStopButton(
                  onStart: () => context.read<ProcessStore>().start(),
                  onStop: () => context.read<ProcessStore>().stop(),
                )
              : null,
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
                switch (_destination) {
                  AppDestination.queue => QueuePage(
                    onOpenFiles: _openFiles,
                    onOpenFolder: _openFolder,
                    onOpenSettings: () => _go(AppDestination.settings),
                    onRevealOutput: _revealOutput,
                    onPreview: _preview,
                  ),
                  AppDestination.settings => const SettingsPage(),
                  AppDestination.about => AboutPage(
                    version: _version,
                    onOpenLink: _openLink,
                    update: _update,
                  ),
                },
                if (_dragging) const _DropOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleFor(AppDestination destination, AppLocalizations strings) {
    return switch (destination) {
      AppDestination.queue => 'Silence SpeedUp',
      AppDestination.settings => strings.navSettings,
      AppDestination.about => strings.navAbout,
    };
  }

  List<Widget> _actionsFor(
    AppDestination destination,
    AppLocalizations strings,
  ) {
    if (destination != AppDestination.queue) return const <Widget>[];

    final ProcessStore process = context.watch<ProcessStore>();
    final QueueStore queue = context.watch<QueueStore>();
    final LogStore log = context.watch<LogStore>();

    return <Widget>[
      IconButton(
        onPressed: context.read<LogStore>().toggleVisible,
        isSelected: log.visible,
        icon: const Icon(Icons.terminal_outlined),
        selectedIcon: const Icon(Icons.terminal),
        tooltip: log.visible ? strings.menuHideShell : strings.menuShowShell,
      ),
      IconButton(
        onPressed: process.isRunning
            ? () => context.read<ProcessStore>().setCompactMode(true)
            : null,
        icon: const Icon(Icons.picture_in_picture_alt_outlined),
        tooltip: strings.menuProgress,
      ),
      IconButton(
        onPressed: queue.canImport && !queue.isEmpty
            ? context.read<QueueStore>().clear
            : null,
        icon: const Icon(Icons.playlist_remove),
        tooltip: strings.menuClearQueue,
      ),
      const SizedBox(width: 4),
    ];
  }
}

/// The one action the queue screen is for.
class _StartStopButton extends StatelessWidget {
  const _StartStopButton({required this.onStart, required this.onStop});

  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final ProcessStore process = context.watch<ProcessStore>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (process.isRunning) {
      return FloatingActionButton.extended(
        onPressed: onStop,
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
        icon: const Icon(Icons.stop),
        label: Text(strings.processStop),
      );
    }

    // Disabled rather than hidden: it should be obvious that Start is the
    // point of the screen even before anything is queued.
    final bool enabled = process.canStart;
    return FloatingActionButton.extended(
      onPressed: enabled ? onStart : null,
      backgroundColor: enabled ? null : scheme.surfaceContainerHighest,
      foregroundColor: enabled ? null : Theme.of(context).disabledColor,
      icon: const Icon(Icons.play_arrow),
      label: Text(strings.processStart),
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
                borderRadius: BorderRadius.circular(16),
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
