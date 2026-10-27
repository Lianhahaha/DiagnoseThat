import 'dart:io';

/// Opens [directory] in Windows Explorer. With [createIfMissing] the folder
/// is created first, which suits user data folders such as logs; pass false
/// for folders the app must never create (system crash-dump folders) — those
/// throw [FileSystemException] when they do not exist. Fire-and-forget by
/// design: Explorer's exit code is unreliable (it often returns 1 even on
/// success), so callers should watch for the future's error instead.
Future<void> openDirectory(
  Directory directory, {
  bool createIfMissing = true,
}) async {
  if (!directory.existsSync()) {
    if (!createIfMissing) {
      throw FileSystemException('Folder not found', directory.path);
    }
    directory.createSync(recursive: true);
  }
  await Process.run('explorer.exe', [directory.path]);
}
