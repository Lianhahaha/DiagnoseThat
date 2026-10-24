import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:pulse_protocol/pulse_wire.dart';

import '../../../app/theme/pulse_theme.dart';
import '../../../application/timeline_library_controller.dart';
import '../../../ipc/pulse_ipc_client.dart';
import '../../../presentation/components/pulse_badge.dart';
import '../../../presentation/utils/pulse_snack.dart';
import '../evtx_import.dart';
import '../hidden_event_types.dart';
import '../timeline_display.dart';
import '../timeline_incident_engine.dart';
import 'detail_section.dart';
import 'metadata_table.dart';

/// Right-side Event Details panel with Explained / Technical / Raw XML tabs
/// (AGENTS.md information hierarchy).
/// Compact Wevtapi fields come from the list [TimelineEvent]; raw XML is lazy-loaded.
class TimelineDetailsPanel extends StatefulWidget {
  const TimelineDetailsPanel({
    super.key,
    required this.event,
    required this.onClose,
    this.rcaHint,
    this.relatedEvents = const [],
    this.onSelectRelated,
    this.isLive = false,
  });

  final TimelineEvent event;
  final VoidCallback onClose;
  final TimelineRcaHint? rcaHint;
  final List<TimelineEvent> relatedEvents;
  final ValueChanged<TimelineEvent>? onSelectRelated;
  final bool isLive;

  @override
  State<TimelineDetailsPanel> createState() => _TimelineDetailsPanelState();
}

class _TimelineDetailsPanelState extends State<TimelineDetailsPanel> {
  String? _rawXml;
  bool _loadingXml = false;
  String? _xmlError;
  bool _xmlRequested = false;
  _DetailLevel _level = _DetailLevel.explained;

  TimelineEvent get event => widget.event;

  @override
  void didUpdateWidget(covariant TimelineDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _rawXml = widget.event.rawXml.isNotEmpty ? widget.event.rawXml : null;
      _loadingXml = false;
      _xmlError = null;
      _xmlRequested = false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (event.rawXml.isNotEmpty) {
      _rawXml = event.rawXml;
      _xmlRequested = true;
    }
  }

