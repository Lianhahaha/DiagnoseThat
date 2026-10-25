#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

// DiagnoseThat runs once per Windows session. Starting it again brings the running
// DiagnoseThat forward (it may be hidden in the tray) instead of opening a second
// window that would duplicate the tray icon, notifications and service
// connection.

// "Local\" scopes the mutex to this session, so other users signed in on the
// same PC run their own DiagnoseThat.
constexpr wchar_t kSingleInstanceMutexName[] =
    L"Local\\Regncreative.DiagnoseThat.SingleInstance";

// Posted by a second launch; the running DiagnoseThat shows its window.
constexpr wchar_t kActivateMessageName[] = L"Regncreative.DiagnoseThat.Activate";

// Method channel the runner uses to ask Dart to show the window, so the tray
// state kept by BackgroundModeController stays right.
constexpr char kSingleInstanceChannel[] = "pulse/single_instance";

// The registered activation message, or 0 if registration failed.
inline UINT PulseActivateMessage() {
  static const UINT message = ::RegisterWindowMessageW(kActivateMessageName);
  return message;
}

#endif  // RUNNER_SINGLE_INSTANCE_H_
