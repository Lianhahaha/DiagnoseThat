#pragma once

#include <string>

namespace pulse::util {

/// First Windows build number that ships as Windows 11 (version 21H2).
inline constexpr unsigned long kFirstWindows11Build = 22000;

/// Returns the marketing edition name for display.
///
/// Windows 11 keeps `ProductName` under
/// `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion` set to
/// "Windows 10 …" for compatibility; Microsoft identifies Windows 11 by
/// build number 22000 and later. When the build says Windows 11 and the
/// product name says Windows 10, only the leading "Windows 10" is replaced so
/// the edition suffix ("Pro", "Home", "Enterprise", …) is preserved.
///
/// `current_build` is the registry `CurrentBuild` string; any value that is
/// not a plain decimal number leaves `product_name` unchanged.
std::string NormalizeWindowsEdition(const std::string& product_name,
                                    const std::string& current_build);

}  // namespace pulse::util
