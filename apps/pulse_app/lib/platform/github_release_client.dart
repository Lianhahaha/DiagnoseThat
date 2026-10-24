import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pulse_protocol/pulse_constants.dart';

/// The newest published Pulse release on GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.pageUrl,
    this.title = '',
    this.notes = '',
    this.publishedAt,
  });

  /// "1.4.0" (tag without the leading "v").
  final String version;

  /// Release page on github.com (validated, never another host).
  final Uri pageUrl;
  final String title;
  final String notes;
  final DateTime? publishedAt;
}

/// A user-facing reason the check failed.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the latest release comes from (replaced in tests).
abstract class LatestReleaseSource {
  Future<ReleaseInfo> latest();
}

/// Reads `GET /repos/Regncreative/Pulse/releases/latest` from the GitHub API.
///
/// The request carries only what HTTP needs (Pulse's version in the
/// User-Agent, which GitHub requires). Nothing about this PC is sent.
class GitHubLatestRelease implements LatestReleaseSource {
  const GitHubLatestRelease({this.timeout = const Duration(seconds: 10)});

  static final Uri _endpoint = Uri.parse(
    'https://api.github.com/repos/Regncreative/Pulse/releases/latest',
  );

  /// Release pages must stay on this prefix before Pulse opens them.
  static const releasePagePrefix =
      'https://github.com/Regncreative/Pulse/releases/';

  final Duration timeout;

  @override
  Future<ReleaseInfo> latest() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(_endpoint).timeout(timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'Pulse/$kAppVersion');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(
            timeout,
          );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateCheckException(
          'GitHub answered with status ${response.statusCode}. Try again '
          'later.',
        );
      }
      return parseRelease(body);
    } on UpdateCheckException {
      rethrow;
    } on TimeoutException {
      throw const UpdateCheckException(
        'GitHub did not answer in time. Check the internet connection.',
      );
    } on SocketException {
      throw const UpdateCheckException(
        'Could not reach GitHub. Check the internet connection.',
      );
    } on HandshakeException {
      throw const UpdateCheckException(
        'A secure connection to GitHub could not be made.',
      );
    } on HttpException catch (e) {
      throw UpdateCheckException('Could not reach GitHub (${e.message}).');
    } finally {
      client.close(force: true);
    }
  }

  /// Parses the GitHub "release" JSON. Throws [UpdateCheckException].
  static ReleaseInfo parseRelease(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const UpdateCheckException('GitHub sent an unreadable answer.');
    }
    if (decoded is! Map) {
      throw const UpdateCheckException('GitHub sent an unexpected answer.');
    }
    final tag = (decoded['tag_name'] as String? ?? '').trim();
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (parseVersion(version) == null) {
      throw UpdateCheckException('The latest release tag "$tag" is not a '
          'version Pulse understands.');
    }
    final page = decoded['html_url'] as String? ?? '';
    final pageUrl = page.startsWith(releasePagePrefix)
        ? Uri.parse(page)
        : Uri.parse('${releasePagePrefix}tag/$tag');
    return ReleaseInfo(
      version: version,
      pageUrl: pageUrl,
      title: decoded['name'] as String? ?? '',
      notes: decoded['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
    );
  }
}

/// [major, minor, patch] of "1.4.0" (pre-release suffixes ignored), or null.
List<int>? parseVersion(String version) {
  final core = version.split(RegExp(r'[-+]')).first;
  final parts = core.split('.');
  if (parts.length != 3) return null;
  final numbers = [for (final p in parts) int.tryParse(p)];
  if (numbers.any((n) => n == null || n < 0)) return null;
  return [for (final n in numbers) n!];
}

/// True when [candidate] is a newer version than [current].
bool isNewerVersion(String candidate, String current) {
  final a = parseVersion(candidate);
  final b = parseVersion(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}
