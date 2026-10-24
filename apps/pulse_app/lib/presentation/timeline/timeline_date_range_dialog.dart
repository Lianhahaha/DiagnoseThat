import 'package:flutter/material.dart';

import '../../app/theme/pulse_theme.dart';
import '../utils/pulse_formatters.dart';

/// Local-time bounds picked in [showTimelineDateRangeDialog].
class TimelineCustomRange {
  const TimelineCustomRange(this.from, this.to);

  final DateTime from;
  final DateTime to;
}

/// "18 Oct 14:00" in local time, honoring the 12/24-hour setting.
String formatTimelineDateTime(DateTime local) =>
    '${local.day} ${_months[local.month - 1]} ${PulseFormatters.clockTime(local)}';

/// "18 Oct 14:00 – 18 Oct 15:30" for the date filter button and chip.
String formatTimelineCustomRange(DateTime from, DateTime to) =>
    '${formatTimelineDateTime(from)} – ${formatTimelineDateTime(to)}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Asks for a from / to range in local time. Returns null when cancelled.
Future<TimelineCustomRange?> showTimelineDateRangeDialog(
  BuildContext context, {
  required DateTime initialFrom,
  required DateTime initialTo,
}) {
  return showDialog<TimelineCustomRange>(
    context: context,
    builder: (context) => _DateRangeDialog(
      initialFrom: initialFrom,
      initialTo: initialTo,
    ),
  );
}

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({required this.initialFrom, required this.initialTo});

  final DateTime initialFrom;
  final DateTime initialTo;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  /// Earliest selectable date; older events are rare in a live session.
  static final _firstDate = DateTime(2000);

  late DateTime _from = widget.initialFrom;
  late DateTime _to = widget.initialTo;

  bool get _valid => !_from.isAfter(_to);

  Future<DateTime?> _pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: _firstDate,
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(alwaysUse24HourFormat: PulseFormatters.clock24h),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _row(String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(color: PulseTokens.textSecondary),
          ),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await _pick(value);
              if (picked != null) setState(() => onPicked(picked));
            },
            child: Text(formatTimelineDateTime(value)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PulseTokens.surfaceElevated,
      title: const Text('Custom date range'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('From', _from, (v) => _from = v),
            const SizedBox(height: 10),
            _row('To', _to, (v) => _to = v),
            if (!_valid) ...[
              const SizedBox(height: 10),
              Text(
                '"From" must be before "To".',
                style: TextStyle(color: PulseTokens.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _valid
              ? () => Navigator.pop(context, TimelineCustomRange(_from, _to))
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
