// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silence_speedup/app.dart';
import 'package:silence_speedup/l10n/gen/app_localizations.dart';
import 'package:silence_speedup/l10n/locale_controller.dart';
import 'package:silence_speedup/services/ffmpeg_runner.dart';
import 'package:silence_speedup/state/log_store.dart';
import 'package:silence_speedup/state/preferences_store.dart';
import 'package:silence_speedup/state/process_store.dart';
import 'package:silence_speedup/state/queue_store.dart';
import 'package:silence_speedup/ui/pages/about_page.dart';
import 'package:silence_speedup/ui/pages/settings_page.dart';

/// An [FFmpegRunner] that never touches an encoder.
///
/// The interface exists so the app can be driven without one; this is the
/// fixture that takes advantage of it.
class FakeFFmpegRunner implements FFmpegRunner {
  int cancels = 0;
  final List<List<String>> invocations = <List<String>>[];

  @override
  Future<Duration?> probeDuration(String path) async =>
      const Duration(minutes: 10);

  @override
  Future<FFmpegResult> run(
    List<String> arguments, {
    void Function(String line)? onLine,
    void Function(FFmpegProgress progress)? onProgress,
  }) async {
    invocations.add(arguments);
    return const FFmpegResult(succeeded: true, cancelled: false, exitCode: 0);
  }

  @override
  Future<void> cancel() async => cancels++;
}

/// The five stores the UI reads, wired the way `main` wires them.
class TestHarness {
  TestHarness._(
    this.locales,
    this.preferences,
    this.log,
    this.queue,
    this.process,
    this.runner,
  );

  final LocaleController locales;
  final PreferencesStore preferences;
  final LogStore log;
  final QueueStore queue;
  final ProcessStore process;
  final FakeFFmpegRunner runner;

  static Future<TestHarness> create({Locale? preferred}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final LocaleController locales = await LocaleController.create(
      preferred: preferred,
    );
    final PreferencesStore preferences = await PreferencesStore.load(
      prefs: prefs,
      locales: locales,
    );

    final FakeFFmpegRunner runner = FakeFFmpegRunner();
    final LogStore log = LogStore();
    final QueueStore queue = QueueStore(
      runner: runner,
      log: log,
      locales: locales,
    );
    final ProcessStore process = ProcessStore(
      runner: runner,
      queue: queue,
      preferences: preferences,
      log: log,
      locales: locales,
    );

    return TestHarness._(locales, preferences, log, queue, process, runner);
  }

  List<SingleChildWidget> get providers => <SingleChildWidget>[
    ChangeNotifierProvider<LocaleController>.value(value: locales),
    ChangeNotifierProvider<PreferencesStore>.value(value: preferences),
    ChangeNotifierProvider<LogStore>.value(value: log),
    ChangeNotifierProvider<QueueStore>.value(value: queue),
    ChangeNotifierProvider<ProcessStore>.value(value: process),
  ];

  /// Wraps [child] in the providers and a MaterialApp, for testing one page.
  Widget wrap(Widget child) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        locale: locales.activeLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
  }

  /// The whole app, as `main` assembles it.
  Widget get app => MultiProvider(
    providers: providers,
    child: const SilenceSpeedUpApp(),
  );
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Silence SpeedUp',
      packageName: 'com.padvincenzo.silence_speedup',
      version: '0.9.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  /// A desktop-sized surface, so a layout that only fits on a phone fails.
  Future<void> useDesktopSurface(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('app shell', () {
    testWidgets('opens on the queue with Start and the import actions', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Silence SpeedUp'), findsWidgets);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Add video(s)'), findsOneWidget);
      expect(find.text('Add folder'), findsOneWidget);
      // The queue starts empty, so Start has nothing to do yet.
      expect(
        tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        ).onPressed,
        isNull,
      );
    });

    testWidgets('has no menu bar left over from the Electron build', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(MenuBar), findsNothing);
      // Navigation is a drawer instead.
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('the drawer navigates to settings and to about', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDrawer), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Silence speed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Version 0.9.0'), findsWidgets);
    });

    testWidgets('the speed chip reflects the settings and opens them', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // The defaults are 8x for silences and 1x for speech.
      expect(find.text('8x / 1x'), findsOneWidget);

      await tester.tap(find.text('8x / 1x'));
      await tester.pumpAndSettle();
      expect(find.text('Speech speed'), findsOneWidget);
    });
  });

  group('settings page', () {
    testWidgets('lays out every group with its explanations', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String group in <String>[
        'Speed',
        'Audio',
        'Silence detection',
      ]) {
        expect(find.text(group), findsOneWidget, reason: group);
      }

      // Descriptions are visible text now, not tooltips.
      expect(
        find.textContaining('Pick Remove to cut them out entirely'),
        findsOneWidget,
      );
    });

    testWidgets('scrolls to the application group and shows the toggles', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Application'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    });

    testWidgets('changing a slider writes through to the store', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );
      final int before = harness.preferences.settings.silenceSpeedIndex;

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      // Drag the first slider — silence speed — towards its minimum.
      await tester.drag(find.byType(Slider).first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        harness.preferences.settings.silenceSpeedIndex,
        lessThan(before),
      );
    });

    testWidgets('renders in Italian too', (WidgetTester tester) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('it'),
      );

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Velocità'), findsOneWidget);
      expect(find.text('Velocità dei silenzi'), findsOneWidget);
    });

    testWidgets('fits a narrow window without overflowing', (
      WidgetTester tester,
    ) async {
      // The minimum window size the app allows.
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('about page', () {
    testWidgets('shows the version, credits and licence notice', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(
          AboutPage(version: '0.9.0', onOpenLink: (String _) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Version 0.9.0'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.textContaining('absolutely no warranty'), findsOneWidget);
      expect(find.text('FFmpeg'), findsWidgets);
    });
  });
}
