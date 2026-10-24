import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/timeline/timeline_display.dart';
import 'package:pulse_protocol/pulse_wire.dart';

TimelineEvent _event(String id, int unixMs) =>
    TimelineEvent(eventId: id, timestampUnixMs: unixMs);

void main() {
  test('latest is the newest event, not the first row (pinned sort first)', () {
    // Pinned 20:34 event listed above the newer 23:15 event.
    final rows = [
      _event('pinned-old', 1000),
      _event('newest', 5000),
      _event('older', 3000),
    ];
    expect(latestEventIdOf(rows), 'newest');
  });

  test('pinned first keeps newest-first order for large lists', () {
    // Over 32 rows List.sort switches to an unstable quicksort; the old
    // pinned-vs-rest comparator put a days-old event above recent ones.
    final rows = [for (var i = 0; i < 500; i++) _event('e$i', 1000000 - i)];
    final ordered = pinnedFirst(rows, (e) => e.eventId == 'e250');
    expect(ordered.first.eventId, 'e250');
    final rest = ordered.skip(1).map((e) => e.timestampUnixMs).toList();
    for (var i = 1; i < rest.length; i++) {
      expect(rest[i] < rest[i - 1], isTrue, reason: 'row $i out of order');
    }
    expect(ordered, hasLength(500));
  });

  test('events without an id are ignored; empty input has no latest', () {
    expect(latestEventIdOf([_event('', 9000), _event('a', 1)]), 'a');
    expect(latestEventIdOf(const []), isNull);
  });
}
