import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pulse/app/theme/pulse_theme.dart';
import 'package:pulse/application/settings_controller.dart';
import 'package:pulse/logging/app_logger.dart';
import 'package:pulse/presentation/health/health_view_models.dart';
import 'package:pulse/presentation/health/widgets/health_details_panel.dart';
import 'package:pulse/presentation/utils/pulse_formatters.dart';
import 'package:pulse_protocol/pulse_wire.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gib = 1024 * 1024 * 1024;

/// A desktop with an Intel iGPU and an RTX 3060 (issue #9).
HealthSample _twoGpus() => HealthSample(
      hasGpuPercent: true,
      gpuPercent: 37.5,
      gpus: [
        HealthGpuAdapter(
          luidLow: 0xF21B,
          name: 'NVIDIA GeForce RTX 3060',
          vendor: 'NVIDIA',
          isPrimary: true,
          dedicatedTotalBytes: 12 * _gib,
          sharedTotalBytes: 16 * _gib,
          hasPercent: true,
          percent: 37.5,
          hasDedicatedUsed: true,
          dedicatedUsedBytes: 3 * _gib,
          hasSharedUsed: true,
          sharedUsedBytes: 0,
        ),
        HealthGpuAdapter(
          luidLow: 0xA001,
          name: 'Intel(R) UHD Graphics 770',
          vendor: 'Intel',
          sharedTotalBytes: 16 * _gib,
          hasPercent: true,
          percent: 4,
          hasSharedUsed: true,
          sharedUsedBytes: _gib ~/ 2,
        ),
      ],
    );

Future<void> _pumpGpuPanel(WidgetTester tester, HealthSample sample) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController(logger: AppLogger());
  await settings.load();
  final view = HealthViewState()
    ..info = HealthStaticInfo(gpuModel: 'NVIDIA GeForce RTX 3060')
    ..sample = sample;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: PulseTheme.dark(),
        home: Scaffold(
          body: HealthDetailsPanel(
            kind: HealthPanelKind.gpu,
            view: view,
            onClose: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => PulseFormatters.binaryUnits = true);

  test('one summary per GPU, with load and memory', () {
    final gpus = gpuAdapterSummaries(_twoGpus());
    expect(gpus, hasLength(2));

    expect(gpus[0].name, 'NVIDIA GeForce RTX 3060');
    expect(gpus[0].usage, '37.5 %');
    expect(gpus[0].memory,
        'Dedicated 3.0 GiB of 12.0 GiB · Shared 0 B of 16.0 GiB');
    expect(gpus[0].isPrimary, isTrue);

    expect(gpus[1].name, 'Intel(R) UHD Graphics 770');
    expect(gpus[1].usage, '4.0 %');
    // An iGPU has no dedicated memory; only shared memory is listed.
    expect(gpus[1].memory, 'Shared 512.0 MiB of 16.0 GiB');
    expect(gpus[1].isPrimary, isFalse);
  });

  test('a GPU Windows reports no load for shows a dash, not 0 %', () {
    final gpus = gpuAdapterSummaries(HealthSample(gpus: [
      HealthGpuAdapter(vendor: 'AMD'),
    ]));
    expect(gpus.single.usage, kUnavailableDash);
    expect(gpus.single.name, 'AMD GPU');
    expect(gpus.single.memory, isEmpty);
  });

  test('an older service sends no list', () {
    expect(gpuAdapterSummaries(HealthSample()), isEmpty);
    expect(gpuAdapterSummaries(null), isEmpty);
  });

  testWidgets('GPU panel lists every GPU when there is more than one',
      (tester) async {
    await _pumpGpuPanel(tester, _twoGpus());
    expect(find.text('All GPUs (2)'), findsOneWidget);
    expect(find.text('Intel(R) UHD Graphics 770'), findsOneWidget);
    expect(find.text('Shared 512.0 MiB of 16.0 GiB'), findsOneWidget);
    expect(find.text(kPrimaryGpuNote), findsOneWidget);
  });

  testWidgets('GPU panel has no list for a single GPU', (tester) async {
    final sample = _twoGpus()..gpus.removeLast();
    await _pumpGpuPanel(tester, sample);
    expect(find.textContaining('All GPUs'), findsNothing);
    expect(find.text(kPrimaryGpuNote), findsNothing);
  });
}
