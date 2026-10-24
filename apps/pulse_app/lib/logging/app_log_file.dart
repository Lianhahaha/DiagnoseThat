import 'dart:convert';
import 'dart:io';

/// Days of daily app log files kept under the log folder.
const int kAppLogRetentionDays = 14;

/// UTF-8 byte order mark written at the start of each new log file.
const List<int> _utf8ByteOrderMark = [0xEF, 0xBB, 0xBF];

/// Daily JSON-lines log file for Pulse.exe, in the same shape as the
/// PulseService log (`timestamp`, `level`, `component`, `message`).
///
/// Lives at `%LOCALAPPDATA%\Pulse\logs\app\pulse-app-YYYY-MM-DD.jsonl`. Writes
/// are synchronous and flushed per line so the last entries survive a crash. Logging must never break the app: I/O failures
/// disable the sink instead of throwing.
class AppLogFile {
  AppLogFile(this.directory);

  final Directory directory;
  RandomAccessFile? _file;
  String? _openDay;
  bool _disabled = false;

  /// Default location, or null when %LOCALAPPDATA% is unavailable.
  static AppLogFile? openDefault() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) return null;
    final sep = Platform.pathSeparator;
    final dir = Directory(
      [localAppData, 'Pulse', 'logs', 'app'].join(sep),
    );
    return AppLogFile(dir)..pruneOldFiles();
  }

  void write(DateTime timestamp, String level, String component, String message) {
    if (_disabled) return;
    try {
      final utc = timestamp.toUtc();
      final day = utc.toIso8601String().substring(0, 10);
      if (_file == null || _openDay != day) {
        _file?.closeSync();
        directory.createSync(recursive: true);
        final path =
            '${directory.path}${Platform.pathSeparator}pulse-app-$day.jsonl';
        _file = File(path).openSync(mode: FileMode.append);
        _openDay = day;
        if (_file!.lengthSync() == 0) {
          // Lines are UTF-8; the byte order mark lets Notepad and
          // PowerShell 5 show localized text instead of assuming ANSI.
          _file!.writeFromSync(_utf8ByteOrderMark);
        }
      }
      final line = jsonEncode({
        'timestamp': utc.toIso8601String(),
        'level': level,
        'component': component,
        'message': message,
      });
      _file!
        ..writeStringSync('$line\n')
        ..flushSync();
    } catch (e) {
      // Disk full / access denied: keep the in-memory log only.
      _disabled = true;
      stderr.writeln('Pulse app log file disabled: $e');
    }
  }

  /// Deletes daily files older than [kAppLogRetentionDays].
  void pruneOldFiles({DateTime? now}) {
    try {
      if (!directory.existsSync()) return;
      final cutoff = (now ?? DateTime.now())
          .toUtc()
          .subtract(const Duration(days: kAppLogRetentionDays));
      final pattern = RegExp(r'^pulse-app-(\d{4}-\d{2}-\d{2})\.jsonl$');
      for (final entity in directory.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final match = pattern.firstMatch(name);
        if (match == null) continue;
        final day = DateTime.tryParse('${match.group(1)}T00:00:00Z');
        if (day != null && day.isBefore(cutoff)) {
          entity.deleteSync();
        }
      }
    } catch (_) {
      // Retention is best effort.
    }
  }

  void close() {
    _file?.closeSync();
    _file = null;
  }
}
