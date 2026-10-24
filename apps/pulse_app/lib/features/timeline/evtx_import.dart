import 'dart:typed_data';

import 'package:pulse_protocol/pulse_wire.dart';

/// Event ids of imported events start with this (set by
/// `PulseService.exe --read-evtx`), so they never collide with live events.
const String kImportedEventIdPrefix = 'evtx:';

bool isImportedEvent(TimelineEvent event) =>
    event.eventId.startsWith(kImportedEventIdPrefix);

/// Events read from an exported .evtx file, newest first.
class EvtxImport {
  EvtxImport({
    required this.filePath,
    required this.events,
    required this.eventLimit,
  });

  final String filePath;
  final List<TimelineEvent> events;

  /// Most events one import reads; the file may hold more when reached.
  final int eventLimit;

  bool get reachedLimit => eventLimit > 0 && events.length >= eventLimit;

  String get fileName {
    final slash = filePath.lastIndexOf(RegExp(r'[\\/]'));
    return slash < 0 ? filePath : filePath.substring(slash + 1);
  }

  /// Computers the events came from, most frequent first.
  List<String> get computerNames {
    final counts = <String, int>{};
    for (final e in events) {
      if (e.computerName.isEmpty) continue;
      counts[e.computerName] = (counts[e.computerName] ?? 0) + 1;
    }
    final names = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names;
  }
}

/// Result of decoding the `--read-evtx` output file.
class DecodedEvtxImport {
  DecodedEvtxImport({required this.events, required this.eventLimit});

  final List<TimelineEvent> events;
  final int eventLimit;
}

/// Decodes the `--read-evtx` output: TimelineEvent frames followed by one
/// closing TimelineSnapshot. Throws [FormatException] when the file is cut
/// short or holds anything else.
DecodedEvtxImport decodeEvtxImport(Uint8List bytes) {
  final events = <TimelineEvent>[];
  var offset = 0;
  while (offset < bytes.length) {
    final frame = tryDecodeFrame(Uint8List.sublistView(bytes, offset));
    if (frame == null) {
      throw const FormatException('The import result ends mid-frame.');
    }
    offset += frame.consumed;
    final body = decodeEnvelope(frame.payload).body;
    if (body is TimelineEvent) {
      events.add(body);
    } else if (body is TimelineSnapshot) {
      if (offset != bytes.length) {
        throw const FormatException('Data follows the end of the import.');
      }
      return DecodedEvtxImport(
        events: events,
        eventLimit: body.requestedLimit,
      );
    } else {
      throw const FormatException('Unexpected message in the import result.');
    }
  }
  throw const FormatException('The import result is incomplete.');
}
