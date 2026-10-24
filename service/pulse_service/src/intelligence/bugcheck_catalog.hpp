#pragma once

#include <cstdint>
#include <string>
#include <string_view>

namespace pulse {

/// What a stop code most often points at, in plain language.
enum class BugcheckCause : std::uint8_t {
  Driver,
  Graphics,
  Memory,
  Hardware,
  Storage,
  Timeout,
  SystemProcess,
  Manual,
};

/// A stop code Pulse can name and explain.
struct BugcheckInfo {
  std::uint32_t code = 0;
  /// Symbolic name from Microsoft's Bug Check Code Reference.
  std::string_view name;
  BugcheckCause cause = BugcheckCause::Driver;
};

/// Common stop codes, or nullptr when the code is not in the catalog.
/// Names follow learn.microsoft.com/windows-hardware/drivers/debugger/bug-check-code-reference2.
[[nodiscard]] const BugcheckInfo* FindBugcheck(std::uint32_t code);

/// One-sentence explanation of what the cause usually means.
[[nodiscard]] std::string_view BugcheckCauseExplanation(BugcheckCause cause);

/// What the user can check next; empty when nothing is worth doing.
[[nodiscard]] std::string_view BugcheckCauseRecommendation(BugcheckCause cause);

/// "0x0000000A" — the eight-digit form Microsoft documents stop codes in.
[[nodiscard]] std::string FormatBugcheckCode(std::uint32_t code);

}  // namespace pulse
