import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/platform/pulse_service_launcher.dart';

/// The elevated launch runs ShellExecuteEx + WaitForSingleObject on a
/// background isolate (blocking them on the UI thread crashed Pulse.exe).
/// Failures must still arrive as [PulseServiceLaunchException].
void main() {
  test(
    'elevated launch errors cross the isolate as PulseServiceLaunchException',
    () async {
      const launcher = WindowsPulseServiceLauncher();
      final missing =
          '${Directory.systemTemp.path}\\pulse-missing-${DateTime.now().microsecondsSinceEpoch}.exe';

      // A missing file fails inside ShellExecuteEx before any UAC prompt.
      await expectLater(
        launcher.runElevatedAt(
          missing,
          '--status',
          timeout: const Duration(seconds: 5),
        ),
        throwsA(isA<PulseServiceLaunchException>()),
      );
    },
    skip: Platform.isWindows ? false : 'Windows-only',
  );
}
