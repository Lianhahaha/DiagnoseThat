import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/platform/export_writer.dart';

void main() {
  late Directory root;
  late Directory downloads;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pulse-export-test-');
    downloads = await Directory('${root.path}/Downloads').create();
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  ExportWriter writer({Directory? downloadsDir}) =>
      ExportWriter(downloadsDirectory: () async => downloadsDir);

  test('writes under Downloads/Pulse by default (never Documents)', () async {
    final saved = await writer(downloadsDir: downloads).write(
      fileName: 'a.json',
      bytes: utf8.encode('{}'),
      defaultSubfolder: const ['Pulse', 'exports'],
    );
    expect(
      saved.path,
      [downloads.path, 'Pulse', 'exports', 'a.json']
          .join(Platform.pathSeparator),
    );
    expect(await File(saved.path).readAsString(), '{}');
    expect(saved.summary, 'Saved to ${saved.path}');
  });

  test('uses the folder chosen in Settings', () async {
    final custom = Directory('${root.path}/custom');
    final saved = await writer(downloadsDir: downloads).write(
      fileName: 'a.json',
      bytes: utf8.encode('{}'),
      defaultSubfolder: const ['Pulse'],
      customDirectory: custom.path,
    );
    expect(saved.path, startsWith(custom.path));
  });

  test('a blocked custom folder is explained, not replaced', () async {
    final blockedCustom = File('${root.path}/custom');
    await blockedCustom.writeAsString('not a folder');
    await expectLater(
      writer(downloadsDir: downloads).write(
        fileName: 'a.json',
        bytes: utf8.encode('{}'),
        defaultSubfolder: const ['Pulse'],
        customDirectory: blockedCustom.path,
      ),
      throwsA(
        isA<ExportWriteException>().having(
          (e) => e.message,
          'message',
          contains('Controlled folder access'),
        ),
      ),
    );
  });

  test('explains when Windows reports no Downloads folder', () async {
    await expectLater(
      writer(downloadsDir: null).write(
        fileName: 'a.json',
        bytes: utf8.encode('{}'),
        defaultSubfolder: const ['Pulse', 'exports'],
      ),
      throwsA(isA<ExportWriteException>()),
    );
  });
}
