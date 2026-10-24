import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/presentation/utils/pulse_user_errors.dart';
import 'package:pulse/ipc/pulse_ipc_client.dart';

void main() {
  test('maps offline and timeout errors to friendly copy', () {
    expect(
      PulseUserErrors.fromMessage('CreateFile failed: 2'),
      contains('offline'),
    );
    expect(
      PulseUserErrors.fromMessage('TimeoutException after 0:00:05.000000'),
      contains('too long'),
    );
    expect(
      PulseUserErrors.connectionHint(IpcConnectionState.connecting),
      contains('Looking for PulseService'),
    );
  });

  test('UAC cancel and Windows denial get different messages', () {
    final cancelled = PulseUserErrors.fromMessage(
      'Administrator approval was cancelled. Pulse did not change the service.',
    );
    final denied = PulseUserErrors.fromMessage(
      'Windows blocked the administrator request (error 5). A security '
      'policy or security software may be preventing elevation.',
    );

    expect(cancelled, contains('cancelled'));
    expect(denied, contains('error 5'));
    expect(denied, contains('services.msc'));
    expect(cancelled, isNot(equals(denied)));
  });
}
