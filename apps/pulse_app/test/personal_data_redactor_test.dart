import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/privacy/personal_data_redactor.dart';

void main() {
  final redactor = PersonalDataRedactor(
    userNames: ['ozsin', 'Sinan'],
    computerNames: ['DESKTOP-ABC123', 'SHOP-PC'],
    secrets: ['WD-WX12A3456789', 'To Be Filled By O.E.M.', '0'],
  );

  test('masks the user part of profile paths, even for other users', () {
    expect(
      redactor.redact(r'Faulting module C:\Users\jane.doe\AppData\x.dll'),
      r'Faulting module C:\Users\[user]\AppData\x.dll',
    );
    // JSON-escaped paths keep their double backslashes.
    expect(
      redactor.redact(r'"path": "C:\\Users\\ozsin\\Downloads"'),
      r'"path": "C:\\Users\\[user]\\Downloads"',
    );
  });

  test('keeps shared profile folders', () {
    expect(
      redactor.redact(r'C:\Users\Public\Documents'),
      r'C:\Users\Public\Documents',
    );
  });

  test('masks user and computer names as whole words only', () {
    expect(
      redactor.redact('Logon by SINAN on desktop-abc123.'),
      'Logon by [user] on [computer].',
    );
    expect(redactor.redact('Sinanoglu Holding'), 'Sinanoglu Holding');
  });

  test('masks account SIDs, keeps well-known ones', () {
    expect(
      redactor.redact('User S-1-5-21-1004336348-1177238915-682003330-1001'),
      'User S-1-5-21-[sid]',
    );
    expect(redactor.redact('SYSTEM S-1-5-18'), 'SYSTEM S-1-5-18');
  });

  test('masks e-mail, IPv4 and MAC addresses', () {
    expect(
      redactor.redact('me@example.com 192.168.1.20 AA:BB:CC:DD:EE:FF'),
      '[email] [ip] [mac]',
    );
  });

  test('keeps loopback IPs and version numbers', () {
    expect(redactor.redact('127.0.0.1 0.0.0.0'), '127.0.0.1 0.0.0.0');
    expect(redactor.redact('Windows 10.0.26200.9711'), 'Windows 10.0.26200.9711');
    expect(redactor.redact('Driver 31.0.101.5445'), 'Driver 31.0.101.5445');
  });

  test('masks real serial numbers, not firmware placeholders', () {
    expect(
      redactor.redact('Disk WD-WX12A3456789, board To Be Filled By O.E.M.'),
      'Disk [serial], board To Be Filled By O.E.M.',
    );
  });

  test('redacts strings anywhere in JSON, keeps other values', () {
    final out = redactor.redactJson({
      'computer': 'SHOP-PC',
      'count': 3,
      'events': [
        {'message': r'C:\Users\Sinan\x.txt', 'ok': true},
      ],
    });
    expect(out, {
      'computer': '[computer]',
      'count': 3,
      'events': [
        {'message': r'C:\Users\[user]\x.txt', 'ok': true},
      ],
    });
  });

  test('ignores names too short to mask safely', () {
    final short = PersonalDataRedactor(userNames: ['a'], computerNames: ['']);
    expect(short.redact('a cat'), 'a cat');
  });
}
