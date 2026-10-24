import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/theme/pulse_theme.dart';
import 'package:pulse/application/timeline_library_controller.dart';
import 'package:pulse/features/timeline/timeline_query.dart';
import 'package:pulse/presentation/timeline/timeline_date_range_dialog.dart';
import 'package:pulse/presentation/utils/pulse_formatters.dart';
import 'package:pulse_protocol/pulse_wire.dart';

TimelineEvent _at(DateTime utc) =>
    TimelineEvent(timestampUnixMs: utc.millisecondsSinceEpoch);

void main() {
  final from = DateTime.utc(2026, 10, 18, 14);
  final to = DateTime.utc(2026, 10, 18, 15, 30);

  group('custom date range (#15)', () {
    final query = TimelineQuery(
      dateRange: TimelineDateRangeFilter.custom,
      customFromUnixMs: from.millisecondsSinceEpoch,
      customToUnixMs: to.millisecondsSinceEpoch,
    );

    test('keeps events inside the range, bounds included', () {
      expect(query.matches(_at(from)), isTrue);
      expect(query.matches(_at(to)), isTrue);
      expect(query.matches(_at(from.add(const Duration(minutes: 45)))), isTrue);
      expect(query.matches(_at(from.subtract(const Duration(seconds: 1)))),
          isFalse);
      expect(query.matches(_at(to.add(const Duration(seconds: 1)))), isFalse);
      expect(query.isActive, isTrue);
    });

    test('composes with the other filters', () {
      final errorsOnly = query.copyWith(severity: TimelineSeverityFilter.errors);
      final inRange = TimelineEvent(
        timestampUnixMs: from.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        severity: Severity.info,
      );
      expect(errorsOnly.matches(inRange), isFalse);
      expect(query.matches(inRange), isTrue);
    });

    test('an open bound leaves that side unrestricted', () {
      final since = TimelineQuery(
        dateRange: TimelineDateRangeFilter.custom,
        customFromUnixMs: from.millisecondsSinceEpoch,
      );
      expect(since.matches(_at(DateTime.utc(2030))), isTrue);
      expect(since.matches(_at(DateTime.utc(2020))), isFalse);
    });

    test('a saved search keeps the range', () {
      final back = timelineQueryFromJson(timelineQueryToJson(query));
      expect(back.dateRange, TimelineDateRangeFilter.custom);
      expect(back.customFromUnixMs, from.millisecondsSinceEpoch);
      expect(back.customToUnixMs, to.millisecondsSinceEpoch);
    });

    test('label shows the range in local time', () {
      PulseFormatters.clock24h = true;
      expect(
        formatTimelineCustomRange(
          DateTime(2026, 10, 18, 14, 5),
          DateTime(2026, 10, 18, 15, 30),
        ),
        '18 Oct 14:05 – 18 Oct 15:30',
      );
    });
  });

  testWidgets('the dialog returns the range, and refuses from after to',
      (tester) async {
    TimelineCustomRange? result;
    Future<void> open(DateTime a, DateTime b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PulseTheme.dark(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTimelineDateRangeDialog(
                  context,
                  initialFrom: a,
                  initialTo: b,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final a = DateTime(2026, 10, 18, 14);
    final b = DateTime(2026, 10, 18, 15);
    await open(a, b);
    expect(find.text('Custom date range'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result?.from, a);
    expect(result?.to, b);

    result = null;
    await open(b, a);
    expect(find.textContaining('must be before'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Custom date range'), findsOneWidget, reason: 'stays open');
    expect(result, isNull);
  });
}
