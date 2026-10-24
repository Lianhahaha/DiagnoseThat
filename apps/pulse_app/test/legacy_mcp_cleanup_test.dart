import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/application/legacy_mcp_cleanup.dart';
import 'package:pulse/logging/app_logger.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('pulse_mcp_cleanup'));
  tearDown(() => root.deleteSync(recursive: true));

  File writeJson(String relative, Object value) {
    final file = File('${root.path}\\$relative')..createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(value));
    return file;
  }

  Map<String, dynamic> readJson(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  test('removes only Pulse-created entries and Pulse MCP folders', () async {
    final cursor = writeJson('clients\\cursor\\mcp.json', {
      'mcpServers': {
        'pulse': {'command': 'PulseMCP.exe'},
        'mine': {'command': 'other.exe'},
      },
    });
    final vscode = writeJson('clients\\vscode\\mcp.json', {
      'servers': {
        'pulse': {'command': 'PulseMCP.exe'},
      },
    });
    final userOwned = writeJson('clients\\windsurf\\mcp.json', {
      'mcpServers': {
        'pulse': {'command': 'user-added.exe'},
      },
    });
    writeJson('Pulse\\mcp\\client-registrations.json', {
      'cursor': {
        'registeredByPulse': true,
        'configPath': cursor.path,
        'serverKey': 'pulse',
      },
      'vscode': {
        'registeredByPulse': true,
        'configPaths': [vscode.path],
        'serverKey': 'pulse',
      },
      'windsurf': {
        'registeredByPulse': false,
        'configPath': userOwned.path,
      },
    });
    writeJson('Pulse\\logs\\pulsemcp\\pulsemcp-20261012.jsonl', {});
    writeJson('Pulse\\logs\\app\\pulse-app-2026-10-13.jsonl', {});

    final edited = await LegacyMcpCleanup(
      logger: AppLogger(),
      localAppData: root.path,
    ).run();

    expect(edited, unorderedEquals([cursor.path, vscode.path]));
    expect(readJson(cursor)['mcpServers'], {
      'mine': {'command': 'other.exe'},
    });
    expect(readJson(vscode)['servers'], isEmpty);
    expect(
      readJson(userOwned)['mcpServers'],
      contains('pulse'),
      reason: 'entries Pulse did not create stay untouched',
    );
    expect(
      cursor.parent.listSync().map((e) => e.path).any(
            (p) => p.contains('.pulse-backup-'),
          ),
      isTrue,
    );
    expect(Directory('${root.path}\\Pulse\\mcp').existsSync(), isFalse);
    expect(Directory('${root.path}\\Pulse\\logs\\pulsemcp').existsSync(), isFalse);
    expect(
      Directory('${root.path}\\Pulse\\logs\\app').existsSync(),
      isTrue,
      reason: 'the app log folder is not MCP data',
    );
  });

  test('is a no-op when nothing is left', () async {
    final edited = await LegacyMcpCleanup(
      logger: AppLogger(),
      localAppData: root.path,
    ).run();
    expect(edited, isEmpty);
  });
}
