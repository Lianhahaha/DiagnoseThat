import 'package:pulse_protocol/pulse_wire.dart';

/// One slice of the Timeline activity strip.
class TimelineActivityBucket {
  const TimelineActivityBucket({
    required this.count,
    required this.worstSeverity,
  });

  /// Events whose timestamp falls inside this slice.
  final int count;

  /// Highest [Severity] seen in the slice ([Severity.unknown] when empty).
  final int worstSeverity;
}

/// Plain-language summary of recent Windows activity for the Timeline hero.
///
/// Built only from events Pulse already holds in the session — it never
/// estimates or extrapolates counts it has not seen.
class TimelineActivitySummary {
  const TimelineActivitySummary({
    required this.lastHourCount,
    required this.lastHourProblems,
    required this.lastHourWarnings,
    required this.buckets,
    required this.window,
  });

  static const Duration defaultWindow = Duration(hours: 24);
  static const int defaultBucketCount = 48;
  static const Duration _recent = Duration(hours: 1);

  /// Events in the last hour.
  final int lastHourCount;

  /// Error and critical events in the last hour.
  final int lastHourProblems;

  /// Warning events in the last hour.
  final int lastHourWarnings;

  /// Oldest → newest slices covering [window].
  final List<TimelineActivityBucket> buckets;
  final Duration window;

  int get peakBucketCount =>
      buckets.fold(0, (peak, b) => b.count > peak ? b.count : peak);

  factory TimelineActivitySummary.fromEvents(
    Iterable<TimelineEvent> events, {
    required int nowUnixMs,
    Duration window = defaultWindow,
    int bucketCount = defaultBucketCount,
  }) {
    final windowMs = window.inMilliseconds;
    final bucketMs = windowMs / bucketCount;
    final startMs = nowUnixMs - windowMs;
    final recentStartMs = nowUnixMs - _recent.inMilliseconds;

    final counts = List<int>.filled(bucketCount, 0);
    final worst = List<int>.filled(bucketCount, Severity.unknown);
    var lastHour = 0;
    var problems = 0;
    var warnings = 0;

    for (final event in events) {
      final ts = event.timestampUnixMs;
      if (ts <= 0 || ts > nowUnixMs || ts < startMs) continue;

      final index = ((ts - startMs) / bucketMs).floor().clamp(
        0,
        bucketCount - 1,
      );
      counts[index]++;
      if (_rank(event.severity) > _rank(worst[index])) {
        worst[index] = event.severity;
      }

      if (ts >= recentStartMs) {
        lastHour++;
        if (event.severity == Severity.error ||
            event.severity == Severity.critical) {
          problems++;
        } else if (event.severity == Severity.warning) {
          warnings++;
        }
      }
    }

    return TimelineActivitySummary(
      lastHourCount: lastHour,
      lastHourProblems: problems,
      lastHourWarnings: warnings,
      window: window,
      buckets: [
        for (var i = 0; i < bucketCount; i++)
          TimelineActivityBucket(count: counts[i], worstSeverity: worst[i]),
      ],
    );
  }

  /// Level 1 sentence for the hero.
  String get headline {
    if (lastHourProblems == 1) {
      return 'Windows reported a problem in the last hour.';
    }
    if (lastHourProblems > 1) {
      return 'Windows reported $lastHourProblems problems in the last hour.';
    }
    if (lastHourWarnings > 0) return 'Windows is mostly quiet.';
    if (lastHourCount > 0) return 'Windows is quiet.';
    return 'Nothing new in the last hour.';
  }

  /// Supporting sentence with the counts behind [headline].
  String get detail {
    if (lastHourCount == 0) {
      return 'Pulse is listening. New events appear here as Windows logs them.';
    }
    final parts = <String>[
      _plural(lastHourCount, 'event', 'events'),
      if (lastHourProblems > 0) _plural(lastHourProblems, 'error', 'errors'),
      if (lastHourWarnings > 0)
        _plural(lastHourWarnings, 'warning', 'warnings'),
    ];
    return '${parts.join(' · ')} in the last hour.';
  }

  static String _plural(int n, String one, String many) =>
      '$n ${n == 1 ? one : many}';

  /// Orders severities so verbose/unknown never outrank real levels.
  static int _rank(int severity) => switch (severity) {
    Severity.critical => 4,
    Severity.error => 3,
    Severity.warning => 2,
    Severity.info => 1,
    _ => 0,
  };
}
