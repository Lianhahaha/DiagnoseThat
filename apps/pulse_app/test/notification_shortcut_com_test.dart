import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/platform/notification_shortcut.dart';
import 'package:win32/win32.dart';

/// Regression: package:win32 releases COM objects from a Finalizer. An extra
/// manual release() freed the ShellLink twice and crashed Pulse.exe shortly
/// after startup, once the GC ran. Exercise the reader and force collections
/// so a double release would crash this test process.
void main() {
  test(
    'reading shortcuts repeatedly survives garbage collection',
    () async {
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      final missing =
          '${Directory.systemTemp.path}\\pulse-no-such-shortcut.lnk';
      for (var round = 0; round < 20; round++) {
        for (var i = 0; i < 50; i++) {
          expect(readShortcutTarget(missing), isNull);
        }
        // Allocate garbage so the GC runs and finalizers fire.
        final junk = List.generate(2000, (_) => Uint8List(4096));
        expect(junk.length, 2000);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    },
    skip: Platform.isWindows ? false : 'Windows-only',
  );
}
