#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "single_instance.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // window_manager's destroy() only posts WM_QUIT, so the window can still
  // exist when this object goes away. Deleting the controller destroys the
  // Flutter view, whose window sends WM_PARENTNOTIFY to this window. The
  // unique_ptr destructor deletes without clearing the pointer, so
  // MessageHandler forwarded that message to a half-destroyed controller and
  // crashed (issue #32). reset() clears the pointer first, so the message is
  // no longer forwarded.
  single_instance_channel_.reset();
  flutter_controller_.reset();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  single_instance_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kSingleInstanceChannel,
          &flutter::StandardMethodCodec::GetInstance());
  // Let a second launch reach this window even when this Pulse runs at a
  // higher integrity level (for example started by an elevated installer).
  // The message carries no data; it only asks this window to show itself.
  if (const UINT activate = PulseActivateMessage(); activate != 0) {
    ::ChangeWindowMessageFilterEx(GetHandle(), activate, MSGFLT_ALLOW,
                                  nullptr);
  }

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  single_instance_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // A second launch of Pulse asked for this window. Dart shows it through
  // window_manager, which also undoes "hidden in the tray".
  if (const UINT activate = PulseActivateMessage();
      activate != 0 && message == activate) {
    if (single_instance_channel_) {
      single_instance_channel_->InvokeMethod("activate", nullptr);
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
