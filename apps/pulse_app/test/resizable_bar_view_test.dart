import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/presentation/health/health_view_models.dart';

void main() {
  test('Resizable BAR that Windows does not report reads as Unknown (#31)', () {
    // "Not supported" read as "this GPU lacks Resizable BAR".
    expect(formatResizableBar(false, false), 'Unknown');
    expect(formatResizableBar(true, true), 'Enabled');
    expect(formatResizableBar(true, false), 'Disabled');
    expect(kResizableBarHint, contains('NVIDIA Control Panel'));
  });
}
