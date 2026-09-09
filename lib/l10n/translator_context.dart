// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'translator.dart';

extension TranslatorContext on BuildContext {
  /// Translates [key] and subscribes this widget to language changes.
  ///
  /// Only valid inside `build`; use [translator] from callbacks.
  String t(String key, [Map<String, Object?> params = const <String, Object?>{}]) =>
      watch<Translator>().t(key, params);

  /// Non-listening access, for event handlers and async work.
  Translator get translator => read<Translator>();
}
