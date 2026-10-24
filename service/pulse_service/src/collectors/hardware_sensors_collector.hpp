#pragma once

#include "pulse_wire.hpp"

namespace pulse {

/// Phase 3 hardware sensors (read-only, documented Win32 Storage IOCTLs).
///
/// Populates HealthSample::disk_health with every physical disk (see
/// disk_health.hpp; refreshed every few minutes) and the older single-disk
/// temperature / SMART fields from it. Leaves has_* false when a drive does
/// not report a value.
///
/// Does **not** sample GPU telemetry — that remains in SampleGpuD3dkmtTelemetry.
/// Does **not** invent CPU package temperature — no reliable public userspace
/// package-temp API without vendor/WMI heuristics.
void SampleHardwareSensors(ipc::HealthSample* out);

}  // namespace pulse
