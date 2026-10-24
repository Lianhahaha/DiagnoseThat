import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/theme/pulse_theme.dart';
import 'package:pulse/presentation/health/health_view_models.dart';
import 'package:pulse/presentation/health/widgets/health_spec_rows.dart';
import 'package:pulse_protocol/pulse_wire.dart';

/// Values read from a Samsung SSD 980 on the test PC.
HealthDiskHealth _nvme({int criticalWarning = 0}) => HealthDiskHealth(
      index: 2,
      model: 'Samsung SSD 980 500GB',
      bus: 'NVMe',
      hasTempC: true,
      tempC: 36,
      hasFailurePredicted: true,
      failurePredicted: criticalWarning != 0,
      hasCriticalWarning: true,
      criticalWarning: criticalWarning,
      hasPercentageUsed: true,
      percentageUsed: 7,
      hasAvailableSpare: true,
      availableSpare: 100,
      availableSpareThreshold: 10,
      hasPowerOnHours: true,
      powerOnHours: 5647,
      hasUnsafeShutdowns: true,
      unsafeShutdowns: 133,
      hasMediaErrors: true,
      mediaErrors: 0,
      hasBytesWritten: true,
      bytesWritten: 27270 * 1000000000,
    );

HealthDiskHealth _sata() => HealthDiskHealth(
      index: 0,
      model: 'MSI S270 480GB',
      bus: 'SATA',
      hasTempC: true,
      tempC: 50,
      hasFailurePredicted: true,
    );

void main() {
  test('a healthy NVMe drive shows every counter it reports', () {
    final rows = Map.fromEntries(
      diskHealthRows(_nvme()).map((r) => MapEntry(r.$1, r.$2)),
    );
    expect(diskHealthTitle(_nvme()), 'Disk 2 · Samsung SSD 980 500GB · NVMe');
    expect(rows['Health'], 'OK');
    expect(rows['Wear'], '7% used');
    expect(rows['Spare capacity'], '100% (warns below 10%)');
    expect(rows['Unsafe shutdowns'], '133');
    expect(rows['Media errors'], '0');
    expect(rows['Power-on time'], '235 d 7 h');
    expect(rows.containsKey('Total Data Written'), isTrue);
    expect(rows.containsKey('Total Data Read'), isFalse);
  });

  test('a SATA drive shows health and temperature only', () {
    final labels = diskHealthRows(_sata()).map((r) => r.$1).toList();
    expect(labels, ['Health', 'Temperature']);
    expect(formatDiskHealthStatus(_sata()), 'OK');
  });

  test('NVMe critical warnings are spelled out', () {
    expect(
      formatDiskHealthStatus(_nvme(criticalWarning: 0x01 | 0x08)),
      'Warning: spare capacity is below its threshold; '
      'the drive has switched to read-only',
    );
    final predicted = _sata()..failurePredicted = true;
    expect(
      formatDiskHealthStatus(predicted),
      'Warning: the drive predicts a failure',
    );
    expect(formatDiskHealthStatus(HealthDiskHealth()), 'Not supported');
  });

  test('disk health survives the wire', () {
    final env = Envelope(
      requestId: 0,
      body: HealthUpdate(
        sample: HealthSample(diskHealth: [_sata(), _nvme()]),
      ),
    );
    final decoded = decodeEnvelope(encodeEnvelope(env));
    final disks = (decoded.body! as HealthUpdate).sample.diskHealth;
    expect(disks, hasLength(2));
    expect(disks[0].model, 'MSI S270 480GB');
    expect(disks[0].hasPercentageUsed, isFalse);
    expect(disks[1].bus, 'NVMe');
    expect(disks[1].percentageUsed, 7);
    expect(disks[1].availableSpareThreshold, 10);
    expect(disks[1].unsafeShutdowns, 133);
    expect(disks[1].bytesWritten, 27270 * 1000000000);
    expect(disks[1].tempC, 36);
  });

  testWidgets('a long warning fits a narrow details panel', (tester) async {
    final disk = _nvme(criticalWarning: 0x1F);
    await tester.pumpWidget(
      MaterialApp(
        theme: PulseTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: HealthSpecSection(
                title: diskHealthTitle(disk),
                compact: true,
                rows: [
                  for (final (label, value) in diskHealthRows(disk))
                    HealthSpecRow(label: label, value: value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('read-only'), findsOneWidget);
  });

  test('the Disk panel totals every local fixed drive (issue #29)', () {
    HealthVolume volume(String id, int total, int used, {bool fixed = true}) =>
        HealthVolume(
          id: id,
          totalBytes: total,
          usedBytes: used,
          hasCapacity: true,
          includedInSummary: fixed,
        );
    const tib = 1 << 40;
    final totals = localStorageTotals(
      HealthSample(
        volumes: [
          volume('C:', 2 * tib, tib ~/ 10),
          volume('D:', 2 * tib, tib ~/ 2),
          volume('E:', 64 << 30, 1 << 30, fixed: false), // USB stick
        ],
      ),
    )!;
    expect(totals.driveCount, 2);
    expect(totals.totalBytes, 4 * tib);
    expect(totals.usedBytes, tib ~/ 10 + tib ~/ 2);
    expect(totals.freeBytes, 4 * tib - (tib ~/ 10 + tib ~/ 2));

    expect(localStorageTotals(HealthSample()), isNull);
  });
}
