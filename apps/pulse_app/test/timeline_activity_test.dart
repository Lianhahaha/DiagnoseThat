import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_protocol/pulse_wire.dart';

import 'package:pulse/features/timeline/timeline_activity.dart';

void main() {
  const nowMs = 1791820000000;
  const minute = 60 * 1000;

  TimelineEvent at(int minutesAgo, int severity) => TimelineEvent(
    eventId: 'e$minutesAgo-$severity',
    timestampUnixMs: nowMs - minutesAgo * minute,
    severity: severity,
  );

  test('counts only the last hour and ranks problems before warnings', () {
    final summary = TimelineActivitySummary.fromEvents([
      at(2, Severity.error),
      at(10, Severity.warning),
      at(30, Severity.info),
      at(90, Severity.critical), // outside the last hour
    ], nowUnixMs: nowMs);

    expect(summary.lastHourCount, 3);
    expect(summary.lastHourProblems, 1);
    expect(summary.lastHourWarnings, 1);
    expect(summary.headline, 'Windows reported a problem in the last hour.');
    expect(summary.detail, '3 events · 1 error · 1 warning in the last hour.');
  });

  test('quiet hour reads as quiet, not as a problem', () {
    final summary = TimelineActivitySummary.fromEvents([
      at(5, Severity.info),
      at(15, Severity.info),
    ], nowUnixMs: nowMs);

    expect(summary.headline, 'Windows is quiet.');
    expect(summary.detail, '2 events in the last hour.');
  });

  test('empty session never invents activity', () {
    final summary = TimelineActivitySummary.fromEvents(
      const [],
      nowUnixMs: nowMs,
    );

    expect(summary.lastHourCount, 0);
    expect(summary.peakBucketCount, 0);
    expect(summary.headline, 'Nothing new in the last hour.');
    expect(
      summary.buckets,
      hasLength(TimelineActivitySummary.defaultBucketCount),
    );
  });

  test('buckets place events by age and keep the worst severity', () {
    final summary = TimelineActivitySummary.fromEvents([
      at(1, Severity.info),
      at(2, Severity.critical),
      at(23 * 60 + 50, Severity.warning), // oldest slice
      at(25 * 60, Severity.error), // older than the window: ignored
      TimelineEvent(eventId: 'future', timestampUnixMs: nowMs + minute),
    ], nowUnixMs: nowMs);

    final newest = summary.buckets.last;
    final oldest = summary.buckets.first;
    expect(newest.count, 2);
    expect(newest.worstSeverity, Severity.critical);
    expect(oldest.count, 1);
    expect(oldest.worstSeverity, Severity.warning);
    expect(summary.buckets.fold<int>(0, (sum, b) => sum + b.count), 3);
  });
}
