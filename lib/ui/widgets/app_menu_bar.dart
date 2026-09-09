// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/translator.dart';
import '../../l10n/translator_context.dart';
import '../../services/update_checker.dart';
import '../../state/log_store.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import '../../state/queue_store.dart';

/// What the menu bar can trigger. Bundled so the same set can be reused by the
/// keyboard shortcuts without duplicating the wiring.
@immutable
class MenuActions {
  const MenuActions({
    required this.openFiles,
    required this.openFolder,
    required this.preferences,
    required this.quit,
    required this.start,
    required this.stop,
    required this.compactMode,
    required this.settings,
    required this.about,
    required this.license,
    required this.showUpdate,
    required this.openLink,
  });

  final VoidCallback openFiles;
  final VoidCallback openFolder;
  final VoidCallback preferences;
  final VoidCallback quit;
  final VoidCallback start;
  final VoidCallback stop;
  final VoidCallback compactMode;
  final VoidCallback settings;
  final VoidCallback about;
  final VoidCallback license;
  final VoidCallback showUpdate;
  final void Function(String url) openLink;
}

/// The File / Media / View / Help bar.
///
/// Flutter's [MenuBar] renders in-app rather than in the window chrome, which
/// is what keeps a single implementation working on Windows, Linux and macOS
/// alike — the Electron build had to hand its template to the native menu.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    super.key,
    required this.actions,
    required this.version,
    this.update,
  });

  final MenuActions actions;

  /// Running version, shown as a disabled entry under Help.
  final String version;

  /// Non-null once a newer release has been found.
  final AvailableUpdate? update;

  @override
  Widget build(BuildContext context) {
    final ProcessStore process = context.watch<ProcessStore>();
    final QueueStore queue = context.watch<QueueStore>();
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final LogStore log = context.watch<LogStore>();
    final Locale locale = context.watch<Translator>().locale;

    return MenuBar(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(
          Theme.of(context).colorScheme.surface,
        ),
        elevation: const WidgetStatePropertyAll<double>(0),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
      children: <Widget>[
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.movie_outlined),
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, control: true),
              onPressed: queue.canImport ? actions.openFiles : null,
              child: Text(context.t('menu.openFile')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.folder_open_outlined),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
                shift: true,
              ),
              onPressed: queue.canImport ? actions.openFolder : null,
              child: Text(context.t('menu.openFolder')),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.tune),
              onPressed: process.isRunning ? null : actions.settings,
              child: Text(context.t('settings.title')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.settings_outlined),
              onPressed: process.isRunning ? null : actions.preferences,
              child: Text(context.t('menu.preferences')),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.power_settings_new),
              shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, control: true),
              onPressed: actions.quit,
              child: Text(context.t('menu.quit')),
            ),
          ],
          child: Text(context.t('menu.file')),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.play_arrow),
              onPressed: process.canStart ? actions.start : null,
              child: Text(context.t('process.start')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.stop),
              shortcut: const SingleActivator(LogicalKeyboardKey.keyD, control: true),
              onPressed: process.isRunning ? actions.stop : null,
              child: Text(context.t('process.stop')),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.playlist_remove),
              onPressed: queue.canImport && !queue.isEmpty
                  ? context.read<QueueStore>().clear
                  : null,
              child: Text(context.t('menu.clearQueue')),
            ),
          ],
          child: Text(context.t('menu.media')),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.minimize),
              onPressed: process.isRunning ? actions.compactMode : null,
              child: Text(context.t('menu.progress')),
            ),
            const Divider(),
            SubmenuButton(
              leadingIcon: const Icon(Icons.brightness_6_outlined),
              menuChildren: <Widget>[
                _ThemeItem(
                  mode: ThemeMode.light,
                  current: preferences.themeMode,
                  label: context.t('ui.lightMode'),
                ),
                _ThemeItem(
                  mode: ThemeMode.dark,
                  current: preferences.themeMode,
                  label: context.t('ui.darkMode'),
                ),
                _ThemeItem(
                  mode: ThemeMode.system,
                  current: preferences.themeMode,
                  label: context.t('ui.systemMode'),
                ),
              ],
              child: Text(context.t('ui.theme')),
            ),
            SubmenuButton(
              leadingIcon: const Icon(Icons.translate),
              menuChildren: <Widget>[
                _LanguageItem(
                  code: 'en',
                  current: locale,
                  label: 'English',
                ),
                _LanguageItem(
                  code: 'it',
                  current: locale,
                  label: 'Italiano',
                ),
              ],
              child: Text(context.t('ui.language')),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.terminal),
              onPressed: context.read<LogStore>().toggleVisible,
              child: Text(
                context.t(log.visible ? 'menu.hideShell' : 'menu.showShell'),
              ),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.cleaning_services_outlined),
              onPressed: log.isEmpty ? null : context.read<LogStore>().clear,
              child: Text(context.t('menu.cleanShell')),
            ),
          ],
          child: Text(context.t('menu.view')),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: null,
              child: Text(
                context.t('menu.version', <String, Object?>{'version': version}),
              ),
            ),
            if (update != null)
              MenuItemButton(
                leadingIcon: const Icon(Icons.system_update_alt),
                onPressed: actions.showUpdate,
                child: Text(context.t('menu.update')),
              ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.info_outline),
              onPressed: actions.about,
              child: Text(context.t('menu.about')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.gavel_outlined),
              onPressed: actions.license,
              child: Text(context.t('menu.license')),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.coffee_outlined),
              onPressed: () => actions.openLink('https://paypal.me/VincenzoPadula'),
              child: Text(context.t('menu.donate')),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.bug_report_outlined),
              onPressed: () => actions.openLink(
                'https://github.com/padvincenzo/silence-speedup-flutter/issues',
              ),
              child: Text(context.t('menu.issue')),
            ),
            SubmenuButton(
              leadingIcon: const Icon(Icons.link),
              menuChildren: <Widget>[
                MenuItemButton(
                  onPressed: () => actions.openLink(
                    'https://github.com/padvincenzo/silence-speedup-flutter',
                  ),
                  child: Text(context.t('menu.sourceCode')),
                ),
                MenuItemButton(
                  onPressed: () => actions.openLink('https://ffmpeg.org/'),
                  child: const Text('FFmpeg'),
                ),
                MenuItemButton(
                  onPressed: () => actions.openLink('https://flutter.dev/'),
                  child: const Text('Flutter'),
                ),
              ],
              child: Text(context.t('menu.references')),
            ),
          ],
          child: Text(context.t('menu.help')),
        ),
      ],
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem({
    required this.mode,
    required this.current,
    required this.label,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(
        mode == current ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
      ),
      onPressed: () => context.read<PreferencesStore>().setThemeMode(mode),
      child: Text(label),
    );
  }
}

class _LanguageItem extends StatelessWidget {
  const _LanguageItem({
    required this.code,
    required this.current,
    required this.label,
  });

  final String code;
  final Locale current;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(
        code == current.languageCode
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        size: 18,
      ),
      onPressed: () =>
          context.read<PreferencesStore>().setLocale(Locale(code)),
      child: Text(label),
    );
  }
}
