import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/pulse_theme.dart';
import '../components/pulse_focus.dart';
import 'health_cards.dart';
import 'health_utilization_colors.dart';
import 'health_view_models.dart';

/// Midnight Overview bento (ADR-012 D7): one large "system pulse" tile next
/// to a 2 × 2 grid of live metric tiles. Every value comes from
/// [HealthViewState]; unavailable metrics show a dash, never an estimate.
class HealthOverviewBento extends StatelessWidget {
  const HealthOverviewBento({
    super.key,
    required this.view,
    required this.selectedPanel,
    required this.onSelect,
    required this.gap,
  });

  final HealthViewState view;
  final HealthPanelKind? selectedPanel;
  final ValueChanged<HealthPanelKind> onSelect;
  final double gap;

  HealthMetric? _metric(String id) {
    for (final metric in view.heroMetrics) {
      if (metric.id == id) return metric;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cpu = _metric('cpu');
    final memory = _metric('memory');
    final gpu = _metric('gpu');
    final download = _metric('download');
    final upload = _metric('upload');
    final info = view.info;
    final sample = view.sample;

    String orDash(String value) =>
        value.trim().isEmpty ? kUnavailableDash : value.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _PulseHeroTile(
            view: view,
            selected: selectedPanel == HealthPanelKind.cpu,
            onTap: () => onSelect(HealthPanelKind.cpu),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MemoryRingTile(
                        metric: memory,
                        selected: selectedPanel == HealthPanelKind.memory,
                        onTap: () => onSelect(HealthPanelKind.memory),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _MetricTile(
                        title: 'CPU',
                        metric: cpu,
                        caption: orDash(info?.cpuModel ?? ''),
                        selected: selectedPanel == HealthPanelKind.cpu,
                        onTap: () => onSelect(HealthPanelKind.cpu),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'GPU',
                        metric: gpu,
                        caption: orDash(info?.gpuModel ?? ''),
                        badge: sample != null && sample.hasGpuTempC
                            ? '${sample.gpuTempC.toStringAsFixed(0)} °C'
                            : null,
                        selected: selectedPanel == HealthPanelKind.gpu,
                        onTap: () => onSelect(HealthPanelKind.gpu),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _NetworkTile(
                        download: download,
                        upload: upload,
                        adapter: orDash(info?.activeNetworkAdapter ?? ''),
                        selected: selectedPanel == HealthPanelKind.network,
                        onTap: () => onSelect(HealthPanelKind.network),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared Midnight tile chrome: panel surface, hairline border, accent ring
/// when its details panel is open.
class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.child,
    required this.semanticsLabel,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 14),
  });

  final Widget child;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PulseTokens.radiusCard);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: PulseFocus(
        onPressed: onTap,
        borderRadius: radius,
        child: Material(
          color: PulseTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected
                  ? PulseTokens.accent.withValues(alpha: 0.45)
                  : PulseTokens.stroke,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: PulseTokens.surfaceElevated.withValues(alpha: 0.6),
            mouseCursor: onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

TextStyle _mono(BuildContext context, {double? size, Color? color}) =>
    (Theme.of(context).textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontFamily: PulseTheme.monoFont,
      fontFamilyFallback: PulseTheme.monoFallback,
      fontSize: size,
      height: 1.05,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w500,
      color: color ?? PulseTokens.textPrimary,
    );

TextStyle? _label(BuildContext context) =>
    Theme.of(context).textTheme.labelLarge?.copyWith(
          color: PulseTokens.textPrimary,
          fontWeight: FontWeight.w500,
        );

TextStyle? _caption(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(
          color: PulseTokens.textSecondary,
          fontSize: 12.5,
        );

class _PulseHeroTile extends StatelessWidget {
  const _PulseHeroTile({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final HealthViewState view;
  final bool selected;
  final VoidCallback onTap;

  static const double _percentMax = 100;

  @override
  Widget build(BuildContext context) {
    final summary = view.systemStatus;
    final sample = view.sample;
    final statusColor = switch (summary.level) {
      SystemStatusLevel.healthy => PulseTokens.success,
      SystemStatusLevel.attention => PulseTokens.warning,
      SystemStatusLevel.critical => PulseTokens.error,
    };
    final textTheme = Theme.of(context).textTheme;
    final history = recentHistory(view.cpuHistory, max: 60);
    final cpuText = sample != null && sample.hasCpuPercent
        ? '${sample.cpuPercent.toStringAsFixed(0)}%'
        : kUnavailableDash;
    final memoryText = sample != null && sample.memoryTotalBytes > 0
        ? '${(sample.memoryUsedBytes * 100 / sample.memoryTotalBytes).toStringAsFixed(0)}%'
        : kUnavailableDash;
    final gpuText = sample != null && sample.hasGpuPercent
        ? '${sample.gpuPercent.toStringAsFixed(0)}%'
        : kUnavailableDash;
    final uptime = formatUptime(sample?.uptimeMs ?? 0);

    return _BentoTile(
      semanticsLabel: 'System pulse: ${summary.title}. ${summary.message} '
          'Health score ${view.healthScore}.',
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYSTEM PULSE',
                      style: textTheme.labelSmall?.copyWith(
                        fontFamily: PulseTheme.monoFont,
                        fontFamilyFallback: PulseTheme.monoFallback,
                        color: PulseTokens.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            summary.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 38,
                              height: 1.05,
                              letterSpacing: -1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      uptime == kUnavailableDash
                          ? summary.message
                          : '${summary.message} Up for $uptime.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: PulseTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${view.healthScore}',
                    style: _mono(context, size: 44, color: PulseTokens.accent),
                  ),
                  const SizedBox(height: 4),
                  Text('Health score', style: _caption(context)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('CPU · last 60 seconds', style: _caption(context)),
              const Spacer(),
              Text(
                view.lastUpdatedLabel,
                style: _caption(context)?.copyWith(
                  color: PulseTokens.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: history.length >= 2
                ? CustomPaint(
                    painter: HealthSparklinePainter(
                      values: history,
                      color: PulseTokens.accent,
                      fixedMin: 0,
                      fixedMax: _percentMax,
                      strokeWidth: 2,
                    ),
                    child: const SizedBox.expand(),
                  )
                : Center(
                    child: Text(
                      'Waiting for live samples…',
                      style: _caption(context),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: PulseTokens.stroke)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  for (final (label, value) in [
                    ('CPU', cpuText),
                    ('Memory', memoryText),
                    ('GPU', gpuText),
                  ])
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: _caption(context)),
                          const SizedBox(height: 2),
                          Text(value, style: _mono(context, size: 20)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.metric,
    required this.caption,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final HealthMetric? metric;
  final String caption;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final value = m?.value ?? kUnavailableDash;
    final unit = m?.unit ?? '';
    final sparkline = m?.sparkline ?? const <double>[];
    return _BentoTile(
      semanticsLabel: '$title: $value$unit. $caption',
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _label(context))),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: PulseTokens.surfaceHover,
                    borderRadius: BorderRadius.circular(PulseTokens.radiusPill),
                  ),
                  child: Text(
                    badge!,
                    style: _mono(context, size: 11.5)
                        .copyWith(letterSpacing: 0, height: 1.2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: _mono(context, size: 30)),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: _mono(context, size: 16, color: PulseTokens.textTertiary),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: sparkline.length >= 2 && m != null
                ? CustomPaint(
                    painter: HealthSparklinePainter(
                      values: sparkline,
                      color: healthMetricChartColor(m),
                      fixedMin: unit == '%' ? 0 : null,
                      fixedMax: unit == '%' ? 100 : null,
                    ),
                    child: const SizedBox.expand(),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _caption(context),
          ),
        ],
      ),
    );
  }
}

class _MemoryRingTile extends StatelessWidget {
  const _MemoryRingTile({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  final HealthMetric? metric;
  final bool selected;
  final VoidCallback onTap;

  static const double _ringStroke = 10;
  static const double _ringMaxSize = 112;

  @override
  Widget build(BuildContext context) {
    final progress = metric?.progress;
    final percentText =
        progress == null ? kUnavailableDash : '${(progress * 100).round()}%';
    final detail = metric == null || !metric!.available
        ? kUnavailableDash
        : '${metric!.value} ${metric!.unit} ${metric!.description}'.trim();
    final color = progress == null
        ? PulseTokens.strokeStrong
        : HealthUtilizationColors.forPercent(progress * 100);

    return _BentoTile(
      semanticsLabel: 'Memory: $percentText in use. $detail',
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxHeight, _ringMaxSize);
              return SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: progress ?? 0,
                    color: color,
                    track: PulseTokens.surfaceHover,
                    stroke: _ringStroke,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Memory', style: _label(context)),
                const SizedBox(height: 6),
                Text(percentText, style: _mono(context, size: 30)),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _caption(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base..color = track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.download,
    required this.upload,
    required this.adapter,
    required this.selected,
    required this.onTap,
  });

  final HealthMetric? download;
  final HealthMetric? upload;
  final String adapter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final down = download?.value ?? kUnavailableDash;
    final up = upload?.value ?? kUnavailableDash;
    final downLine = download?.sparkline ?? const <double>[];
    final upLine = upload?.sparkline ?? const <double>[];

    Widget column(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _caption(context)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(context, size: 20),
              ),
            ],
          ),
        );

    return _BentoTile(
      semanticsLabel: 'Network: download $down, upload $up. $adapter',
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Network', style: _label(context)),
          const SizedBox(height: 10),
          Row(children: [column('Down', down), column('Up', up)]),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (downLine.length >= 2)
                  CustomPaint(
                    painter: HealthSparklinePainter(
                      values: downLine,
                      color: PulseTokens.accent,
                    ),
                  ),
                if (upLine.length >= 2)
                  CustomPaint(
                    painter: HealthSparklinePainter(
                      values: upLine,
                      color: PulseTokens.info,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            adapter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _caption(context),
          ),
        ],
      ),
    );
  }
}
