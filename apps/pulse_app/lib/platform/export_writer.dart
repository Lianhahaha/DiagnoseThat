import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where an export ended up.
class ExportResult {
  const ExportResult({required this.path});

  final String path;

  String get summary => 'Saved to $path';
}

/// An export that could not be written; [message] is user-facing.
class ExportWriteException implements Exception {
  const ExportWriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Writes exports (reports, Timeline, diagnostics, settings).
///
/// The default location is **Downloads**/Pulse, not Documents. Windows
/// Security's Controlled folder access blocks apps it does not trust (Pulse
/// is not code-signed yet) from writing to Documents and Desktop, and every
/// attempt shows the user a "blocked" alert. Pulse must not work around that
/// protection, so it never tries. Revisit once releases are signed.
///
/// A folder the user chose in Settings is always used as-is; when Windows
/// refuses it, the error says so instead of picking another folder.
class ExportWriter {
  ExportWriter({Future<Directory?> Function()? downloadsDirectory})
      : _downloads = downloadsDirectory ?? getDownloadsDirectory;

  final Future<Directory?> Function() _downloads;

  /// Default export root (Downloads), or null when Windows reports none.
  Future<Directory?> defaultRoot() => _downloads();

  /// Writes [bytes] as [fileName] under [customDirectory] when set, else
  /// under Downloads/[defaultSubfolder].
  Future<ExportResult> write({
    required String fileName,
    required List<int> bytes,
    required List<String> defaultSubfolder,
    String customDirectory = '',
  }) async {
    final custom = customDirectory.trim();
    if (custom.isNotEmpty) {
      try {
        return ExportResult(
          path: await _writeInto(Directory(custom), fileName, bytes),
        );
      } on FileSystemException catch (e) {
        throw ExportWriteException(
          'Windows did not let Pulse write to $custom (${_reason(e)}). '
          'If Controlled folder access is on, allow Pulse in Windows '
          'Security → Ransomware protection, or choose another export '
          'folder in Settings.',
        );
      }
    }

    final root = await _downloads();
    if (root == null) {
      throw const ExportWriteException(
        'Windows did not report a Downloads folder. Choose an export folder '
        'in Settings.',
      );
    }
    try {
      return ExportResult(
        path: await _writeInto(_join(root, defaultSubfolder), fileName, bytes),
      );
    } on FileSystemException catch (e) {
      throw ExportWriteException(
        'Windows did not let Pulse save the export to Downloads '
        '(${_reason(e)}). Choose an export folder in Settings.',
      );
    }
  }

  static Future<String> _writeInto(
    Directory dir,
    String fileName,
    List<int> bytes,
  ) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Directory _join(Directory root, List<String> parts) => Directory(
        [root.path, ...parts].join(Platform.pathSeparator),
      );

  static String _reason(FileSystemException e) {
    final os = e.osError;
    if (os == null) return e.message;
    return 'Windows error ${os.errorCode}';
  }
}