  Future<void> _loadRawXml() async {
    if (_xmlRequested || _loadingXml) return;
    // Imported events came with their XML; looking up their record id here
    // would return an unrelated event from this PC's log.
    if (isImportedEvent(event)) {
      setState(() {
        _xmlRequested = true;
        _xmlError = 'The file did not include Event XML for this record.';
      });
      return;
    }
    if (event.channel.isEmpty || event.recordId == 0) {
      setState(() {
        _xmlRequested = true;
        _xmlError = 'Record ID or channel unavailable — cannot load Event XML.';
      });
      return;
    }
    setState(() {
      _loadingXml = true;
      _xmlError = null;
      _xmlRequested = true;
    });
    try {
      final ipc = context.read<PulseIpcClient>();
      final detail = await ipc.getTimelineEventDetail(
        channel: event.displayChannel,
        recordId: event.recordId,
      );
      if (!mounted) return;
      if (!detail.found) {
        setState(() {
          _loadingXml = false;
          _xmlError = 'Event was not found in the Event Log (it may have been cleared).';
        });
        return;
      }
      setState(() {
        _loadingXml = false;
        _rawXml = detail.event.rawXml;
        if (_rawXml == null || _rawXml!.isEmpty) {
          _xmlError = 'Windows did not return Event XML for this record.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingXml = false;
        _xmlError = e.toString();
      });
    }
  }

  List<MetadataEntry> _technicalEntries({required bool dense}) {
    String dash(String v) => dense ? (v.isEmpty ? '—' : v) : v;
    String hexKeywords() {
      if (!event.hasKeywords) return '';
      return '0x${event.keywords.toUnsigned(64).toRadixString(16)}';
    }

    // Structured Wevtapi system props mirrored on TimelineEvent.
    // Version / Qualifiers / Provider Guid appear in Raw Event XML when present
    // (not duplicated as structured columns in R2 — see validation report).
    return [
      MetadataEntry('Logged (ISO UTC)', dash(event.timestampIso)),
      MetadataEntry(
        'Logged (Unix ms)',
        event.timestampUnixMs == 0
            ? dash('')
            : event.timestampUnixMs.toString(),
      ),
      MetadataEntry('Provider', dash(event.providerName)),
      MetadataEntry(
        'Event ID',
        event.winEventId == 0 ? dash('') : event.winEventId.toString(),
      ),
      MetadataEntry('Channel', dash(event.displayChannel)),
      MetadataEntry('Computer', dash(event.computerName)),
      MetadataEntry(
        'Level',
        dash(event.levelName.isNotEmpty
            ? event.levelName
            : event.severityVisual.label),
      ),
      MetadataEntry(
        'Task',
        event.hasTask ? event.task.toString() : dash(''),
      ),
      MetadataEntry(
        'Opcode',
        event.hasOpcode ? event.opcode.toString() : dash(''),
      ),
      MetadataEntry('Keywords', dash(hexKeywords())),
      MetadataEntry(
        'Process',
        dash(event.processName),
      ),
      MetadataEntry(
        'PID',
        event.hasProcessId ? event.processId.toString() : dash(''),
      ),
      MetadataEntry(
        'Thread ID',
        event.hasThreadId ? event.threadId.toString() : dash(''),
      ),
      MetadataEntry('User (SID)', dash(event.userSid)),
      MetadataEntry(
        'Record ID',
        event.recordId == 0 ? dash('') : event.recordId.toString(),
      ),
      MetadataEntry('Activity ID', dash(event.activityId)),
      MetadataEntry(
        'Related Activity ID',
        dash(event.relatedActivityId),
      ),
      MetadataEntry('Category', dash(event.category)),
      MetadataEntry('Importance', dash(event.importanceLabel)),
      MetadataEntry(
        'Pulse event id',
        dense
            ? (event.eventId.isEmpty ? '—' : event.eventId)
            : dash(event.eventId),
      ),
    ];
  }

  /// Hides or shows again every event with this provider and Event ID
  /// (issue #25). Only Pulse's view changes; Windows' logs stay as they are.
  Future<void> _toggleHiddenType(TimelineLibraryController library) async {
    final key = hiddenEventTypeKeyOf(event);
    if (key == null) return;
    if (library.isHiddenType(event)) {
      await library.showEventType(key);
      if (!mounted) return;
      PulseSnack.info(context, 'Events like this show in the Timeline again.');
      return;
    }
    await library.hideEventType(event, title: event.displayTitle);
    if (!mounted) return;
    PulseSnack.info(
      context,
      'Hidden: ${event.providerName}, Event ID ${event.winEventId}. '
      'They stay in reports and exports. Show them again here or in Settings.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = event.severityVisual;
    final library = context.watch<TimelineLibraryController>();
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, PulseTokens.pagePadX, 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PulseTokens.surface,
          borderRadius: BorderRadius.circular(PulseTokens.radiusCard),
          border: Border.all(color: PulseTokens.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailsHeader(
              onClose: widget.onClose,
              bookmarked: library.isBookmarked(event.eventId),
              pinned: library.isPinned(event.eventId),
              onToggleBookmark: () => context
                  .read<TimelineLibraryController>()
                  .toggleBookmark(event.eventId),
              onTogglePin: () => context
                  .read<TimelineLibraryController>()
                  .togglePin(event.eventId),
              hiddenType: library.isHiddenType(event),
              onToggleHiddenType: hiddenEventTypeKeyOf(event) == null
                  ? null
                  : () => _toggleHiddenType(library),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PulseBadge(
                        label: style.label,
                        tone: style.tone,
                        compact: true,
                      ),
                      if (widget.isLive)
                        const PulseBadge(
                          label: 'Live',
                          tone: PulseBadgeTone.success,
                          compact: true,
                        ),
                      Text(
                        '${event.absoluteTimeLabel} · ${event.relativeTimeLabel}',
                        style: textTheme.bodySmall?.copyWith(
                          fontFamily: PulseTheme.monoFont,
                          fontFamilyFallback: PulseTheme.monoFallback,
                          color: PulseTokens.textTertiary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    event.displayTitle,
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.displaySummary,
                    style: textTheme.bodyLarge?.copyWith(
                      color: PulseTokens.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LevelTabs(
                    selected: _level,
                    onSelected: (level) {
                      setState(() => _level = level);
                      if (level == _DetailLevel.raw) _loadRawXml();
                    },
                  ),
                  const SizedBox(height: 18),
                  ...switch (_level) {
                    _DetailLevel.explained => _explained(context, library),
                    _DetailLevel.technical => _technical(context),
                    _DetailLevel.raw => _raw(context),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Level 1 — what it means and whether the user needs to act.
  List<Widget> _explained(
    BuildContext context,
    TimelineLibraryController library,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final needsAction = event.actionRequired;
    final tone = needsAction ? PulseTokens.severityWarning : PulseTokens.success;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(PulseTokens.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              needsAction ? LucideIcons.circleAlert : LucideIcons.circleCheck,
              size: 20,
              color: tone,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    needsAction ? 'Worth a look' : 'No action needed',
                    style: textTheme.titleSmall?.copyWith(
                      color: PulseTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.showRecommendationSection
                        ? event.recommendation.trim()
                        : needsAction
                            ? event.actionGuidance
                            : 'Windows logged this for your information. '
                                'Nothing here needs fixing.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: PulseTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PulseBadge(
            label: '${event.importanceLabel} importance',
            tone: needsAction ? PulseBadgeTone.warning : PulseBadgeTone.neutral,
            compact: true,
          ),
          if (event.category.isNotEmpty)
            PulseBadge(label: event.category, compact: true),
          if (widget.rcaHint != null)
            const PulseBadge(label: 'Correlated', compact: true),
          if (library.isBookmarked(event.eventId))
            const PulseBadge(label: 'Bookmarked', compact: true),
          if (library.isPinned(event.eventId))
            const PulseBadge(label: 'Pinned', compact: true),
        ],
      ),
      if (widget.rcaHint != null) ...[
        const SizedBox(height: 8),
        DetailSection(
          title: 'Possible cause',
          child: _RcaHintBox(hint: widget.rcaHint!),
        ),
      ],
      if (widget.onSelectRelated != null) ...[
        const SizedBox(height: 8),
        DetailSection(
          title: 'Event links',
          child: _EventLinks(
            event: event,
            relatedIds: widget.rcaHint?.relatedEventIds ?? const [],
            pool: widget.relatedEvents,
            onSelect: widget.onSelectRelated!,
          ),
        ),
      ],
    ];
  }

  /// Level 2 — technical summary, structured fields, original message.
  List<Widget> _technical(BuildContext context) {
    return [
      if (event.technicalSummary.isNotEmpty) ...[
        Text(
          event.technicalSummary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PulseTokens.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
      ],
      DetailSection(
        title: 'Technical information',
        child: MetadataTable(entries: _technicalEntries(dense: false)),
      ),
      DetailSection(
        title: 'Original Windows message',
        child: _OriginalMessageBox(
          message: event.message.isNotEmpty
              ? event.message
              : 'No original Event Viewer message was available for this entry.',
        ),
      ),
    ];
  }

  /// Level 3 — the complete Event XML, loaded on demand.
  List<Widget> _raw(BuildContext context) {
    return [
      _RawXmlSection(
        loading: _loadingXml,
        error: _xmlError,
        xml: _rawXml,
        onLoad: _loadRawXml,
        loaded: _xmlRequested && !_loadingXml,
      ),
      DetailSection(
        title: 'Raw metadata',
        child: MetadataTable(
          dense: true,
          entries: _technicalEntries(dense: true),
        ),
      ),
    ];
  }
}

/// Information hierarchy from AGENTS.md: human → technical → raw.
enum _DetailLevel { explained, technical, raw }

class _LevelTabs extends StatelessWidget {
  const _LevelTabs({required this.selected, required this.onSelected});

  final _DetailLevel selected;
  final ValueChanged<_DetailLevel> onSelected;

  static const _labels = {
    _DetailLevel.explained: 'Explained',
    _DetailLevel.technical: 'Technical',
    _DetailLevel.raw: 'Raw XML',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PulseTokens.canvas,
        borderRadius: BorderRadius.circular(PulseTokens.radiusLg),
        border: Border.all(color: PulseTokens.stroke),
      ),
      child: Row(
        children: [
          for (final level in _DetailLevel.values)
            Expanded(
              child: Semantics(
                selected: level == selected,
                button: true,
                child: Material(
                  color: level == selected
                      ? PulseTokens.surfaceHover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(PulseTokens.radiusSm),
                  child: InkWell(
                    onTap: () => onSelected(level),
                    borderRadius: BorderRadius.circular(PulseTokens.radiusSm),
                    child: SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          _labels[level]!,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: level == selected
                                    ? PulseTokens.textPrimary
                                    : PulseTokens.textTertiary,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RcaHintBox extends StatelessWidget {
  const _RcaHintBox({required this.hint});

  final TimelineRcaHint hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint.possibleCause,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PulseTokens.textSecondary,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PulseBadge(
              label: 'Confidence: ${hint.confidenceLabel}',
              compact: true,
            ),
            PulseBadge(
              label: 'Rule ${hint.ruleId}',
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Suggested next step',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          hint.nextStep,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PulseTokens.textSecondary,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class _EventLinks extends StatelessWidget {
  const _EventLinks({
    required this.event,
    required this.relatedIds,
    required this.pool,
    required this.onSelect,
  });

  final TimelineEvent event;
  final List<String> relatedIds;
  final List<TimelineEvent> pool;
  final ValueChanged<TimelineEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    TimelineEvent? byId(String id) {
      for (final e in pool) {
        if (e.eventId == id) return e;
      }
      return null;
    }

    final related = [
      for (final id in relatedIds)
        if (id != event.eventId) byId(id),
    ].whereType<TimelineEvent>().toList();

    final sameProvider = pool
        .where(
          (e) =>
              e.eventId != event.eventId &&
              e.providerName.isNotEmpty &&
              e.providerName == event.providerName,
        )
        .take(3)
        .toList();

    final sameProcess = event.hasProcessId
        ? pool
            .where(
              (e) =>
                  e.eventId != event.eventId &&
                  e.hasProcessId &&
                  e.processId == event.processId,
            )
            .take(3)
            .toList()
        : const <TimelineEvent>[];

    Widget link(String label, TimelineEvent target) {
      return TextButton(
        onPressed: () => onSelect(target),
        child: Text(
          '$label · ${target.displayTitle}',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (related.isEmpty && sameProvider.isEmpty && sameProcess.isEmpty)
          Text(
            'No related events in the current Timeline view.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PulseTokens.textTertiary,
                ),
          ),
        for (var i = 0; i < related.length; i++)
          link(i == 0 ? 'Previous related' : 'Next related', related[i]),
        for (final e in sameProvider) link('Same provider', e),
        for (final e in sameProcess) link('Same process', e),
        if (relatedIds.length > 1)
          Text(
            'Same incident · ${relatedIds.length} events',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: PulseTokens.textTertiary,
                ),
          ),
      ],
    );
  }
}

class _RawXmlSection extends StatelessWidget {
  const _RawXmlSection({
    required this.loading,
    required this.error,
    required this.xml,
    required this.onLoad,
    required this.loaded,
  });

  final bool loading;
  final String? error;
  final String? xml;
  final VoidCallback onLoad;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    if (!loaded && !loading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onLoad,
          icon: const Icon(LucideIcons.fileCode, size: 16),
          label: const Text('Load Event XML'),
        ),
      );
    }
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading Event XML…'),
          ],
        ),
      );
    }
    if (error != null && (xml == null || xml!.isEmpty)) {
      return Text(
        error!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PulseTokens.severityWarning,
              height: 1.4,
            ),
      );
    }
    final text = xml ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Copy XML',
            onPressed: text.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: text)),
            icon: const Icon(LucideIcons.copy, size: 16),
          ),
        ),
        _OriginalMessageBox(message: text.isEmpty ? '(empty)' : text),
      ],
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({
    required this.onClose,
    required this.bookmarked,
    required this.pinned,
    required this.onToggleBookmark,
    required this.onTogglePin,
    required this.hiddenType,
    required this.onToggleHiddenType,
  });

  final VoidCallback onClose;
  final bool bookmarked;
  final bool pinned;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTogglePin;
  final bool hiddenType;

  /// Null when the event has no provider to match a type on.
  final VoidCallback? onToggleHiddenType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 2),
      child: Row(
        children: [
          Text(
            'Event details',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: PulseTokens.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            onPressed: onToggleBookmark,
            icon: Icon(
              bookmarked ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
              size: 17,
            ),
          ),
          IconButton(
            tooltip: pinned ? 'Unpin' : 'Pin',
            onPressed: onTogglePin,
            icon: Icon(
              pinned ? LucideIcons.pinOff : LucideIcons.pin,
              size: 17,
            ),
          ),
          if (onToggleHiddenType != null)
            IconButton(
              tooltip: hiddenType
                  ? 'Show events like this again'
                  : 'Hide events like this',
              onPressed: onToggleHiddenType,
              icon: Icon(
                hiddenType ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 17,
              ),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, size: 17),
          ),
        ],
      ),
    );
  }
}

class _OriginalMessageBox extends StatelessWidget {
  const _OriginalMessageBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseTokens.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(PulseTokens.radiusMd),
        border: Border.all(color: PulseTokens.strokeSubtle),
      ),
      child: SelectableText(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: PulseTokens.textSecondary,
              height: 1.45,
              fontFamily: PulseTheme.monoFont,
              fontFamilyFallback: PulseTheme.monoFallback,
            ),
      ),
    );
  }
}
