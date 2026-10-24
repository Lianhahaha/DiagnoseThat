import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/assistant/diagnostic_tool_allowlist.dart';
import 'package:pulse/assistant/ipc_assistant_tool_layer.dart';
import 'package:pulse/ipc/pulse_ipc_client.dart';
import 'package:pulse_protocol/pulse_wire.dart';

/// Serves canned PulseService replies; never opens the pipe.
class _FakeIpc extends PulseIpcClient {
  _FakeIpc({this.details, this.services = const [], this.processes = const []});

  final ProcessDetails? details;
  final List<InventoryServiceEntry> services;
  final List<HealthProcessEntry> processes;

  @override
  Future<ProcessDetails> getProcessDetails(int pid) async => details!;

  @override
  Future<InventoryDomainSnapshot> getInventoryDomain({
    required InventoryDomainId domain,
    bool forceRefresh = false,
    int sinceGeneration = 0,
    int limit = 0,
  }) async {
    expect(domain, InventoryDomainId.services);
    return InventoryDomainSnapshot(domain: domain, services: services);
  }

  @override
  Future<HealthSnapshot> getHealthSnapshot() async =>
      HealthSnapshot(sample: HealthSample(topMemory: processes));

  @override
  Future<void> startHealthMonitoring() async {}

  @override
  Stream<HealthUpdate> get healthUpdates => const Stream.empty();
}

InventoryServiceEntry _service(String id, String name, String state) =>
    InventoryServiceEntry(
      id: id,
      displayName: name,
      state: state,
      startType: 'automatic',
    );

HealthProcessEntry _process(int pid, String name, int workingSet, int private) =>
    HealthProcessEntry(
      pid: pid,
      name: name,
      hasWorkingSetBytes: true,
      workingSetBytes: workingSet,
      hasCommitBytes: true,
      commitBytes: private,
    );

void main() {
  test('process_details returns everything the service collected', () async {
    final layer = IpcAssistantToolLayer(
      ipc: _FakeIpc(
        details: ProcessDetails(
          pid: 4321,
          name: 'chrome.exe',
          path: r'C:\Program Files\Google\Chrome\Application\chrome.exe',
          hasPath: true,
          commandLine: 'chrome.exe --type=renderer --extension-process',
          hasCommandLine: true,
          integrityLevel: 'Low',
          hasIntegrityLevel: true,
          elevated: false,
          hasElevated: true,
          architecture: 'x64',
          hasArchitecture: true,
          productName: 'Google Chrome',
          hasProductName: true,
          createTimeUnixMs: DateTime.utc(2026, 10, 17, 20).millisecondsSinceEpoch,
          hasCreateTime: true,
          cpuTimeMs: 90500,
          hasCpuTime: true,
        ),
      ),
    );

    final result = await layer.invoke('process_details', arguments: {'pid': 4321});

    expect(result.ok, isTrue);
    final data = result.data!;
    expect(data['commandLine'], contains('--extension-process'));
    expect(data['elevated'], isFalse);
    expect(data['architecture'], 'x64');
    expect(data['integrityLevel'], 'Low');
    expect(data['productName'], 'Google Chrome');
    expect(data['startedAt'], '2026-10-17T20:00:00.000Z');
    expect(data['cpuTimeSeconds'], 90.5);
  });

  test('process_details leaves out what the service could not read', () async {
    final layer = IpcAssistantToolLayer(
      ipc: _FakeIpc(details: ProcessDetails(pid: 4, name: 'System')),
    );
    final data = (await layer.invoke('process_details', arguments: {'pid': 4})).data!;
    expect(data.keys, isNot(contains('commandLine')));
    expect(data.keys, isNot(contains('cpuTimeSeconds')));
    expect(data.keys, isNot(contains('elevated')));
  });

  test('process_list sortBy private ranks by private bytes', () async {
    final layer = IpcAssistantToolLayer(
      ipc: _FakeIpc(
        processes: [
          _process(1, 'big-working-set.exe', 900, 100),
          _process(2, 'leaky.exe', 200, 5000),
          _process(3, 'quiet.exe', 100, 50),
        ],
      ),
    );

    final result = await layer.invoke('process_list', arguments: {'sortBy': 'private'});
    final names = [
      for (final p in result.data!['processes'] as List) (p as Map)['name'],
    ];
    expect(names, ['leaky.exe', 'big-working-set.exe', 'quiet.exe']);
    expect(
      ((result.data!['processes'] as List).first as Map)['privateBytes'],
      5000,
    );
  });

  test('windows_services finds Windows Search by name or display name', () async {
    final layer = IpcAssistantToolLayer(
      ipc: _FakeIpc(
        services: [
          _service('WSearch', 'Windows Search', 'running'),
          _service('Spooler', 'Print Spooler', 'stopped'),
          _service('wuauserv', 'Windows Update', 'stopped'),
        ],
      ),
    );

    final search = await layer.invoke('windows_services', arguments: {'query': 'search'});
    expect(search.ok, isTrue);
    expect(search.data!['count'], 1);
    final first = (search.data!['services'] as List).first as Map;
    expect(first['name'], 'WSearch');
    expect(first['state'], 'running');
    expect(first['startType'], 'automatic');

    final stopped = await layer.invoke('windows_services', arguments: {'state': 'stopped'});
    expect(stopped.data!['count'], 2);
  });

  test('windows_services is allowed and cannot start or stop anything', () {
    expect(AssistantToolAllowlist.isAllowed('windows_services'), isTrue);
    expect(AssistantToolAllowlist.looksDangerous('windows_services'), isFalse);
    final schema = AssistantToolAllowlist.tools
        .firstWhere((t) => t.name == 'windows_services')
        .inputSchema;
    expect(
      (schema['properties'] as Map).keys,
      unorderedEquals(['query', 'state', 'limit']),
    );
    expect(AssistantToolAllowlist.isAllowed('stop_service'), isFalse);
  });
}
