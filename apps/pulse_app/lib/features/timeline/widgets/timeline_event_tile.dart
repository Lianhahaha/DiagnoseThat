import 'package:flutter/material.dart';
import 'package:pulse_protocol/pulse_wire.dart';

import '../../../app/theme/pulse_theme.dart';
import '../../../presentation/components/pulse_badge.dart';
import '../../../presentation/components/pulse_focus.dart';
import '../../../presentation/components/safe_hover.dart';
import '../timeline_display.dart';

/// Story-feed row (ADR-012): time column, severity node on a vertical rail,
/// then the human sentence first and technical hints after it.
class TimelineEventTile extends StatefulWidget {
  const TimelineEventTile({
    super.key,
    required this.event,
    required this.isFirst,
    required this.isLast,
    this.selected = false,
    this.emphasize = false,
    this.animationIndex = 0,
    this.onTap,
  });

  final TimelineEvent event;
  final bool isFirst;
  final bool isLast;
  final bool selected;
  final bool emphasize;
  final int animationIndex;
  final VoidCallback? onTap;

  @override
  State<TimelineEventTile> createState() => _TimelineEventTileState();
}

class _TimelineEventTileState extends State<TimelineEventTile>
    with TickerProviderStateMixin, SafeHoverState {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: PulseTokens.motionSlow,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _enter.value = 1;
        return;
      }
      final delay = Duration(milliseconds: 24 + (widget.animationIndex * 36));
      Future<void>.delayed(delay, () {
        if (mounted) _enter.forward();
      });
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  static const double _timeColumnWidth = 52;
  static const double _rowRadius = 12;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final style = event.severityVisual;
    final selected = widget.selected;
    final textTheme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _enter,
                curve: PulseTokens.motionEmphasized,
              ),
            ),
        child: PulseFocus(
          onPressed: widget.onTap,
          borderRadius: BorderRadius.circular(_rowRadius),
          child: AnimatedContainer(
            duration: PulseTokens.motionFast,
            curve: PulseTokens.motionCurve,
            decoration: BoxDecoration(
              color: selected || hover
                  ? PulseTokens.surfaceElevated
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(_rowRadius),
              border: Border.all(
                color: selected
                    ? PulseTokens.accent.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: setHovered,
                borderRadius: BorderRadius.circular(_rowRadius),
                splashColor: style.color.withValues(alpha: 0.06),
                highlightColor: style.color.withValues(alpha: 0.03),
                mouseCursor: SystemMouseCursors.click,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _timeColumnWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 13),
                          child: Text(
                            event.clockLabel,
                            style: textTheme.bodySmall?.copyWith(
                              fontFamily: PulseTheme.monoFont,
                              fontFamilyFallback: PulseTheme.monoFallback,
                              color: PulseTokens.textTertiary,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                      _EventRail(
                        color: style.color,
                        isFirst: widget.isFirst,
                        isLast: widget.isLast,
                        selected: selected,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 11, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    event.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (event.actionRequired)
                                    const PulseBadge(
                                      label: 'Action needed',
                                      tone: PulseBadgeTone.warning,
                                      compact: true,
                                    )
                                  else if (widget.emphasize)
                                    const PulseBadge(
                                      label: 'Latest',
                                      tone: PulseBadgeTone.accent,
                                      compact: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                event.displaySummary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: PulseTokens.textSecondary,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _metaLine(event, style),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: PulseTokens.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Level 2 hints under the human sentence: when, where, how severe.
  static String _metaLine(TimelineEvent event, TimelineSeverityVisual style) {
    final parts = <String>[
      event.relativeTimeLabel,
      event.displayChannel,
      if (event.providerName.isNotEmpty) event.providerName,
      if (event.winEventId > 0) 'ID ${event.winEventId}',
      style.label,
    ];
    return parts.join(' · ');
  }
}

class _EventRail extends StatelessWidget {
  const _EventRail({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.selected,
  });

  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool selected;

  static const double _width = 20;
  static const double _nodeSize = 11;
  static const double _nodeTop = 16;
  static const double _lineWidth = 1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: isFirst ? _nodeTop : 0,
            bottom: isLast ? null : 0,
            height: isLast ? _nodeTop : null,
            child: Container(
              width: _lineWidth,
              color: PulseTokens.strokeStrong,
            ),
          ),
          Positioned(
            top: _nodeTop - 1,
            child: Container(
              width: _nodeSize,
              height: _nodeSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? PulseTokens.surfaceElevated
                      : PulseTokens.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
