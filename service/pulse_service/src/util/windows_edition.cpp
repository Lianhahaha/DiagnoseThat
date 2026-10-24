#include "util/windows_edition.hpp"

#include <cctype>

namespace pulse::util {
namespace {

constexpr char kWindows10Prefix[] = "Windows 10";
constexpr char kWindows11Prefix[] = "Windows 11";

bool ParseBuild(const std::string& text, unsigned long* build) {
  if (text.empty()) return false;
  unsigned long value = 0;
  for (const char c : text) {
    if (!std::isdigit(static_cast<unsigned char>(c))) return false;
    value = value * 10 + static_cast<unsigned long>(c - '0');
  }
  *build = value;
  return true;
}

}  // namespace

std::string NormalizeWindowsEdition(const std::string& product_name,
                                    const std::string& current_build) {
  unsigned long build = 0;
  if (!ParseBuild(current_build, &build) || build < kFirstWindows11Build) {
    return product_name;
  }
  if (product_name.rfind(kWindows10Prefix, 0) != 0) return product_name;
  return kWindows11Prefix + product_name.substr(sizeof(kWindows10Prefix) - 1);
}

}  // namespace pulse::util
