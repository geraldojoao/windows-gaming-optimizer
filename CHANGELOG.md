# Changelog

All notable changes to OtimizadorFPS are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [2.1.0] — 2026-05-08

### Added
- Stable launcher: `OtimizadorFPS.ps1`.
- Persistent rollback backup in `~/Documents/OtimizadorFPS_backup.json`.
- GitHub-ready project docs: product strategy, architecture, design/brand guide and PT-BR portfolio guide.
- Security policy, contribution guide, MIT license, issue templates and CI workflow.

### Fixed
- Registry writes now use a safe `RegistryKey.SetValue()` helper instead of the invalid `Set-ItemProperty -Type` pattern.
- Script saved as UTF-8 with BOM for Windows PowerShell 5.1 compatibility.
- Windows 11 VBS/HVCI warning now points to menu option 11.

### Changed
- README rewritten with professional positioning, safety model, roadmap and references.
- Rollback state now loads on startup and is cleared after a successful restore.

## [2.0.0] — 2024

### Added
- **Timer Resolution** (opt 8): `GlobalTimerResolutionRequests` + CPU C-States reduction
- **Disk Optimizations** (opt 9): NTFS 8.3 names, Last Access, TRIM, hibernate (desktop only)
- **GPU Vendor-Specific** (opt 10): NVIDIA TDR tuning, AMD deep sleep, Intel fallback
- **VBS/HVCI disable** (opt 11): Windows 11 only, with user confirmation prompt
- **Memory tweaks** (opt 12): LargeSystemCache, DisablePagingExecutive, Heap threshold
- **Profile system** [P]: Gaming, Balanced, Competitive, Laptop presets
- **Benchmark score** [B]: 0–100 pt score with grade (S/A/B/C/D) and delta tracking
- **Persistent log**: all actions written to `~/Documents/OtimizadorFPS_log.txt`
- **Hardware cache**: `$Script:HW` avoids repeated WMI calls; `[I]` refreshes it
- **GPU vendor detection**: NVIDIA / AMD / Intel via GPU name pattern matching
- **Windows 11 detection**: `OSBuild >= 22000` with VBS status alert on main screen
- **SSD detection**: via `Get-PhysicalDisk` MediaType
- **Laptop detection**: via `Win32_Battery`
- **CimInstance migration**: replaced deprecated `Get-WmiObject` with `Get-CimInstance` (PS7 compatible), with WMI fallback
- **HAGS** added to opt 4 (`HwSchMode = 2`)
- Session start/end logged with score delta
- Menu padded option numbers `[1]`–`[12]` for alignment

### Fixed
- Menu footer incorrectly referenced "opção 8" for restore — now correctly shows `[R]`
- `Invoke-RestoreDefaults` now also re-enables hypervisor boot entry when VBS was disabled
- Window width increased to 95 chars to accommodate new 2-digit menu items

### Changed
- Banner updated to show v2.0 and new feature list
- `Show-SystemInfo` now shows disk type, laptop tag, and VBS warning for Win11

---

## [1.0.0] — Initial Release

### Added
- Admin guard with auto-elevation
- Session-scoped backup/restore system (LIFO, registry-level)
- Hardware info: CPU, GPU, RAM, Power Plan, OS, Process count
- Opt 1: Ultimate Performance power plan + PCIe ASPM off
- Opt 2: Disable SysMain (SuperFetch)
- Opt 3: Disable Game DVR / Xbox Game Bar
- Opt 4: NetworkThrottlingIndex + SystemResponsiveness + Win32PrioritySeparation + Games profile
- Opt 5: USB Selective Suspend off (AC + DC)
- Opt 6: Visual effects + MenuShowDelay + WaitToKillAppTimeout + AnimationOff
- Opt 7: Nagle off (per-NIC + global) + Mouse Acceleration removal + DiagTrack + Prefetcher
- Apply All with Windows Restore Point creation
- Restore Defaults (LIFO revert + service restart + Balanced power plan)
- Color UI helpers (Write-Color, Write-Header, Write-Section, Write-OK/WARN/ERR/INFO/SKIP)
- Terminal window auto-resize (90×45)
