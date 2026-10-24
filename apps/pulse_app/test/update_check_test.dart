import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/application/settings_controller.dart';
import 'package:pulse/application/update_check_controller.dart';
import 'package:pulse/logging/app_logger.dart';
import 'package:pulse/platform/github_release_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSource implements LatestReleaseSource {
  _FakeSource(this.result);

  Object result;
  int calls = 0;

  @override
  Future<ReleaseInfo> latest() async {
    calls++;
    final r = result;
    if (r is ReleaseInfo) return r;
    throw r;
  }
}

ReleaseInfo _release(String version) => ReleaseInfo(
      version: version,
      pageUrl: Uri.parse(
        '${GitHubLatestRelease.releasePagePrefix}tag/v$version',
      ),
    );

void main() {
  group('versions', () {
    test('compares major, minor and patch numerically', () {
      expect(isNewerVersion('1.4.0', '1.3.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.9'), isTrue);
      expect(isNewerVersion('1.3.0', '1.3.0'), isFalse);
      expect(isNewerVersion('1.2.9', '1.3.0'), isFalse);
      expect(isNewerVersion('2.0.0-beta', '1.9.0'), isTrue);
      expect(isNewerVersion('garbage', '1.3.0'), isFalse);
    });
  });

  group('GitHub release JSON', () {
    test('reads tag, page and notes', () {
      final release = GitHubLatestRelease.parseRelease(jsonEncode({
        'tag_name': 'v1.4.0',
        'html_url':
            'https://github.com/Regncreative/Pulse/releases/tag/v1.4.0',
        'name': 'Pulse 1.4.0',
        'body': 'Blue screen explainer',
        'published_at': '2026-10-20T10:00:00Z',
      }));
      expect(release.version, '1.4.0');
      expect(release.pageUrl.toString(), endsWith('/releases/tag/v1.4.0'));
      expect(release.notes, 'Blue screen explainer');
      expect(release.publishedAt, DateTime.utc(2026, 10, 20, 10));
    });

    test('never trusts a release page outside the Pulse repository', () {
      final release = GitHubLatestRelease.parseRelease(jsonEncode({
        'tag_name': 'v1.4.0',
        'html_url': 'https://example.com/phish',
      }));
      expect(
        release.pageUrl.toString(),
        'https://github.com/Regncreative/Pulse/releases/tag/v1.4.0',
      );
    });

    test('rejects answers without a version tag', () {
      expect(
        () => GitHubLatestRelease.parseRelease('{"message": "Not Found"}'),
        throwsA(isA<UpdateCheckException>()),
      );
      expect(
        () => GitHubLatestRelease.parseRelease('<html>'),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });

  group('UpdateCheckController', () {
    late SettingsController settings;
    final logger = AppLogger();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsController(logger: logger);
      await settings.load();
    });

    test('reports a newer release', () async {
      final updates = UpdateCheckController(
        settings: settings,
        logger: logger,
        source: _FakeSource(_release('1.5.0')),
        currentVersion: '1.4.0',
      );
      await updates.check();
      expect(updates.status, UpdateCheckStatus.available);
      expect(updates.latest!.version, '1.5.0');
    });

    test('reports up to date and failures', () async {
      final source = _FakeSource(_release('1.4.0'));
      final updates = UpdateCheckController(
        settings: settings,
        logger: logger,
        source: source,
        currentVersion: '1.4.0',
      );
      await updates.check();
      expect(updates.status, UpdateCheckStatus.upToDate);

      source.result = const UpdateCheckException('offline');
      await updates.check();
      expect(updates.status, UpdateCheckStatus.failed);
      expect(updates.error, 'offline');
    });

    test('automatic check is off by default and runs at most weekly',
        () async {
      var now = DateTime(2026, 10, 14);
      final source = _FakeSource(_release('1.4.0'));
      final updates = UpdateCheckController(
        settings: settings,
        logger: logger,
        source: source,
        currentVersion: '1.4.0',
        clock: () => now,
      );

      await updates.checkAutomaticallyIfDue();
      expect(source.calls, 0, reason: 'off by default');

      await settings.setCheckUpdatesAutomatically(true);
      await updates.checkAutomaticallyIfDue();
      expect(source.calls, 1);

      now = now.add(const Duration(days: 3));
      await updates.checkAutomaticallyIfDue();
      expect(source.calls, 1, reason: 'checked 3 days ago');

      now = now.add(const Duration(days: 5));
      await updates.checkAutomaticallyIfDue();
      expect(source.calls, 2);
    });
  });
}
