import 'dart:io';

/// Masks details that identify a person or a machine in exported files, so a
/// report can be shared (for example in a forum or support ticket).
///
/// Masked:
/// - user names and the user part of `C:\Users\<name>\` paths → `[user]`
/// - computer names → `[computer]`
/// - account SIDs (`S-1-5-21-…`) → `S-1-5-21-[sid]`
/// - e-mail addresses → `[email]`
/// - IPv4 and MAC addresses → `[ip]` / `[mac]`
/// - hardware identifiers given as [secrets] (serial numbers, asset tags)
///   → `[serial]`
///
/// Tokens use square brackets so they survive HTML, CSV, JSON and PDF.
///
/// Kept: Event IDs, providers, timestamps, versions, hardware models — what
/// is needed to understand a problem. Well-known SIDs (S-1-5-18 SYSTEM, …)
/// and loopback / unspecified IPs are not personal and stay.
class PersonalDataRedactor {
  PersonalDataRedactor({
    Iterable<String> userNames = const [],
    Iterable<String> computerNames = const [],
    Iterable<String> secrets = const [],
  })  : _userNames = _usable(userNames),
        _computerNames = _usable(computerNames),
        _secrets = _usable(secrets.where((s) => !_isPlaceholder(s)));

  /// Uses this PC's user, profile folder and computer name, plus any names
  /// found in the exported data (an imported .evtx may come from another PC).
  factory PersonalDataRedactor.forThisPc({
    Iterable<String> extraComputerNames = const [],
    Iterable<String> secrets = const [],
  }) {
    final env = Platform.environment;
    final profile = env['USERPROFILE'] ?? '';
    final profileName = profile.isEmpty
        ? ''
        : profile.split(RegExp(r'[\\/]')).lastWhere(
              (part) => part.isNotEmpty,
              orElse: () => '',
            );
    final computer = env['COMPUTERNAME'] ?? '';
    final domain = env['USERDOMAIN'] ?? '';
    return PersonalDataRedactor(
      userNames: [env['USERNAME'] ?? '', profileName],
      computerNames: [
        computer,
        if (domain.toUpperCase() != computer.toUpperCase()) domain,
        ...extraComputerNames,
      ],
      secrets: secrets,
    );
  }

  static const userToken = '[user]';
  static const computerToken = '[computer]';
  static const serialToken = '[serial]';

  /// Shorter names would match inside ordinary words.
  static const _minNameLength = 2;

  /// Shorter hardware identifiers are not identifying (and are often "0").
  static const _minSecretLength = 4;

  /// Values firmware ships when nobody set a real serial number.
  static const _placeholders = {
    'to be filled by o.e.m.',
    'default string',
    'not specified',
    'not applicable',
    'none',
    'n/a',
    'unknown',
    'system serial number',
    'chassis serial number',
    'base board serial number',
    '0123456789',
  };

  static final _profilePath = RegExp(
    r'([A-Za-z]:\\+Users\\+)([^\\/:*?"<>|\r\n]+)',
    caseSensitive: false,
  );

  /// Shared profile folders that do not identify anyone.
  static const _sharedProfiles = {'public', 'default', 'default user',
      'all users'};

  static final _accountSid = RegExp(r'S-1-5-21(?:-\d+){3,4}');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
  static final _mac = RegExp(r'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b');
  static final _ipv4 = RegExp(r'\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b');

  final List<String> _userNames;
  final List<String> _computerNames;
  final List<String> _secrets;

  /// Masks [text]; returns it unchanged when nothing matches.
  String redact(String text) {
    if (text.isEmpty) return text;
    var out = text;
    for (final secret in _secrets) {
      out = _replaceLiteral(out, secret, serialToken);
    }
    out = out.replaceAllMapped(_profilePath, (m) {
      final name = m.group(2)!;
      if (_sharedProfiles.contains(name.toLowerCase())) return m.group(0)!;
      return '${m.group(1)}$userToken';
    });
    for (final name in _userNames) {
      out = _replaceWord(out, name, userToken);
    }
    for (final name in _computerNames) {
      out = _replaceWord(out, name, computerToken);
    }
    out = out.replaceAll(_accountSid, 'S-1-5-21-[sid]');
    out = out.replaceAll(_email, '[email]');
    out = out.replaceAll(_mac, '[mac]');
    out = out.replaceAllMapped(_ipv4, (m) {
      final octets = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
      if (octets.any((o) => o > 255)) return m.group(0)!; // a version number
      if (octets[0] == 127 || octets.every((o) => o == 0)) return m.group(0)!;
      return '[ip]';
    });
    return out;
  }

  /// Masks every string inside decoded JSON (maps, lists, strings).
  Object? redactJson(Object? value) {
    if (value is String) return redact(value);
    if (value is List) return [for (final v in value) redactJson(v)];
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key: redactJson(entry.value),
      };
    }
    return value;
  }

  static List<String> _usable(Iterable<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in values) {
      final v = raw.trim();
      if (v.length < _minNameLength) continue;
      if (seen.add(v.toLowerCase())) out.add(v);
    }
    // Longest first, so "SHOP-PC-2" is masked before "SHOP-PC".
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  static bool _isPlaceholder(String value) {
    final v = value.trim();
    return v.length < _minSecretLength ||
        _placeholders.contains(v.toLowerCase()) ||
        RegExp(r'^[0\s.-]+$').hasMatch(v);
  }

  static String _replaceLiteral(String text, String value, String token) =>
      text.replaceAll(
        RegExp(RegExp.escape(value), caseSensitive: false),
        token,
      );

  /// Whole-word, case-insensitive: "Sinan" masks "sinan\" and "sinan," but
  /// not "Sinanoglu".
  static String _replaceWord(String text, String value, String token) =>
      text.replaceAll(
        RegExp(
          '(?<![A-Za-z0-9_])${RegExp.escape(value)}(?![A-Za-z0-9_])',
          caseSensitive: false,
        ),
        token,
      );
}
