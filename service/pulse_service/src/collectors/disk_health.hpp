#pragma once

#include "pulse_wire.hpp"

#include <vector>

#define WIN32_LEAN_AND_MEAN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <winioctl.h>
#include <nvme.h>

namespace pulse {

/// Per-disk health from documented Storage IOCTLs, read-only.
///
/// Each \\.\PhysicalDriveN is opened with no access rights (desired access
/// 0). IOCTL_STORAGE_QUERY_PROPERTY and IOCTL_STORAGE_PREDICT_FAILURE work
/// on such a handle, while GENERIC_READ needs administrator rights and fails
/// for the LocalService account.
///
///  - StorageDeviceProperty: model and bus type
///  - StorageDeviceTemperatureProperty: temperature (NVMe and many SATA)
///  - StorageDeviceProtocolSpecificProperty, NVMe health log (log page 2):
///    critical warnings, wear, spare capacity, power-on hours, unsafe
///    shutdowns, media errors, data read and written
///  - IOCTL_STORAGE_PREDICT_FAILURE: SMART failure prediction (SATA / ATA)
///
/// Fields the drive or driver does not report keep has_* = false; nothing is
/// estimated.
[[nodiscard]] std::vector<ipc::HealthDiskHealth> ReadDiskHealth();

/// Copies an NVMe SMART / Health Information log into `out` (exposed for
/// tests).
void ApplyNvmeHealthLog(const NVME_HEALTH_INFO_LOG& log,
                        ipc::HealthDiskHealth* out);

/// Short bus name for STORAGE_BUS_TYPE, e.g. "NVMe", "SATA", "USB".
[[nodiscard]] const char* StorageBusName(STORAGE_BUS_TYPE bus);

}  // namespace pulse
