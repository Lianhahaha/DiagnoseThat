import 'dart:io';

import 'folder_opener.dart';

/// Folders Windows fills with crash evidence that DiagnoseThat's read-only
/// collectors cannot reach: kernel dumps after a bugcheck and the reports
/// Windows Error Reporting keeps for application crashes.
abstract final class CrashFolders {
  /// Kernel crash dumps written after a bugcheck (BSOD), usually one per
  /// stop. Opening this is the first step of any blue-screen investigation.
  static Directory minidumps() {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    return Directory('$windir\\Minidump');
  }

  /// Application crash reports collected by Windows Error Reporting —
  /// faulting module, exception code, and the time of each crash.
  static Directory? werReports() {
    final programData = Platform.environment['ProgramData'];
    if (programData == null || programData.isEmpty) return null;
    return Directory('$programData\\Microsoft\\Windows\\WER\\ReportArchive');
  }
}

/// Opens a crash-evidence folder in Explorer without ever creating the
/// folder. Throws [FileSystemException] when the folder does not exist or
/// Windows does not expose its location, so callers can name it in an error.
Future<void> openCrashEvidence(Directory? dir) async {
  if (dir == null) {
    throw const FileSystemException('Folder not available on this system');
  }
  await openDirectory(dir, createIfMissing: false);
}
