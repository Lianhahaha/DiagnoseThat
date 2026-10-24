import 'package:pulse_protocol/pulse_wire.dart';

/// An event type the user chose to hide from the Timeline (issue #25):
/// every event with this provider and Event ID.
///
/// Hiding only changes what Pulse shows. Windows' logs are untouched, the
/// events stay in reports and exports, and Settings lists every hidden type
/// so it can be shown again.
class HiddenEventType {
  const HiddenEventType({
    required this.provider,
    required this.eventId,
    required this.title,
    required this.hiddenAtUnixMs,
  });

  /// Provider name as Windows reports it, e.g. "Microsoft-Windows-TPM-WMI".
  final String provider;
  final int eventId;

  /// The event's title when it was hidden, so Settings can name it.
  final String title;
  final int hiddenAtUnixMs;

  String get key => hiddenEventTypeKey(provider, eventId);

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'event_id': eventId,
        'title': title,
        'hidden_at_unix_ms': hiddenAtUnixMs,
      };

  static HiddenEventType? fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim() ?? '';
    final eventId = json['event_id'];
    if (provider.isEmpty || eventId is! num) return null;
    return HiddenEventType(
      provider: provider,
      eventId: eventId.toInt(),
      title: json['title']?.toString() ?? '',
      hiddenAtUnixMs: (json['hidden_at_unix_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Provider names are case-insensitive in Windows, so the key is too.
String hiddenEventTypeKey(String provider, int eventId) =>
    '${provider.trim().toLowerCase()}#$eventId';

/// The key of [event]'s type, or null when it has no provider to match on.
String? hiddenEventTypeKeyOf(TimelineEvent event) {
  if (event.providerName.trim().isEmpty) return null;
  return hiddenEventTypeKey(event.providerName, event.winEventId);
}
