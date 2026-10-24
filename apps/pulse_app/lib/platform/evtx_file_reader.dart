import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../features/timeline/evtx_import.dart';
import 'pulse_service_launcher.dart';

/// Exit codes of `PulseService.exe --read-evtx` (read_evtx_command.hpp).
const int _kReadEvtxReadFailed = 3;

/// A user-facing reason the file could not be opened.
class EvtxImportException implements Exception {
  const EvtxImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens an exported .evtx by running `PulseService.exe --read-evtx` as the
/// current user. The service binary explains each event exactly like live
/// events; nothing is installed, elevated or sent anywhere.
class EvtxFileReader {
  EvtxFileReader({
    this.launcher = const WindowsPulseServiceLauncher(),
    this.timeout = const Duration(minutes: 2),
  });

  final PulseServiceLauncher launcher;
  final Duration timeout;

  Future<EvtxImport> read(String path) async {
    final exe = launcher.resolvePackageServiceExePath();
    if (exe == null) {
      throw const EvtxImportException(
        'PulseService.exe is missing from the Pulse install folder, so the '
        'file cannot be read. Repair Pulse with the installer.',
      );
    }

    final outDir = await Directory.systemTemp.createTemp('pulse-evtx-');
    final outPath = '${outDir.path}${Platform.pathSeparator}events.bin';
    try {
      final ProcessResult result;
      try {
        result = await Process.run(
          exe,
          ['--read-evtx', path, '--out', outPath],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        ).timeout(timeout);
      } on TimeoutException {
        throw const EvtxImportException(
          'Reading the file took too long. Try a smaller export.',
        );
      }

      if (result.exitCode != 0) {
        final reason = (result.stderr as String).trim();
        final detail = reason.isEmpty ? '' : ' ($reason)';
        throw EvtxImportException(
          result.exitCode == _kReadEvtxReadFailed
              ? 'Windows could not read this file as an event log.$detail'
              : 'Pulse could not read the file '
                  '(exit code ${result.exitCode}).$detail',
        );
      }

      final bytes = await File(outPath).readAsBytes();
      final decoded = await Isolate.run(() => decodeEvtxImport(bytes));
      return EvtxImport(
        filePath: path,
        events: decoded.events,
        eventLimit: decoded.eventLimit,
      );
    } on FormatException catch (e) {
      throw EvtxImportException('The import result was damaged: ${e.message}');
    } finally {
      try {
        await outDir.delete(recursive: true);
      } on FileSystemException {
        // Temp folder cleanup is best effort; Windows clears %TEMP% later.
      }
    }
  }
}
