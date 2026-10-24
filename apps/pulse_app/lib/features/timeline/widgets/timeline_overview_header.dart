import 'package:flutter/material.dart';
import 'package:pulse_protocol/pulse_wire.dart';

import '../../../app/theme/pulse_theme.dart';
import '../../../presentation/utils/pulse_formatters.dart';
import '../timeline_activity.dart';

/// Timeline hero (ADR-012 D7): a plain-language sentence about the last
/// hour, three counts, and a 24-hour activity strip built from session events.
class TimelineOverviewHeader extends StatelessWidget {
  const TimelineOverviewHeader({
    super.key,
    required this.summary,
    required this.now,
  });

  final TimelineActivitySummary summary;
  final DateTime now;

  static const double _stripHeight = 56;
  static const double _minBarHeight = 4;
  static const double _barGap = 3;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get _eyebrow =>
      '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}'
      ' · ${PulseFormatters.clockTime(now)}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mono = TextStyle(
      fontFamily: PulseTheme.monoFont,
      fontFamilyFallback: PulseTheme.monoFallback,
      letterSpacing: 0,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
      decoration: BoxDecoration(
        color: PulseTokens.surface,
        borderRadius: BorderRadius.circular(PulseTokens.radiusCard),
        border: Border.all(color: PulseTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 48,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.end,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eyebrow.toUpperCase(),
                      style: textTheme.labelSmall
                          ?.merge(mono)
                          .copyWith(
                            color: PulseTokens.textTertiary,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      summary.headline,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        height: 1.15,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.detail,
                      style: textTheme.bodyLarge?.copyWith(
                        color: PulseTokens.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _Stat(
                    label: 'Events · 1 h',
                    value: summary.lastHourCount,
                    mono: mono,
                  ),
                  _Stat(
                    label: 'Errors',
                    value: summary.lastHourProblems,
                    mono: mono,
                    highlight: summary.lastHourProblems > 0
                        ? PulseTokens.severityError
                        : null,
                  ),
                  _Stat(
                    label: 'Warnings',
                    value: summary.lastHourWarnings,
                    mono: mono,
                    highlight: summary.lastHourWarnings > 0
                        ? PulseTokens.severityWarning
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Semantics(
            label:
                'Event activity over the last 24 hours. '
                '${summary.lastHourCount} events in the last hour.',
            child: ExcludeSemantics(
              child: SizedBox(
                height: _stripHeight,
                child: _ActivityStrip(summary: summary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: (textTheme.labelSmall ?? const TextStyle())
                .merge(mono)
                .copyWith(color: PulseTokens.textTertiary, fontSize: 11),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('24 h ago'),
                Text('18 h'),
                Text('12 h'),
                Text('6 h'),
                Text('Now'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({required this.summary});

  final TimelineActivitySummary summary;

  Color _barColor(TimelineActivityBucket bucket, bool newest) {
    if (bucket.worstSeverity == Severity.critical ||
        bucket.worstSeverity == Severity.error) {
      return PulseTokens.severityError;
    }
    if (bucket.worstSeverity == Severity.warning) {
      return PulseTokens.severityWarning;
    }
    if (newest && bucket.count > 0) return PulseTokens.accent;
    return PulseTokens.strokeStrong;
  }

  @override
  Widget build(BuildContext context) {
    final peak = summary.peakBucketCount;
    final buckets = summary.buckets;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          if (i > 0) const SizedBox(width: TimelineOverviewHeader._barGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bucket = buckets[i];
                final ratio = peak == 0 ? 0.0 : bucket.count / peak;
                final height =
                    TimelineOverviewHeader._minBarHeight +
                    ratio *
                        (constraints.maxHeight -
                            TimelineOverviewHeader._minBarHeight);
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: _barColor(bucket, i == buckets.length - 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.mono,
    this.highlight,
  });

  final String label;
  final int value;
  final TextStyle mono;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: PulseTokens.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: textTheme.headlineMedium
              ?.merge(mono)
              .copyWith(
                fontSize: 32,
                height: 1.1,
                fontWeight: FontWeight.w500,
                color: highlight ?? PulseTokens.textPrimary,
              ),
        ),
      ],
    );
  }
}
