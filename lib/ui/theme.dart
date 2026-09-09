// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

/// Seed taken from the Bootstrap primary the Electron UI was built on, so the
/// two versions of the app still look related.
const Color _seed = Color(0xFF0D6EFD);

/// Colour reserved for the Start action and for finished rows.
const Color _goColor = Color(0xFF198754);

ThemeData buildAppTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: scheme.surface,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 4,
      showValueIndicator: ShowValueIndicator.never,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, 36),
      ),
    ),
  );
}

/// Palette for the queue's status column, derived from the active scheme so it
/// stays legible in both themes.
class StatusPalette {
  const StatusPalette(this._scheme);

  final ColorScheme _scheme;

  static StatusPalette of(BuildContext context) =>
      StatusPalette(Theme.of(context).colorScheme);

  Color get success => Color.alphaBlend(
    _goColor.withValues(alpha: _scheme.brightness == Brightness.dark ? 0.6 : 1),
    _scheme.surface,
  );

  Color get failure => _scheme.error;

  Color get warning => Color.alphaBlend(
    const Color(0xFFFFC107).withValues(alpha: 0.9),
    _scheme.surface,
  );

  Color get busy => _scheme.primary;

  Color get idle => _scheme.onSurfaceVariant;

  /// Tint used behind a completed or failed row.
  Color rowTint(Color base) => base.withValues(alpha: 0.10);
}
