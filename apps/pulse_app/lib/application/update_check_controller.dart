import 'package:flutter/foundation.dart';
import 'package:pulse_protocol/pulse_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import '../platform/github_release_client.dart';
import 'settings_controller.dart';

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

/// Tells the GitHub edition when a newer Pulse is published.
///
/// Never downloads or installs anything: it reads the latest release from
/// GitHub and links to its page. Checks happen when the user asks, or once a
/// week when "Check automatically" is on (off by default). The Store edition
/// does not use this; the Store updates Pulse itself.
class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({
    required this.settings,
    required this.logger,
    LatestReleaseSource? source,
    this.currentVersion = kAppVersion,
    DateTime Function()? clock,
  })  : _source = source ?? const GitHubLatestRelease(),
        _clock = clock ?? DateTime.now;

  final SettingsController settings;
  final AppLogger logger;
  final String currentVersion;
  final LatestReleaseSource _source;
  final DateTime Function() _clock;

  static const automaticCheckInterval = Duration(days: 7);
  static const _kLastCheckUnixMs = 'updates.last_check_unix_ms';

  UpdateCheckStatus _status = UpdateCheckStatus.idle;
  ReleaseInfo? _latest;
  String? _error;
  DateTime? _lastCheckedAt;

  UpdateCheckStatus get status => _status;

  /// The newer release when [status] is [UpdateCheckStatus.available].
  ReleaseInfo? get latest => _latest;
  String? get error => _error;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  Future<void> check() async {
    if (_status == UpdateCheckStatus.checking) return;
    _status = UpdateCheckStatus.checking;
    _error = null;
    notifyListeners();
    try {
      final release = await _source.latest();
      if (isNewerVersion(release.version, currentVersion)) {
        _latest = release;
        _status = UpdateCheckStatus.available;
        logger.info('Updates', 'Pulse ${release.version} is available');
      } else {
        _latest = null;
        _status = UpdateCheckStatus.upToDate;
      }
      await _recordCheck();
    } on UpdateCheckException catch (e) {
      _status = UpdateCheckStatus.failed;
      _error = e.message;
      logger.warn('Updates', 'Update check failed: ${e.message}');
    }
    notifyListeners();
  }

  /// Runs [check] when automatic checks are on and the last one was more
  /// than [automaticCheckInterval] ago.
  Future<void> checkAutomaticallyIfDue() async {
    if (!settings.checkUpdatesAutomatically) return;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastCheckUnixMs);
    if (lastMs != null) {
      _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (_clock().difference(_lastCheckedAt!) < automaticCheckInterval) {
        return;
      }
    }
    await check();
  }

  Future<void> _recordCheck() async {
    _lastCheckedAt = _clock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastCheckUnixMs,
      _lastCheckedAt!.millisecondsSinceEpoch,
    );
  }
}
