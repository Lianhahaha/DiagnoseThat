#include "intelligence/bugcheck_catalog.hpp"

#include <cstdio>

namespace pulse {
namespace {

// The stop codes people most often run into. Names are copied from Microsoft's
// Bug Check Code Reference; the cause is the usual culprit, not a diagnosis.
constexpr BugcheckInfo kBugchecks[] = {
    {0x0000000A, "IRQL_NOT_LESS_OR_EQUAL", BugcheckCause::Driver},
    {0x00000019, "BAD_POOL_HEADER", BugcheckCause::Memory},
    {0x0000001A, "MEMORY_MANAGEMENT", BugcheckCause::Memory},
    {0x0000001E, "KMODE_EXCEPTION_NOT_HANDLED", BugcheckCause::Driver},
    {0x00000024, "NTFS_FILE_SYSTEM", BugcheckCause::Storage},
    {0x0000003B, "SYSTEM_SERVICE_EXCEPTION", BugcheckCause::Driver},
    {0x0000004E, "PFN_LIST_CORRUPT", BugcheckCause::Memory},
    {0x00000050, "PAGE_FAULT_IN_NONPAGED_AREA", BugcheckCause::Memory},
    {0x00000077, "KERNEL_STACK_INPAGE_ERROR", BugcheckCause::Storage},
    {0x0000007A, "KERNEL_DATA_INPAGE_ERROR", BugcheckCause::Storage},
    {0x0000007B, "INACCESSIBLE_BOOT_DEVICE", BugcheckCause::Storage},
    {0x0000007E, "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED", BugcheckCause::Driver},
    {0x0000007F, "UNEXPECTED_KERNEL_MODE_TRAP", BugcheckCause::Hardware},
    {0x00000080, "NMI_HARDWARE_FAILURE", BugcheckCause::Hardware},
    {0x0000008E, "KERNEL_MODE_EXCEPTION_NOT_HANDLED", BugcheckCause::Driver},
    {0x0000009C, "MACHINE_CHECK_EXCEPTION", BugcheckCause::Hardware},
    {0x0000009F, "DRIVER_POWER_STATE_FAILURE", BugcheckCause::Timeout},
    {0x000000A0, "INTERNAL_POWER_ERROR", BugcheckCause::Driver},
    {0x000000BE, "ATTEMPTED_WRITE_TO_READONLY_MEMORY", BugcheckCause::Driver},
    {0x000000C2, "BAD_POOL_CALLER", BugcheckCause::Driver},
    {0x000000C4, "DRIVER_VERIFIER_DETECTED_VIOLATION", BugcheckCause::Driver},
    {0x000000C5, "DRIVER_CORRUPTED_EXPOOL", BugcheckCause::Driver},
    {0x000000D1, "DRIVER_IRQL_NOT_LESS_OR_EQUAL", BugcheckCause::Driver},
    {0x000000D5, "DRIVER_PAGE_FAULT_IN_FREED_SPECIAL_POOL",
     BugcheckCause::Driver},
    {0x000000E2, "MANUALLY_INITIATED_CRASH", BugcheckCause::Manual},
    {0x000000EA, "THREAD_STUCK_IN_DEVICE_DRIVER", BugcheckCause::Timeout},
    {0x000000ED, "UNMOUNTABLE_BOOT_VOLUME", BugcheckCause::Storage},
    {0x000000EF, "CRITICAL_PROCESS_DIED", BugcheckCause::SystemProcess},
    {0x000000F4, "CRITICAL_OBJECT_TERMINATION", BugcheckCause::SystemProcess},
    {0x000000FC, "ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY",
     BugcheckCause::Driver},
    {0x000000FE, "BUGCODE_USB_DRIVER", BugcheckCause::Driver},
    {0x00000101, "CLOCK_WATCHDOG_TIMEOUT", BugcheckCause::Hardware},
    {0x00000109, "CRITICAL_STRUCTURE_CORRUPTION", BugcheckCause::Memory},
    {0x0000010E, "VIDEO_MEMORY_MANAGEMENT_INTERNAL", BugcheckCause::Graphics},
    {0x00000113, "VIDEO_DXGKRNL_FATAL_ERROR", BugcheckCause::Graphics},
    {0x00000116, "VIDEO_TDR_FAILURE", BugcheckCause::Graphics},
    {0x00000117, "VIDEO_TDR_TIMEOUT_DETECTED", BugcheckCause::Graphics},
    {0x00000119, "VIDEO_SCHEDULER_INTERNAL_ERROR", BugcheckCause::Graphics},
    {0x00000124, "WHEA_UNCORRECTABLE_ERROR", BugcheckCause::Hardware},
    {0x0000012B, "FAULTY_HARDWARE_CORRUPTED_PAGE", BugcheckCause::Memory},
    {0x00000133, "DPC_WATCHDOG_VIOLATION", BugcheckCause::Timeout},
    {0x00000139, "KERNEL_SECURITY_CHECK_FAILURE", BugcheckCause::Driver},
    {0x0000013A, "KERNEL_MODE_HEAP_CORRUPTION", BugcheckCause::Driver},
    {0x00000144, "BUGCODE_USB3_DRIVER", BugcheckCause::Driver},
    {0x00000154, "UNEXPECTED_STORE_EXCEPTION", BugcheckCause::Storage},
    {0x000001C8, "MANUALLY_INITIATED_POWER_BUTTON_HOLD",
     BugcheckCause::Manual},
    {0x1000007E, "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED_M",
     BugcheckCause::Driver},
    {0x1000008E, "KERNEL_MODE_EXCEPTION_NOT_HANDLED_M", BugcheckCause::Driver},
    {0xC000021A, "WINLOGON_FATAL_ERROR", BugcheckCause::SystemProcess},
    {0xDEADDEAD, "MANUALLY_INITIATED_CRASH1", BugcheckCause::Manual},
};

}  // namespace

const BugcheckInfo* FindBugcheck(std::uint32_t code) {
  for (const auto& info : kBugchecks) {
    if (info.code == code) {
      return &info;
    }
  }
  return nullptr;
}

std::string_view BugcheckCauseExplanation(BugcheckCause cause) {
  switch (cause) {
    case BugcheckCause::Driver:
      return "This is usually caused by a faulty or outdated driver.";
    case BugcheckCause::Graphics:
      return "The graphics driver or graphics card stopped responding.";
    case BugcheckCause::Memory:
      return "Memory contents were corrupted, usually by a driver bug and "
             "sometimes by faulty RAM.";
    case BugcheckCause::Hardware:
      return "The processor or another hardware component reported an error "
             "it could not recover from.";
    case BugcheckCause::Storage:
      return "Windows could not read data it needed from the disk.";
    case BugcheckCause::Timeout:
      return "A driver or device took too long to respond, so Windows stopped "
             "to protect itself.";
    case BugcheckCause::SystemProcess:
      return "A core Windows process stopped unexpectedly.";
    case BugcheckCause::Manual:
      return "The crash was triggered on purpose, for example by holding the "
             "power button or a debugging shortcut.";
  }
  return "";
}

std::string_view BugcheckCauseRecommendation(BugcheckCause cause) {
  switch (cause) {
    case BugcheckCause::Driver:
      return "Update or roll back recently installed drivers, especially "
             "graphics, network, audio and storage drivers.";
    case BugcheckCause::Graphics:
      return "Update or clean-install the graphics driver, check GPU "
             "temperatures and remove any GPU overclock.";
    case BugcheckCause::Memory:
      return "Run Windows Memory Diagnostic and update drivers. If you changed "
             "RAM or memory overclock (XMP/EXPO) settings, try the defaults.";
    case BugcheckCause::Hardware:
      return "Remove any overclock, check temperatures and the power supply, "
             "and update the BIOS.";
    case BugcheckCause::Storage:
      return "Check the drive's health with the manufacturer's tool or chkdsk, "
             "and check its cables and free space.";
    case BugcheckCause::Timeout:
      return "Update chipset, storage and graphics drivers and the BIOS, and "
             "check any recently added devices.";
    case BugcheckCause::SystemProcess:
      return "Check the disk for errors and run sfc /scannow. Recent driver or "
             "security software changes are also common causes.";
    case BugcheckCause::Manual:
      return "";
  }
  return "";
}

std::string FormatBugcheckCode(std::uint32_t code) {
  char buffer[16];
  std::snprintf(buffer, sizeof(buffer), "0x%08X", code);
  return buffer;
}

}  // namespace pulse
