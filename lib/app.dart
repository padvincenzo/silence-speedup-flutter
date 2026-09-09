// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/translator.dart';
import 'state/preferences_store.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

class SilenceSpeedUpApp extends StatelessWidget {
  const SilenceSpeedUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final PreferencesStore preferences = context.watch<PreferencesStore>();
    final Translator translator = context.watch<Translator>();

    return MaterialApp(
      title: 'Silence SpeedUp',
      debugShowCheckedModeBanner: false,
      themeMode: preferences.themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      locale: translator.locale,
      supportedLocales: Translator.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}
