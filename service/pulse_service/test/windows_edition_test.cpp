#include "util/windows_edition.hpp"

#include <iostream>
#include <string>

namespace {

struct EditionCase {
  const char* product;
  const char* build;
  const char* expected;
};

constexpr EditionCase kCases[] = {
    // Windows 11 machines still report "Windows 10" in ProductName.
    {"Windows 10 Pro", "26200", "Windows 11 Pro"},
    {"Windows 10 Home", "22000", "Windows 11 Home"},
    // Real Windows 10 builds stay untouched.
    {"Windows 10 Pro", "19045", "Windows 10 Pro"},
    // Already-correct names and other products are left alone.
    {"Windows 11 Pro", "26100", "Windows 11 Pro"},
    {"Windows Server 2025 Datacenter", "26100",
     "Windows Server 2025 Datacenter"},
    // Missing or malformed builds never change the name.
    {"Windows 10 Pro", "", "Windows 10 Pro"},
    {"Windows 10 Pro", "26200.1", "Windows 10 Pro"},
};

}  // namespace

int main() {
  int index = 0;
  for (const auto& c : kCases) {
    ++index;
    const auto actual = pulse::util::NormalizeWindowsEdition(c.product, c.build);
    if (actual != c.expected) {
      std::cerr << "case " << index << ": NormalizeWindowsEdition(\""
                << c.product << "\", \"" << c.build << "\") = \"" << actual
                << "\", expected \"" << c.expected << "\"\n";
      return index;
    }
  }
  std::cout << "windows_edition_tests OK (" << index << " cases)\n";
  return 0;
}
