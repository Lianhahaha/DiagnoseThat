import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/logging/app_logger.dart';
import 'package:pulse/platform/notification_shortcut.dart';

void main() {
  late Directory appData;
  late File shortcut;

  setUp(() {
    appData = Directory.systemTemp.createTempSync('pulse_shortcut_test');
    shortcut = File(
      '${appData.path}\\Microsoft\\Windows\\Start Menu\\Programs\\$kNotificationAppName.lnk',
    )..createSync(recursive: true);
  });

  tearDown(() => appData.deleteSync(recursive: true));

  bool run(String? target) => removeStaleNotificationShortcut(
        logger: AppLogger(),
        appData: appData.path,
        currentExecutable: r'C:\Program Files\Pulse\Pulse.exe',
        readTarget: (_) => target,
      );

  test('removes a shortcut that points to another Pulse.exe', () {
    expect(run(r'C:\dev\old-build\Pulse.exe'), isTrue);
    expect(shortcut.existsSync(), isFalse);
  });

  test('removes a shortcut whose target cannot be read', () {
    expect(run(null), isTrue);
    expect(shortcut.existsSync(), isFalse);
  });

  test('keeps a shortcut that already points to this executable', () {
    expect(run(r'c:\program files\pulse\PULSE.EXE'), isFalse);
    expect(shortcut.existsSync(), isTrue);
  });

  test('outside a Store package there is no package app id', () {
    // flutter test runs unpackaged; the Store build gets
    // "<PackageFamilyName>!pulse" from Windows instead.
    expect(packagedAppUserModelId(), isNull);
  });
}
