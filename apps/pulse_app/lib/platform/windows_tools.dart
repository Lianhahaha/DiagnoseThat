import 'dart:async';
import 'dart:io';

/// Built-in Windows diagnostic tools DiagnoseThat can open for the user.
///
/// Each entry is Microsoft's own read-only tool for a job DiagnoseThat does
/// not duplicate — kernel counters, driver state, hardware inventory, disk
/// layout — so the palette can send the user straight to the authoritative
/// view while investigating a problem.
enum WindowsTool {
  eventViewer(
    label: 'Event Viewer',
    executable: 'mmc.exe',
    arguments: ['eventvwr.msc'],
    purpose: 'Read the Application, System, and Security event logs',
    keywords: ['events', 'event log', 'eventvwr', 'errors'],
  ),
  reliabilityMonitor(
    label: 'Reliability Monitor',
    executable: 'perfmon.exe',
    arguments: ['/rel'],
    purpose: 'See failures and changes day by day',
    keywords: ['reliability', 'stability', 'crashes', 'history'],
  ),
  resourceMonitor(
    label: 'Resource Monitor',
    executable: 'resmon.exe',
    arguments: [],
    purpose: 'Watch CPU, memory, disk, and network use per process',
    keywords: ['cpu', 'memory', 'disk', 'network', 'usage'],
  ),
  performanceMonitor(
    label: 'Performance Monitor',
    executable: 'perfmon.exe',
    arguments: [],
    purpose: 'Inspect counters, traces, and system activity',
    keywords: ['perfmon', 'counters', 'performance'],
  ),
  deviceManager(
    label: 'Device Manager',
    executable: 'mmc.exe',
    arguments: ['devmgmt.msc'],
    purpose: 'Find hardware errors and driver problems',
    keywords: ['drivers', 'hardware', 'devices', 'driver error'],
  ),
  systemInformation(
    label: 'System Information',
    executable: 'msinfo32.exe',
    arguments: [],
    purpose: 'Full hardware and software summary you can save',
    keywords: ['msinfo32', 'inventory', 'summary', 'specs'],
  ),
  diskManagement(
    label: 'Disk Management',
    executable: 'mmc.exe',
    arguments: ['diskmgmt.msc'],
    purpose: 'Check partitions, volumes, and disk status',
    keywords: ['disk', 'partition', 'volume', 'storage'],
  ),
  services(
    label: 'Services',
    executable: 'mmc.exe',
    arguments: ['services.msc'],
    purpose: 'Inspect service states and startup types',
    keywords: ['service', 'services.msc', 'startup'],
  ),
  directXDiagnostics(
    label: 'DirectX Diagnostic',
    executable: 'dxdiag.exe',
    arguments: [],
    purpose: 'Diagnose display, sound, and input devices',
    keywords: ['dxdiag', 'gpu', 'display', 'sound', 'audio'],
  );

  const WindowsTool({
    required this.label,
    required this.executable,
    required this.arguments,
    required this.purpose,
    required this.keywords,
  });

  /// Menu / palette name of the tool.
  final String label;

  /// Program Windows starts, for example `mmc.exe` or `resmon.exe`.
  final String executable;

  /// Arguments passed to [executable]; `.msc` names are resolved to
  /// `%WINDIR%\System32` by [launch].
  final List<String> arguments;

  /// One line explaining what the tool is for, shown as the palette subtitle.
  final String purpose;

  /// Extra palette search terms beyond `windows` and [label].
  final List<String> keywords;

  /// Starts the tool. Completes as soon as Windows accepts the launch and
  /// throws [ProcessException] when the tool cannot be started, so callers
  /// can surface a failure instead of failing silently.
  Future<void> launch() async {
    final resolved = [
      for (final argument in arguments)
        if (argument.toLowerCase().endsWith('.msc')) _system32(argument)
        else argument,
    ];
    final process = await Process.start(executable, resolved);
    // Detach: the tool keeps running after the palette has moved on.
    unawaited(process.exitCode);
  }

  /// Snap-in console files only load reliably from an absolute path when
  /// started outside a shell.
  static String _system32(String snapIn) {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    return '$windir\\System32\\$snapIn';
  }
}
