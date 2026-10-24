/// Development feature flags for Pulse UI.
///
/// Enable mock timeline:
/// `flutter run -d windows --dart-define=PULSE_MOCK_TIMELINE=true`
library;

const bool kUseMockTimeline = bool.fromEnvironment(
  'PULSE_MOCK_TIMELINE',
  defaultValue: false,
);

/// Shell page shown at launch (development and screenshot automation only).
///
/// `flutter run -d windows --dart-define=PULSE_START_PAGE=1`
/// 0 Timeline · 1 Health · 2 Inventory · 3 Reports · 4 Diagnostics ·
/// 5 Settings · 6 Assistant. Out-of-range values fall back to Timeline.
const int kStartPage = int.fromEnvironment(
  'PULSE_START_PAGE',
  defaultValue: 0,
);

/// Named pipe the IPC client connects to (development and testing only).
///
/// Pair with `PulseService.exe --console --pipe <name>` to test reconnects
/// without touching the installed service:
/// `flutter run -d windows --dart-define=PULSE_PIPE_NAME=\.\pipe\PulseServiceDev`
const String kPipeNameOverride = String.fromEnvironment('PULSE_PIPE_NAME');
