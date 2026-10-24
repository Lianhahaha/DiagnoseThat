import 'package:flutter/material.dart';

import '../../app/theme/pulse_theme.dart';
import 'safe_hover.dart';

/// Midnight pill segmented control (ADR-012).
///
/// The track is a canvas-colored pill; the selected segment is an inverted
/// pill (primary text color fill, canvas label) so it reads without relying
/// on the accent. The control hugs its content instead of stretching.
class PulseSegmentedControl<T> extends StatelessWidget {
  const PulseSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PulseSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _height = 40;
  static const double _trackPadding = 4;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final control = DecoratedBox(
          decoration: BoxDecoration(
            color: PulseTokens.canvas,
            borderRadius: BorderRadius.circular(PulseTokens.radiusPill),
            border: Border.all(color: PulseTokens.stroke),
          ),
          child: Container(
            height: _height,
            padding: const EdgeInsets.all(_trackPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  _SegmentButton<T>(
                    segment: segments[i],
                    selected: segments[i].value == selected,
                    onPressed: segments[i].enabled
                        ? () => onChanged(segments[i].value)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        );

        if (constraints.maxWidth.isFinite &&
            constraints.maxWidth < 360 &&
            constraints.maxWidth > 0) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: control,
          );
        }
        return Align(alignment: Alignment.centerLeft, child: control);
      },
    );
  }
}

class PulseSegment<T> {
  const PulseSegment({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

class _SegmentButton<T> extends StatefulWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onPressed,
  });

  final PulseSegment<T> segment;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_SegmentButton<T>> createState() => _SegmentButtonState<T>();
}

class _SegmentButtonState<T> extends State<_SegmentButton<T>>
    with SafeHoverState {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final selected = widget.selected;

    Color bg;
    Color fg;
    Color border;

    if (!enabled) {
      bg = Colors.transparent;
      fg = PulseTokens.textDisabled;
      border = Colors.transparent;
    } else if (selected) {
      bg = PulseTokens.textPrimary;
      fg = PulseTokens.canvas;
      border = Colors.transparent;
    } else if (_pressed) {
      bg = PulseTokens.surfacePressed;
      fg = PulseTokens.textPrimary;
      border = Colors.transparent;
    } else if (hover) {
      bg = PulseTokens.surfaceHover;
      fg = PulseTokens.textPrimary;
      border = Colors.transparent;
    } else {
      bg = Colors.transparent;
      fg = PulseTokens.textSecondary;
      border = Colors.transparent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: enabled ? setHovered : null,
        onHighlightChanged: enabled
            ? (v) => setState(() => _pressed = v)
            : null,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(PulseTokens.radiusPill),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : PulseTokens.motionFast,
          curve: PulseTokens.motionCurve,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PulseTokens.radiusPill),
            border: Border.all(color: border),
          ),
          child: Text(
            widget.segment.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
          ),
        ),
      ),
    );
  }
}
