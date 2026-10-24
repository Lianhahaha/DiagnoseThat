import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Pages Pulse may open in the browser: its own GitHub project only.
const String kPulseGitHubPrefix = 'https://github.com/Regncreative/Pulse/';

/// ShellExecute returns a value greater than 32 on success.
const int _kShellExecuteSuccessFloor = 32;

/// Opens [url] in the default browser. Refuses anything outside
/// [kPulseGitHubPrefix], so data from the network can never make Pulse open
/// another site. Returns false when it was refused or Windows failed.
bool openPulseGitHubPage(Uri url) {
  final text = url.toString();
  if (!Platform.isWindows || !text.startsWith(kPulseGitHubPrefix)) {
    return false;
  }
  final operation = 'open'.toNativeUtf16();
  final file = text.toNativeUtf16();
  try {
    final result =
        ShellExecute(NULL, operation, file, nullptr, nullptr, SW_SHOWNORMAL);
    return result > _kShellExecuteSuccessFloor;
  } finally {
    calloc.free(operation);
    calloc.free(file);
  }
}
