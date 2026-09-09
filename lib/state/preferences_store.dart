// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/translator.dart';
import '../models/processing_settings.dart';
import '../services/app_paths.dart';

/// Everything that survives a restart: the export folder, the look of the app,
/// and the processing settings.
///
/// The Electron app reset its settings on every launch and kept a `config.json`
/// next to the executable; keeping them here means a batch run can be repeated
/// tomorrow without redialling every slider.
class PreferencesStore extends ChangeNotifier {
  PreferencesStore._(this._prefs, this._translator, this._outputDirectory);

  static const String _keyOutputDirectory = 'outputDirectory';
  static const String _keyThemeMode = 'themeMode';
  static const String _keyLocale = 'locale';
  static const String _keySettings = 'processingSettings';

  final SharedPreferences _prefs;
  final Translator _translator;

  String _outputDirectory;
  ThemeMode _themeMode = ThemeMode.system;
  ProcessingSettings _settings = const ProcessingSettings();

  /// Loads persisted state, falling back to sane defaults for anything absent
  /// or corrupt, and applies the stored language to [translator].
  static Future<PreferencesStore> load(Translator translator) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String fallbackDirectory = await AppPaths.defaultOutputDirectory();

    final PreferencesStore store = PreferencesStore._(
      prefs,
      translator,
      prefs.getString(_keyOutputDirectory) ?? fallbackDirectory,
    );

    store._themeMode = _decodeThemeMode(prefs.getString(_keyThemeMode));

    final String? languageCode = prefs.getString(_keyLocale);
    if (languageCode != null) {
      await translator.setLocale(Locale(languageCode));
    }

    final String? rawSettings = prefs.getString(_keySettings);
    if (rawSettings != null) {
      try {
        store._settings = ProcessingSettings.fromJson(
          jsonDecode(rawSettings) as Map<String, dynamic>,
        );
      } catch (error) {
        debugPrint('Discarding unreadable processing settings: $error');
      }
    }

    return store;
  }

  String get outputDirectory => _outputDirectory;

  ThemeMode get themeMode => _themeMode;

  Locale get locale => _translator.locale;

  ProcessingSettings get settings => _settings;

  Future<void> setOutputDirectory(String directory) async {
    if (directory == _outputDirectory) return;
    _outputDirectory = directory;
    notifyListeners();
    await _prefs.setString(_keyOutputDirectory, directory);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_keyThemeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    await _translator.setLocale(locale);
    notifyListeners();
    await _prefs.setString(_keyLocale, _translator.locale.languageCode);
  }

  Future<void> updateSettings(ProcessingSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  /// Puts every processing setting back to its shipped default.
  Future<void> resetSettings() => updateSettings(const ProcessingSettings());

  /// Restores the platform default export folder.
  Future<void> resetOutputDirectory() async {
    await setOutputDirectory(await AppPaths.defaultOutputDirectory());
  }

  static ThemeMode _decodeThemeMode(String? name) {
    return ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }
}
