// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filesystem locations the app needs.
///
/// Kept in one place because this is the part that has to change for Android,
/// where an app cannot write to an arbitrary folder in the user's home.
class AppPaths {
  const AppPaths._();

  /// Folder name used under the user's home directory, matching the Electron
  /// app so an existing install keeps exporting to the same place.
  static const String exportFolderName = 'speededup';

  /// Default export directory: `~/speededup` on desktop, app documents
  /// elsewhere.
  static Future<String> defaultOutputDirectory() async {
    final String? home = _homeDirectory();
    if (home != null) {
      return p.join(home, exportFolderName);
    }
    final Directory documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, exportFolderName);
  }

  static String? _homeDirectory() {
    final Map<String, String> environment = Platform.environment;
    if (Platform.isWindows) {
      final String? profile = environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) return profile;
      final String? drive = environment['HOMEDRIVE'];
      final String? path = environment['HOMEPATH'];
      if (drive != null && path != null) return '$drive$path';
      return null;
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final String? home = environment['HOME'];
      if (home != null && home.isNotEmpty) return home;
    }
    return null;
  }

  /// Makes sure [directory] exists, returning false when it cannot be created.
  static Future<bool> ensureDirectory(String directory) async {
    try {
      await Directory(directory).create(recursive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Total bytes sitting in the scratch directory, for the preferences dialog.
  static Future<int> temporaryBytes(String outputDirectory) async {
    final Directory tmp = Directory(p.join(outputDirectory, 'tmp'));
    if (!await tmp.exists()) return 0;
    int bytes = 0;
    try {
      await for (final FileSystemEntity entity in tmp.list(recursive: true)) {
        if (entity is File) bytes += await entity.length();
      }
    } on FileSystemException {
      // A file vanishing mid-scan is not worth reporting.
    }
    return bytes;
  }

  /// Empties the scratch directory. Only ever touches `<output>/tmp`, which
  /// nothing but this app writes to.
  static Future<void> clearTemporary(String outputDirectory) async {
    final Directory tmp = Directory(p.join(outputDirectory, 'tmp'));
    if (!await tmp.exists()) return;
    await for (final FileSystemEntity entity in tmp.list()) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        // Leave anything the OS still has open; the next run will retry.
      }
    }
  }
}
