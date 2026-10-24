import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/ipc/pulse_ipc_client.dart';
import 'package:win32/win32.dart';

/// Regression: disposing the client must close its pipe handle.
///
/// The old disposeClient killed the worker isolate before it handled
/// "shutdown", so the pipe stayed open (handles belong to the process) and
/// PulseService kept one pipe instance per restart until all were in use.
void main() {
  test(
    'disposeClient closes the pipe so the server sees the hang-up',
    () async {
      final pipeName =
          '\\\\.\\pipe\\PulseIpcShutdownTest-$pid-${DateTime.now().microsecondsSinceEpoch}';
      final server = _createServerPipe(pipeName);
      addTearDown(() => CloseHandle(server));

      final client = PulseIpcClient(pipeName: pipeName);
      await client.start();

      // Wait until the client is connected and has sent ClientHello.
      await _waitFor(() => _bytesAvailable(server) > 0);

      await client.disposeClient();

      // A closed client end makes PeekNamedPipe fail with ERROR_BROKEN_PIPE.
      await _waitFor(() => _bytesAvailable(server) < 0);
    },
    skip: Platform.isWindows ? false : 'Named pipes are Windows-only',
  );
}

int _createServerPipe(String name) {
  final namePtr = name.toNativeUtf16();
  try {
    final handle = CreateNamedPipe(
      namePtr,
      PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
      1,
      64 * 1024,
      64 * 1024,
      0,
      nullptr,
    );
    if (handle == INVALID_HANDLE_VALUE) {
      fail('CreateNamedPipe failed: ${GetLastError()}');
    }
    return handle;
  } finally {
    calloc.free(namePtr);
  }
}

/// Bytes the client has sent (drained so a later hang-up is visible), or -1
/// once the client end is closed. Windows reports ERROR_BROKEN_PIPE only
/// after unread data has been consumed.
int _bytesAvailable(int server) {
  final avail = calloc<DWORD>();
  final buffer = calloc<Uint8>(4096);
  final read = calloc<DWORD>();
  try {
    final ok = PeekNamedPipe(server, nullptr, 0, nullptr, avail, nullptr);
    if (ok == FALSE) {
      return GetLastError() == ERROR_BROKEN_PIPE ? -1 : 0;
    }
    final count = avail.value;
    if (count > 0) {
      ReadFile(server, buffer, count > 4096 ? 4096 : count, read, nullptr);
    }
    return count;
  } finally {
    calloc.free(avail);
    calloc.free(buffer);
    calloc.free(read);
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for pipe state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
