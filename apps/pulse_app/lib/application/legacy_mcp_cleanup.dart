import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';

/// Removes what AI Integration (PulseMCP, removed in 1.3 — ADR-013) left on
/// this PC, once:
///
/// * the `pulse` server entry Pulse added to AI client configs (Claude
///   Desktop, Cursor, Windsurf, Cline, VS Code), so those apps stop trying to
///   launch a PulseMCP that no longer exists;
/// * Pulse's own MCP folders (`%LOCALAPPDATA%\Pulse\mcp`, `logs\pulsemcp`).
///
/// Only entries recorded as `registeredByPulse` in Pulse's marker file are
/// touched; servers the user added themselves are left alone. Every edited
/// config is backed up next to the original first.
class LegacyMcpCleanup {
  LegacyMcpCleanup({required this.logger, String? localAppData})
      : _localAppData =
            localAppData ?? Platform.environment['LOCALAPPDATA'] ?? '';

  final AppLogger logger;
  final String _localAppData;

  static const String _component = 'LegacyMcpCleanup';
  static const String _defaultServerKey = 'pulse';

  /// Top-level keys AI clients use for their server maps
  /// (`mcpServers` for most clients, `servers` for VS Code).
  static const List<String> _serverMapKeys = ['mcpServers', 'servers'];

  String get _pulseDir => '$_localAppData\\Pulse';
  String get _mcpDir => '$_pulseDir\\mcp';
  String get _registrationsFile => '$_mcpDir\\client-registrations.json';
  String get _mcpLogsDir => '$_pulseDir\\logs\\pulsemcp';

  /// Runs the cleanup if anything is left; returns the configs it edited.
  Future<List<String>> run() async {
    if (_localAppData.isEmpty) return const [];
    final edited = <String>[];
    try {
      edited.addAll(await _removeRegistrations());
      await _deleteDirectory(_mcpDir);
      await _deleteDirectory(_mcpLogsDir);
    } catch (e) {
      // Never block startup; the user can remove the entries by hand.
      logger.warn(_component, 'Cleanup incomplete: $e');
    }
    return edited;
  }

  Future<List<String>> _removeRegistrations() async {
    final markerFile = File(_registrationsFile);
    if (!await markerFile.exists()) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(await markerFile.readAsString());
    } on FormatException catch (e) {
      logger.warn(_component, 'Unreadable registration marker: $e');
      return const [];
    }
    if (decoded is! Map) return const [];

    final edited = <String>[];
    for (final MapEntry(key: client, value: entry) in decoded.entries) {
      if (entry is! Map || entry['registeredByPulse'] != true) continue;
      final serverKey = entry['serverKey'] as String? ?? _defaultServerKey;
      final paths = <String>{
        if (entry['configPath'] is String) entry['configPath'] as String,
        if (entry['configPaths'] is List)
          ...(entry['configPaths'] as List).whereType<String>(),
      };
      for (final path in paths) {
        try {
          if (await _removeServer(File(path), serverKey)) {
            edited.add(path);
            logger.info(_component, 'Removed Pulse MCP entry for $client: $path');
          }
        } catch (e) {
          logger.warn(_component, 'Could not edit $path ($client): $e');
        }
      }
    }
    return edited;
  }

  /// Removes [serverKey] from the client's server map; false if absent.
  Future<bool> _removeServer(File config, String serverKey) async {
    if (!await config.exists()) return false;
    final text = await config.readAsString();
    if (text.trim().isEmpty) return false;
    final root = jsonDecode(text);
    if (root is! Map) return false;

    var changed = false;
    for (final key in _serverMapKeys) {
      final servers = root[key];
      if (servers is Map && servers.containsKey(serverKey)) {
        servers.remove(serverKey);
        changed = true;
      }
    }
    if (!changed) return false;

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    await config.copy('${config.path}.pulse-backup-$stamp');
    final encoded = const JsonEncoder.withIndent('  ').convert(root);
    final tmp = File('${config.path}.tmp');
    await tmp.writeAsString('$encoded\n');
    await tmp.rename(config.path);
    return true;
  }

  Future<void> _deleteDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      logger.info(_component, 'Deleted $path');
    }
  }
}
