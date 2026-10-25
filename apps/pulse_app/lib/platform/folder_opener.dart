import 'dart:io';

/// Opens [directory] in Windows Explorer, creating it first when it is
/// missing. Fire-and-forget by design: Explorer's exit code is unreliable
/// (it often returns 1 even on success), so callers that care should watch
/// for the future's error rather than the exit code.
Future<void> openDirectory(Directory directory) async {
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  await Process.run('explorer.exe', [directory.path]);
}
