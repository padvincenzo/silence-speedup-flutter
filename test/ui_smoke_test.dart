// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/foundation.dart';
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
import 'package:silence_speedup/ui/pages/app_settings_page.dart';
import 'package:silence_speedup/ui/pages/licenses_page.dart';
import 'package:silence_speedup/ui/widgets/compact_progress_view.dart';
import 'package:silence_speedup/ui/widgets/encoding_settings_panel.dart';
import 'package:silence_speedup/ui/widgets/output_destination.dart';
import 'package:silence_speedup/ui/widgets/encoding_settings_view.dart';
import 'package:silence_speedup/ui/theme.dart';

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
  ///
  /// The real theme is installed rather than Flutter's default: the app's
  /// own tile and text styles are part of what these tests are watching.
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        theme: buildAppTheme(brightness),
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

      await tester.tap(find.text('App settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The application page carries what is set once, and nothing that
      // decides how a video is encoded.
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Silence speed'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Version 0.9.0'), findsWidgets);
    });

    testWidgets('one control shows the rates and opens the settings', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // The defaults are 8x for silences and 1x for speech, and there is
      // exactly one place that says so: the app bar button that opens the
      // panel. A second control on the queue used to duplicate it.
      expect(find.text('8x / 1x'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('8x / 1x'),
        ),
        findsOneWidget,
      );

      await harness.preferences.updateSettings(
        harness.preferences.settings.copyWith(silenceSpeedIndex: 4),
      );
      await tester.pumpAndSettle();
      expect(find.text('8x / 1x'), findsNothing);
      expect(find.textContaining('/ 1x'), findsOneWidget);
    });
  });

  group('queue toolbar', () {
    testWidgets('imports and clearing share one row, and nothing else does', (
      WidgetTester tester,
    ) async {
      // Roomy on purpose: the test font draws every glyph as a square of the
      // font size, so these labels are half again as wide here as on screen.
      await useDesktopSurface(tester, size: const Size(1920, 1000));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final double row = tester.getCenter(find.text('Add video(s)')).dy;
      expect(tester.getCenter(find.text('Add folder')).dy, row);
      expect(tester.getCenter(find.byIcon(Icons.playlist_remove)).dy, row);

      // Emptying the queue is an icon here, not a labelled button: it is a
      // once-in-a-while action and the row is for the imports.
      expect(find.text('Clear queue'), findsNothing);

      // The destination is a setting about exporting, and it moved there.
      expect(find.byType(OutputDestination), findsNothing);
    });

    testWidgets('the destination is a setting in the export group', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(1400, 900));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // The panel is docked at this width, with Export closed and nothing
      // to report: exports follow their source unless told otherwise.
      expect(find.byType(OutputDestination), findsNothing);

      await harness.preferences.setFixedDirectory(r'D:\Renders');
      await tester.pumpAndSettle();

      // A chosen folder is a change from the default, so the closed group
      // says so -- by its name, since the whole path would not fit.
      expect(find.text('Export to Renders'), findsOneWidget);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(OutputDestination), findsOneWidget);
      // The path is editable once a folder is what is wanted.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the log has one switch, and it is not in the app bar', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // It lives in the status strip, beside the console it opens.
      expect(find.byIcon(Icons.terminal_outlined), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.terminal_outlined),
        ),
        findsNothing,
      );
      // And so does emptying the queue, which is a queue action.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.playlist_remove),
        ),
        findsNothing,
      );
    });
  });

  group('encoding settings', () {
    testWidgets('are docked beside the queue on a wide window', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(1280, 900));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // Docked from the start: on a window this wide there is no reason to
      // make someone ask for them.
      expect(find.byType(DockedEncodingSettings), findsOneWidget);
      expect(find.text('Silence speed'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Start floats over the queue, not over a setting.
      expect(
        tester.getBottomRight(find.byType(FloatingActionButton)).dx,
        lessThan(tester.getTopLeft(find.byType(DockedEncodingSettings)).dx),
      );

      // Scoped to the app bar: the panel's own header carries the same
      // tooltip, since hiding it is exactly what its close button does.
      Finder barButton(String tooltip) => find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip(tooltip),
      );

      await tester.tap(barButton('Hide the encoding settings'));
      await tester.pumpAndSettle();
      expect(find.byType(DockedEncodingSettings), findsNothing);

      await tester.tap(barButton('Show the encoding settings'));
      await tester.pumpAndSettle();
      expect(find.byType(DockedEncodingSettings), findsOneWidget);
    });

    testWidgets('open as a side sheet on a narrow window, and close again', (
      WidgetTester tester,
    ) async {
      // The minimum window size the app allows.
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byType(DockedEncodingSettings), findsNothing);
      expect(find.text('Silence speed'), findsNothing);

      // The rates chip is the shortcut in: it is what a user looks at
      // before every run anyway.
      await tester.tap(find.text('8x / 1x'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Encoding settings'), findsOneWidget);
      expect(find.text('Silence speed'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Silence speed'), findsNothing);
    });

    testWidgets('closed groups say what was changed inside them', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const EncodingSettingsView()));
      await tester.pumpAndSettle();

      // Only the speeds start open, so the other four groups are one line
      // each -- and with nothing changed, that line is a single word.
      expect(find.text('Default'), findsNWidgets(4));
      expect(find.text('CRF'), findsNothing);

      await harness.preferences.updateSettings(
        harness.preferences.settings.copyWith(crf: 20),
      );
      await tester.pumpAndSettle();

      expect(find.text('Default'), findsNWidgets(3));
      expect(find.text('CRF 20'), findsOneWidget);
      // Still closed: the summary is what it says while shut.
      expect(find.byType(Slider), findsNWidgets(2));
    });

    testWidgets('opening a group reveals its controls, and is remembered', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const EncodingSettingsView()));
      await tester.pumpAndSettle();

      expect(harness.preferences.openEncodingGroups, <String>{'speed'});

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CRF'), findsOneWidget);
      expect(
        harness.preferences.openEncodingGroups,
        containsAll(<String>['speed', 'export']),
      );

      // Closing it puts the summary back and takes the controls away.
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('CRF'), findsNothing);
      expect(harness.preferences.openEncodingGroups, isNot(contains('export')));
    });

    testWidgets('lay out every group with its explanations', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const EncodingSettingsView()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final String group in <String>[
        'Speed',
        'Audio',
        'Silence detection',
        'Export',
        'Preview',
      ]) {
        expect(find.text(group), findsOneWidget, reason: group);
      }

      // Descriptions are visible text, not tooltips -- in the group that
      // starts open, which is the speeds.
      expect(
        find.textContaining('Pick Remove to cut them out entirely'),
        findsOneWidget,
      );
    });

    testWidgets('changing a slider writes through to the store', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );
      final int before = harness.preferences.settings.silenceSpeedIndex;

      await tester.pumpWidget(harness.wrap(const EncodingSettingsView()));
      await tester.pumpAndSettle();

      // Drag the first slider - silence speed - towards its minimum.
      await tester.drag(find.byType(Slider).first, const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        harness.preferences.settings.silenceSpeedIndex,
        lessThan(before),
      );
    });

    testWidgets('render in Italian too', (WidgetTester tester) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('it'),
      );

      await tester.pumpWidget(harness.wrap(const EncodingSettingsView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Velocità'), findsOneWidget);
      expect(find.text('Velocità dei silenzi'), findsOneWidget);
    });

    testWidgets('fit the panel width without overflowing', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      // The panel is the tightest place these tiles ever have to work in:
      // a dropdown beside its label would not fit, so it goes under it.
      await tester.pumpWidget(
        harness.wrap(
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: kEncodingPanelWidth,
              child: EncodingSettingsPanel(onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Export'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('app settings page', () {
    testWidgets('shows the application group and the working directory', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester);
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const AppSettingsPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      // Encoding lives in its own panel now.
      expect(find.text('Speed'), findsNothing);
      expect(find.text('Export'), findsNothing);
    });

    testWidgets('fits a narrow window without overflowing', (
      WidgetTester tester,
    ) async {
      // The minimum window size the app allows.
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(harness.wrap(const AppSettingsPage()));
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

    testWidgets('fits a narrow window without overflowing', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(640, 480));
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
    });
  });

  group('compact progress strip', () {
    testWidgets('fits the height it asks the window for', (
      WidgetTester tester,
    ) async {
      // Exactly the room the strip declares it needs. The window is told to
      // be this tall plus its title bar; when that addition was missing the
      // strip had about twenty pixels and everything in it was clipped.
      await useDesktopSurface(
        tester,
        size: const Size(kCompactWidth, kCompactContentHeight),
      );
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(CompactProgressView(onExpand: () {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    });

    testWidgets('survives being dragged to its narrowest', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(
        tester,
        size: const Size(kCompactMinimumWidth, kCompactContentHeight),
      );
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(CompactProgressView(onExpand: () {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('licences page', () {
    setUp(() {
      // Deterministic contents: the registry would otherwise hold whatever
      // the binding managed to read out of the asset bundle.
      LicenseRegistry.reset();
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks(<String>[
          'silence_speedup',
        ], 'GNU GPL v3 or later');
        yield const LicenseEntryWithLineBreaks(<String>[
          'ffmpeg_kit_flutter_new',
        ], 'LGPL, or GPL with libx264');
        yield const LicenseEntryWithLineBreaks(<String>[
          'ffmpeg_kit_flutter_new',
        ], 'A second notice for the same package');
      });
    });

    tearDown(LicenseRegistry.reset);

    testWidgets('keeps the name and version in view while the list scrolls', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(const LicensesPage(version: '0.9.3')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // A large app bar carries the title twice, collapsed and expanded, and
      // cross-fades between them.
      expect(find.text('Silence SpeedUp 0.9.3'), findsWidgets);
      expect(find.text('2 packages'), findsOneWidget);
      // One package carries two notices, and the row says so.
      expect(find.text('2 licences'), findsOneWidget);

      // The heading is pinned, so scrolling the list past it does not take
      // it away -- which is the whole reason this page exists.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Silence SpeedUp 0.9.3'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the document beside the list on a wide window', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(1400, 900));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(const LicensesPage(version: '0.9.4')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The first package is shown without being asked for, so the pane is
      // never a blank half of the window. Both its notices are there.
      expect(find.textContaining('libx264'), findsOneWidget);
      expect(
        find.textContaining('A second notice for the same package'),
        findsOneWidget,
      );

      // Picking another one swaps the document and leaves the list in place:
      // no route is pushed, so the list is still on screen.
      final Finder inList = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text('silence_speedup'),
      );
      await tester.tap(inList);
      await tester.pumpAndSettle();

      expect(find.textContaining('GNU GPL v3 or later'), findsOneWidget);
      expect(find.textContaining('libx264'), findsNothing);
      expect(find.text('ffmpeg_kit_flutter_new'), findsOneWidget);
    });

    testWidgets('holds the document to a readable width', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(1920, 1000));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(const LicensesPage(version: '0.9.4')),
      );
      await tester.pumpAndSettle();

      // The pane is over 1500 pixels wide here; the licence is not allowed
      // to be, because a line that long cannot be read.
      final Finder document = find.byWidgetPredicate(
        (Widget widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == kLicensesDocumentWidth,
      );
      expect(
        tester.getSize(document).width,
        lessThanOrEqualTo(kLicensesDocumentWidth),
      );
    });

    testWidgets('opens the licence as its own page when narrow', (
      WidgetTester tester,
    ) async {
      await useDesktopSurface(tester, size: const Size(640, 480));
      final TestHarness harness = await TestHarness.create(
        preferred: const Locale('en'),
      );

      await tester.pumpWidget(
        harness.wrap(const LicensesPage(version: '0.9.4')),
      );
      await tester.pumpAndSettle();

      // Nothing is preselected: there is no room to show it.
      expect(find.textContaining('libx264'), findsNothing);

      await tester.tap(find.text('ffmpeg_kit_flutter_new'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('libx264'), findsOneWidget);
      expect(
        find.textContaining('A second notice for the same package'),
        findsOneWidget,
      );
      // The list gave way to the document rather than sitting beside it.
      expect(find.text('silence_speedup'), findsNothing);
    });
  });

  group('theme', () {
    // ListTile installs its subtitle style as a DefaultTextStyle, which
    // replaces the ambient one instead of merging with it. A subtitle style
    // without a colour therefore paints in the engine's default black, which
    // is invisible on a dark surface — every setting's description and every
    // line of the about page went that way once.
    testWidgets('gives tile subtitles a colour in both brightnesses', (
      WidgetTester tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            home: const Scaffold(
              body: ListTile(title: Text('title'), subtitle: Text('detail')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final TextStyle style = DefaultTextStyle.of(
          tester.element(find.text('detail')),
        ).style;
        expect(
          style.color,
          isNotNull,
          reason: 'subtitles have no colour in $brightness',
        );
        expect(
          style.color,
          isNot(buildAppTheme(brightness).colorScheme.surface),
        );
      }
    });

    // Material 3 would tint the app bar's background once content scrolls
    // under it, and that tint is baked into the colour at build time: the
    // bar changed shade in one frame while only its elevation animated.
    // A shadow does animate, so the tint is off and the elevation is not.
    test('an app bar lifts on a shadow rather than changing colour', () {
      for (final Brightness brightness in Brightness.values) {
        final ThemeData theme = buildAppTheme(brightness);
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        expect(theme.appBarTheme.shadowColor, theme.colorScheme.shadow);
        expect(theme.appBarTheme.elevation, 0);
        expect(theme.appBarTheme.scrolledUnderElevation, greaterThan(0));
      }
    });
  });
}
