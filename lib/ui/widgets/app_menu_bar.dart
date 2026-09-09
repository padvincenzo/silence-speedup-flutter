// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../services/update_checker.dart';
import '../../state/log_store.dart';
import '../../state/preferences_store.dart';
import '../../state/process_store.dart';
import '../../state/queue_store.dart';

/// What the menu bar can trigger. Bundled so the keyboard shortcuts can reuse
/// the same set without duplicating the wiring.
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
/// is what keeps one implementation working on Windows, Linux and macOS alike —
/// the Electron build had to hand its template to the native menu.
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
    final AppLocalizations strings = AppLocalizations.of(context);
    final ProcessStore process = context.watch<ProcessStore>();
    final QueueStore queue = context.watch<QueueStore>();
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final LogStore log = context.watch<LogStore>();

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
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ),
              onPressed: queue.canImport ? actions.openFiles : null,
              child: Text(strings.menuOpenFile),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.folder_open_outlined),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
                shift: true,
              ),
              onPressed: queue.canImport ? actions.openFolder : null,
              child: Text(strings.menuOpenFolder),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.tune),
              onPressed: process.isRunning ? null : actions.settings,
              child: Text(strings.settingsTitle),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.settings_outlined),
              onPressed: process.isRunning ? null : actions.preferences,
              child: Text(strings.menuPreferences),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.power_settings_new),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyQ,
                control: true,
              ),
              onPressed: actions.quit,
              child: Text(strings.menuQuit),
            ),
          ],
          child: Text(strings.menuFile),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.play_arrow),
              onPressed: process.canStart ? actions.start : null,
              child: Text(strings.processStart),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.stop),
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyD,
                control: true,
              ),
              onPressed: process.isRunning ? actions.stop : null,
              child: Text(strings.processStop),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.playlist_remove),
              onPressed: queue.canImport && !queue.isEmpty
                  ? context.read<QueueStore>().clear
                  : null,
              child: Text(strings.menuClearQueue),
            ),
          ],
          child: Text(strings.menuMedia),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              leadingIcon: const Icon(Icons.minimize),
              onPressed: process.isRunning ? actions.compactMode : null,
              child: Text(strings.menuProgress),
            ),
            const Divider(),
            SubmenuButton(
              leadingIcon: const Icon(Icons.brightness_6_outlined),
              menuChildren: <Widget>[
                _ThemeItem(
                  mode: ThemeMode.light,
                  current: preferences.themeMode,
                  label: strings.uiLightMode,
                ),
                _ThemeItem(
                  mode: ThemeMode.dark,
                  current: preferences.themeMode,
                  label: strings.uiDarkMode,
                ),
                _ThemeItem(
                  mode: ThemeMode.system,
                  current: preferences.themeMode,
                  label: strings.uiSystemMode,
                ),
              ],
              child: Text(strings.uiTheme),
            ),
            SubmenuButton(
              leadingIcon: const Icon(Icons.translate),
              menuChildren: <Widget>[
                // Following the system is the default; the two explicit
                // choices pin a language until the user comes back here.
                _LanguageItem(
                  locale: null,
                  current: preferences.preferredLocale,
                  label: strings.uiSystemMode,
                ),
                const _LanguageItemDivider(),
                _LanguageItem(
                  locale: const Locale('en'),
                  current: preferences.preferredLocale,
                  label: 'English',
                ),
                _LanguageItem(
                  locale: const Locale('it'),
                  current: preferences.preferredLocale,
                  label: 'Italiano',
                ),
              ],
              child: Text(strings.uiLanguage),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.terminal),
              onPressed: context.read<LogStore>().toggleVisible,
              child: Text(
                log.visible ? strings.menuHideShell : strings.menuShowShell,
              ),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.cleaning_services_outlined),
              onPressed: log.isEmpty ? null : context.read<LogStore>().clear,
              child: Text(strings.menuCleanShell),
            ),
          ],
          child: Text(strings.menuView),
        ),
        SubmenuButton(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: null,
              child: Text(strings.menuVersion(version)),
            ),
            if (update != null)
              MenuItemButton(
                leadingIcon: const Icon(Icons.system_update_alt),
                onPressed: actions.showUpdate,
                child: Text(strings.menuUpdate),
              ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.info_outline),
              onPressed: actions.about,
              child: Text(strings.menuAbout),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.gavel_outlined),
              onPressed: actions.license,
              child: Text(strings.menuLicense),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.coffee_outlined),
              onPressed: () =>
                  actions.openLink('https://paypal.me/VincenzoPadula'),
              child: Text(strings.menuDonate),
            ),
            const Divider(),
            MenuItemButton(
              leadingIcon: const Icon(Icons.bug_report_outlined),
              onPressed: () => actions.openLink(
                'https://github.com/padvincenzo/silence-speedup-flutter/issues',
              ),
              child: Text(strings.menuIssue),
            ),
            SubmenuButton(
              leadingIcon: const Icon(Icons.link),
              menuChildren: <Widget>[
                MenuItemButton(
                  onPressed: () => actions.openLink(
                    'https://github.com/padvincenzo/silence-speedup-flutter',
                  ),
                  child: Text(strings.menuSourceCode),
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
              child: Text(strings.menuReferences),
            ),
          ],
          child: Text(strings.menuHelp),
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

/// One language choice. A null [locale] means "follow the system".
class _LanguageItem extends StatelessWidget {
  const _LanguageItem({
    required this.locale,
    required this.current,
    required this.label,
  });

  final Locale? locale;

  /// The pinned language, or null while the system decides.
  final Locale? current;

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool selected = locale?.languageCode == current?.languageCode;

    return MenuItemButton(
      leadingIcon: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
      ),
      onPressed: () =>
          context.read<PreferencesStore>().setPreferredLocale(locale),
      child: Text(label),
    );
  }
}

class _LanguageItemDivider extends StatelessWidget {
  const _LanguageItemDivider();

  @override
  Widget build(BuildContext context) => const Divider();
}
