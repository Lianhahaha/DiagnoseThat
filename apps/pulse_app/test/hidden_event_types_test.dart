import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pulse/app/theme/pulse_theme.dart';
import 'package:pulse/application/connection_controller.dart';
import 'package:pulse/application/evtx_import_controller.dart';
import 'package:pulse/application/settings_controller.dart';
import 'package:pulse/application/timeline_library_controller.dart';
import 'package:pulse/application/timeline_session_controller.dart';
import 'package:pulse/features/timeline/evtx_import.dart';
import 'package:pulse/features/timeline/hidden_event_types.dart';
import 'package:pulse/ipc/pulse_ipc_client.dart';
import 'package:pulse/logging/app_logger.dart';
import 'package:pulse/platform/evtx_file_reader.dart';
import 'package:pulse/presentation/timeline/timeline_page.dart';
import 'package:pulse_protocol/pulse_wire.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The SBAT update failure from issue #21, which a PC can log every boot.
TimelineEvent _sbatFailure(String id, {String provider = 'Microsoft-Windows-TPM-WMI'}) =>
    TimelineEvent(
      eventId: id,
      timestampUnixMs: DateTime.now().millisecondsSinceEpoch,
      severity: Severity.error,
      channel: 'System',
      providerName: provider,
      winEventId: 1796,
      title: 'Secure Boot SBAT update failed',
    );

TimelineEvent _serviceCrash() => TimelineEvent(
      eventId: 'scm-7031',
      timestampUnixMs: DateTime.now().millisecondsSinceEpoch,
      severity: Severity.error,
      channel: 'System',
      providerName: 'Service Control Manager',
      winEventId: 7031,
      title: 'A service stopped unexpectedly',
    );

class _FakeReader implements EvtxFileReader {
  _FakeReader(this.events);
  final List<TimelineEvent> events;

  @override
  Future<EvtxImport> read(String path) async =>
      EvtxImport(filePath: path, events: events, eventLimit: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<TimelineLibraryController> _library() async {
  final library = TimelineLibraryController(logger: AppLogger());
  await library.load();
  return library;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a type is provider + Event ID, provider case-insensitive', () {
    expect(
      hiddenEventTypeKeyOf(_sbatFailure('a')),
      hiddenEventTypeKeyOf(_sbatFailure('b', provider: 'microsoft-windows-tpm-wmi')),
    );
    expect(hiddenEventTypeKeyOf(_sbatFailure('a')),
        isNot(hiddenEventTypeKeyOf(_serviceCrash())));
    // Nothing to match on: such an event cannot be hidden.
    expect(hiddenEventTypeKeyOf(TimelineEvent(winEventId: 1796)), isNull);
  });

  test('hiding a type hides every event of it, and is kept', () async {
    final library = await _library();
    expect(await library.hideEventType(_sbatFailure('a'), title: 'SBAT'), isTrue);
    expect(library.isHiddenType(_sbatFailure('later')), isTrue);
    expect(library.isHiddenType(_serviceCrash()), isFalse);

    final reloaded = await _library();
    expect(reloaded.isHiddenType(_sbatFailure('after restart')), isTrue);
    expect(reloaded.hiddenEventTypes.single.title, 'SBAT');
    expect(reloaded.hiddenEventTypes.single.eventId, 1796);

    await reloaded.showEventType(reloaded.hiddenEventTypes.single.key);
    expect(reloaded.isHiddenType(_sbatFailure('a')), isFalse);
    expect((await _library()).hiddenEventTypes, isEmpty);
  });

  test('an event without a provider is not hidden', () async {
    final library = await _library();
    expect(
      await library.hideEventType(TimelineEvent(winEventId: 1), title: ''),
      isFalse,
    );
    expect(library.hiddenEventTypes, isEmpty);
  });

  test('a damaged list hides nothing instead of failing', () async {
    SharedPreferences.setMockInitialValues(
      {'timeline.hidden_event_types': '{not json'},
    );
    final library = await _library();
    expect(library.hiddenEventTypes, isEmpty);
    expect(library.isHiddenType(_sbatFailure('a')), isFalse);
  });

  testWidgets('Timeline leaves hidden types out but counts them',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final logger = AppLogger();
    final settings = SettingsController(logger: logger);
    await settings.load();
    await settings.completeWelcome();
    final ipc = PulseIpcClient();
    final library = await _library();
    await library.hideEventType(_sbatFailure('x'), title: 'SBAT');
    final imports = EvtxImportController(
      logger: logger,
      reader: _FakeReader([
        _sbatFailure('sbat-1'),
        _sbatFailure('sbat-2'),
        _serviceCrash(),
      ]),
    );
    await imports.open(r'C:\logs\other-pc.evtx');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: ipc),
          ChangeNotifierProvider.value(
            value: ConnectionController(ipc: ipc, logger: logger),
          ),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(
            value: TimelineSessionController(
              ipc: ipc,
              settings: settings,
              logger: logger,
            ),
          ),
          ChangeNotifierProvider.value(value: library),
          ChangeNotifierProvider.value(value: imports),
        ],
        child: MaterialApp(
          theme: PulseTheme.dark(),
          home: const Scaffold(body: TimelinePage(title: 'Timeline')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A service stopped unexpectedly'), findsOneWidget);
    expect(find.text('Secure Boot SBAT update failed'), findsNothing);
    expect(find.text('2 hidden events'), findsOneWidget);

    await tester.tap(find.text('2 hidden events'));
    await tester.pumpAndSettle();
    expect(find.text('Secure Boot SBAT update failed'), findsNWidgets(2));
    expect(find.text('Showing 2 hidden events'), findsOneWidget);
  });
}
