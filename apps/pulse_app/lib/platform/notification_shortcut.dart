import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../logging/app_logger.dart';

/// App name passed to `localNotifier.setup`. WinToast uses it as the
/// AppUserModelID and as the name of the Start menu shortcut it creates
/// (`%APPDATA%\Microsoft\Windows\Start Menu\Programs\<name>.lnk`).
const String kNotificationAppName = 'Pulse Diagnostics';

/// APPMODEL_ERROR_NO_APPLICATION: the process is not a packaged app.
const int _kAppModelErrorNoApplication = 15703;

typedef _GetAumidNative = Int32 Function(Pointer<Uint32>, Pointer<Utf16>);
typedef _GetAumidDart = int Function(Pointer<Uint32>, Pointer<Utf16>);

/// The Store (MSIX) package's AppUserModelID, e.g.
/// `Regncreative.PulseDiagnostics_epm7qp6hnh3h0!pulse`, or null outside a
/// package.
///
/// Toasts from a packaged app must use this id. With [kNotificationAppName]
/// WinToast set the process id to "Pulse Diagnostics", Windows read it as
/// `<package>!Pulse Diagnostics`, found no such app in the manifest and showed
/// that raw string instead of the app name and icon.
/// GetCurrentApplicationUserModelId is in kernel32 (appmodel.h, Windows 8+);
/// package:win32 has no binding for it.
String? packagedAppUserModelId() {
  if (!Platform.isWindows) return null;
  final _GetAumidDart getAumid;
  try {
    getAumid = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<_GetAumidNative, _GetAumidDart>(
      'GetCurrentApplicationUserModelId',
    );
  } on ArgumentError {
    return null;
  }
  final length = calloc<Uint32>();
  try {
    final probe = getAumid(length, nullptr);
    if (probe == _kAppModelErrorNoApplication) return null;
    if (probe != ERROR_INSUFFICIENT_BUFFER || length.value == 0) return null;
    final buffer = calloc<Uint16>(length.value).cast<Utf16>();
    try {
      if (getAumid(length, buffer) != ERROR_SUCCESS) return null;
      final id = buffer.toDartString();
      return id.isEmpty ? null : id;
    } finally {
      calloc.free(buffer);
    }
  } finally {
    calloc.free(length);
  }
}

/// SLGP_UNCPRIORITY: return the target path in its standard form.
const int _kSlgpUncPriority = 0x2;

/// Reads the target path of a `.lnk` file, or null when it cannot be read.
typedef ShortcutTargetReader = String? Function(String shortcutPath);

/// Removes the notification shortcut when it points to another `Pulse.exe`.
///
/// WinToast only checks that the shortcut exists, not where it points. Because
/// the taskbar takes Pulse's icon from the shortcut that carries its
/// AppUserModelID, a stale one (Pulse reinstalled elsewhere, a deleted dev
/// build) showed a blank taskbar icon. Deleting it lets `localNotifier.setup`
/// recreate it for the running executable. Returns true when it was removed.
bool removeStaleNotificationShortcut({
  required AppLogger logger,
  String? appData,
  String? currentExecutable,
  ShortcutTargetReader readTarget = readShortcutTarget,
}) {
  final roaming = appData ?? Platform.environment['APPDATA'];
  if (roaming == null || roaming.isEmpty) return false;
  final shortcut = File(
    '$roaming\\Microsoft\\Windows\\Start Menu\\Programs\\$kNotificationAppName.lnk',
  );
  if (!shortcut.existsSync()) return false;

  final current = currentExecutable ?? Platform.resolvedExecutable;
  final target = readTarget(shortcut.path);
  if (target != null && _samePath(target, current)) return false;

  try {
    shortcut.deleteSync();
    logger.info(
      'Notifications',
      'Removed stale shortcut (target: ${target ?? 'unreadable'}); it is '
          'recreated for $current',
    );
    return true;
  } on FileSystemException catch (e) {
    logger.warn('Notifications', 'Could not remove stale shortcut: $e');
    return false;
  }
}

bool _samePath(String a, String b) =>
    File(a).absolute.path.toLowerCase() == File(b).absolute.path.toLowerCase();

/// Reads a shortcut target with the Shell's IShellLink (COM must already be
/// initialized on this thread; the Flutter runner does so for the UI thread).
///
/// Do not call `release()` on the COM objects: package:win32 releases them
/// from a Finalizer, and an extra manual release is a use-after-free that
/// crashed Pulse.exe a few seconds after startup once the GC ran.
String? readShortcutTarget(String shortcutPath) {
  final link = ShellLink.createInstance();
  final persist = IPersistFile.from(link);
  final path = shortcutPath.toNativeUtf16();
  final buffer = calloc<Uint16>(MAX_PATH).cast<Utf16>();
  try {
    if (FAILED(persist.load(path, STGM_READ))) return null;
    if (FAILED(link.getPath(buffer, MAX_PATH, nullptr, _kSlgpUncPriority))) {
      return null;
    }
    final target = buffer.toDartString();
    return target.isEmpty ? null : target;
  } finally {
    free(path);
    calloc.free(buffer);
  }
}
