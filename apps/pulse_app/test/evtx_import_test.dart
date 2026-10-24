import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/timeline/evtx_import.dart';
import 'package:pulse_protocol/pulse_wire.dart';

Uint8List _frame(Object body) =>
    encodeFrame(encodeEnvelope(Envelope(body: body)));

Uint8List _concat(List<Uint8List> parts) {
  final builder = BytesBuilder(copy: false);
  for (final p in parts) {
    builder.add(p);
  }
  return builder.toBytes();
}

TimelineEvent _event(String id, {String computer = 'PC-1'}) => TimelineEvent(
      eventId: '$kImportedEventIdPrefix$id',
      providerName: 'Microsoft-Windows-Kernel-Power',
      winEventId: 41,
      computerName: computer,
      title: 'PC Lost Power or Stopped Suddenly',
    );

void main() {
  group('decodeEvtxImport', () {
    test('reads events up to the closing snapshot', () {
      final bytes = _concat([
        _frame(_event('a')),
        _frame(_event('b')),
        _frame(TimelineSnapshot(requestedLimit: 20000)),
      ]);
      final decoded = decodeEvtxImport(bytes);
      expect(decoded.events.map((e) => e.eventId), ['evtx:a', 'evtx:b']);
      expect(decoded.eventLimit, 20000);
      expect(decoded.events.first.title, 'PC Lost Power or Stopped Suddenly');
    });

    test('an empty log is still a complete result', () {
      final decoded = decodeEvtxImport(_frame(TimelineSnapshot()));
      expect(decoded.events, isEmpty);
    });

    test('rejects a result without the closing snapshot', () {
      final bytes = _concat([_frame(_event('a'))]);
      expect(() => decodeEvtxImport(bytes), throwsFormatException);
    });

    test('rejects a result cut mid-frame', () {
      final whole = _concat([
        _frame(_event('a')),
        _frame(TimelineSnapshot()),
      ]);
      final cut = Uint8List.sublistView(whole, 0, whole.length - 3);
      expect(() => decodeEvtxImport(cut), throwsFormatException);
    });
  });

  group('EvtxImport', () {
    test('names the file and the computers it came from', () {
      final imported = EvtxImport(
        filePath: r'C:\Users\me\Downloads\System.evtx',
        events: [
          _event('a', computer: 'SHOP-PC'),
          _event('b', computer: 'SHOP-PC'),
          _event('c', computer: 'OTHER'),
        ],
        eventLimit: 3,
      );
      expect(imported.fileName, 'System.evtx');
      expect(imported.computerNames, ['SHOP-PC', 'OTHER']);
      expect(imported.reachedLimit, isTrue);
    });

    test('imported events are recognised by their id', () {
      expect(isImportedEvent(_event('x')), isTrue);
      expect(
        isImportedEvent(TimelineEvent(eventId: 'System|123')),
        isFalse,
      );
    });
  });
}
