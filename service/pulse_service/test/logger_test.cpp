#include "logging/logger.hpp"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>

// CI builds Release, where assert() is compiled out; fail loudly instead.
#define CHECK(condition)                                                  \
  do {                                                                    \
    if (!(condition)) {                                                   \
      std::cerr << __FILE__ << ":" << __LINE__ << " CHECK failed: "       \
                << #condition << "\n";                                    \
      std::exit(1);                                                       \
    }                                                                     \
  } while (false)

int main() {
  namespace fs = std::filesystem;
  const fs::path dir =
      fs::temp_directory_path() /
      ("pulse-logger-test-" + std::to_string(std::rand()) + "-" +
       std::to_string(fs::file_time_type::clock::now().time_since_epoch().count()));
  fs::create_directories(dir);

  auto& logger = pulse::Logger::Instance();
  logger.SetLogDirectory(dir.wstring());
  // "Odmowa dostępu" (Polish, issue #29) as UTF-8 bytes.
  const std::string polish = "Odmowa dost\xC4\x99pu";
  logger.Warn("Test", polish);
  logger.Info("Test", "second line");
  logger.SetLogDirectory(L"");

  fs::path file;
  for (const auto& entry : fs::directory_iterator(dir)) {
    file = entry.path();
  }
  CHECK(!file.empty());
  std::ifstream in(file, std::ios::binary);
  const std::string bytes((std::istreambuf_iterator<char>(in)),
                          std::istreambuf_iterator<char>());
  in.close();

  // One byte order mark at the start, then plain UTF-8 lines.
  CHECK(bytes.rfind("\xEF\xBB\xBF{", 0) == 0);
  CHECK(bytes.find("\xEF\xBB\xBF", 3) == std::string::npos);
  CHECK(bytes.find(polish) != std::string::npos);
  CHECK(bytes.find("second line") != std::string::npos);

  fs::remove_all(dir);
  std::cout << "logger_tests passed\n";
  return 0;
}
