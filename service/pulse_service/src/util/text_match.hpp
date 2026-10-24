#pragma once

#include <algorithm>
#include <cctype>
#include <string_view>

namespace pulse {

/// ASCII case-insensitive substring test; an empty needle always matches.
/// Used for Event Log provider names, which are ASCII.
[[nodiscard]] inline bool ContainsIgnoreCase(std::string_view haystack,
                                             std::string_view needle) {
  if (needle.empty()) {
    return true;
  }
  if (haystack.size() < needle.size()) {
    return false;
  }
  auto pred = [](unsigned char a, unsigned char b) {
    return std::tolower(a) == std::tolower(b);
  };
  return std::search(haystack.begin(), haystack.end(), needle.begin(),
                     needle.end(), pred) != haystack.end();
}

}  // namespace pulse
