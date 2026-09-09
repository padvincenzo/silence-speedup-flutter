// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Runtime translation store.
///
/// Strings live in `assets/locales/<languageCode>.json` as a flat map of dotted
/// keys — the same shape the Electron app handed to i18next — so translation
/// work carries over between the two projects. Placeholders are `{{name}}`.
///
/// This is a [ChangeNotifier] rather than a `LocalizationsDelegate` because the
/// processing services log localized messages far away from any
/// `BuildContext`; they hold a [Translator] directly.
class Translator extends ChangeNotifier {
  Translator({Locale? initialLocale})
    : _locale = _resolve(initialLocale ?? PlatformDispatcher.instance.locale);

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  static const Locale fallbackLocale = Locale('en');

  static final RegExp _placeholder = RegExp(r'\{\{\s*(\w+)\s*\}\}');

  Locale _locale;
  Map<String, String> _strings = const <String, String>{};
  Map<String, String> _fallback = const <String, String>{};

  Locale get locale => _locale;

  /// Loads the fallback catalogue plus the active one. Call once at startup,
  /// before the first frame, so no widget ever renders raw keys.
  Future<void> load() async {
    _fallback = await _read(fallbackLocale.languageCode);
    _strings = _locale.languageCode == fallbackLocale.languageCode
        ? _fallback
        : await _read(_locale.languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final Locale resolved = _resolve(locale);
    if (resolved == _locale) return;
    _locale = resolved;
    _strings = resolved.languageCode == fallbackLocale.languageCode
        ? _fallback
        : await _read(resolved.languageCode);
    notifyListeners();
  }

  /// Resolves [key], falling back to English and finally to the key itself, so
  /// a missing translation stays visible without crashing the UI.
  String t(String key, [Map<String, Object?> params = const <String, Object?>{}]) {
    final String template = _strings[key] ?? _fallback[key] ?? key;
    if (params.isEmpty) return template;
    return template.replaceAllMapped(_placeholder, (Match match) {
      final Object? value = params[match.group(1)];
      return value?.toString() ?? match.group(0)!;
    });
  }

  static Locale _resolve(Locale locale) {
    for (final Locale supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return fallbackLocale;
  }

  static Future<Map<String, String>> _read(String languageCode) async {
    final String raw = await rootBundle.loadString(
      'assets/locales/$languageCode.json',
    );
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry<String, String>(
        key,
        value.toString(),
      ),
    );
  }
}
