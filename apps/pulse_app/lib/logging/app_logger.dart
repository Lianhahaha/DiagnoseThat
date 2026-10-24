import 'package:flutter/foundation.dart';

import 'app_log_file.dart';

/// Simple logging abstraction for the Flutter app (TASK-001 / TASK-008).
///
/// Keeps the recent lines in memory (Diagnostics) and, when [file] is set,
/// appends structured JSON lines to disk.
class AppLogger {
  AppLogger({this.file});

  final AppLogFile? file;
  final List<String> lines = [];
  bool debugEnabled = false;

  void info(String component, String message) =>
      _log('info', component, message);
  void warn(String component, String message) =>
      _log('warn', component, message);
  void error(String component, String message) =>
      _log('error', component, message);
  void debug(String component, String message) {
    if (!debugEnabled) return;
    _log('debug', component, message);
  }

  void _log(String level, String component, String message) {
    final now = DateTime.now();
    file?.write(now, level, component, message);
    final line =
        '${now.toIso8601String()} level=$level component=$component message=$message';
    lines.add(line);
    if (lines.length > 2000) {
      lines.removeRange(0, lines.length - 2000);
    }
    // Console only in debug builds, or when the user enables Debug Logging.
    if (kDebugMode || debugEnabled || level == 'error' || level == 'warn') {
      debugPrint(line);
    }
  }
}
