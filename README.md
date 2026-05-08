# RealG Optimizer

Windows gaming optimizer focused on competitive performance, lower input latency,
frametime stability and safe, reversible system tuning.

<p align="center">
  <img src="https://img.shields.io/badge/Windows-10%2F11-0078D6?style=flat-square&logo=windows&logoColor=white" />
  <img src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Portfolio%20MVP-blueviolet?style=flat-square" />
  <img src="https://img.shields.io/badge/Admin-Required-red?style=flat-square" />
  <img src="https://img.shields.io/badge/Rollback-Persistent-green?style=flat-square" />
</p>

## Overview

RealG Optimizer is a PowerShell-based Windows optimization tool for gamers who
want a transparent alternative to one-click "boosters". It detects hardware,
shows the current system state, applies focused Windows tweaks and keeps a
persistent rollback file so the user can reverse registry changes even after
closing the app.

The project is intentionally positioned as a technical portfolio product:
Windows internals, system automation, safety-first UX, performance diagnostics,
documentation and a clear roadmap toward a full desktop application.

## What It Optimizes

| Area | Current scope |
| --- | --- |
| CPU and power | Ultimate Performance plan, PCIe ASPM off, processor idle tuning |
| GPU | HAGS, TDR stability tuning, NVIDIA/AMD/Intel detection |
| Input | USB selective suspend off, mouse acceleration removal |
| Network | Network throttling, MMCSS games profile, Nagle-related TCP keys |
| Memory | LargeSystemCache, DisablePagingExecutive, heap threshold |
| Disk | NTFS 8.3 names, last access update, TRIM check, desktop hibernation |
| Windows gaming | Game DVR/Game Bar capture off, visual effects, optional VBS/HVCI toggle |
| Safety | Restore point on "apply all", persistent registry backup, logs |

## Quick Start

Run PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File ".\OtimizadorFPS.ps1"
```

Or right-click `OtimizadorFPS.ps1` and choose **Run with PowerShell**.

Main files:

- `OtimizadorFPS.ps1`: stable launcher.
- `OtimizadorFPS_v2.ps1`: current implementation.
- `CHANGELOG.md`: release notes.
- `docs/`: product, architecture and design strategy.

## Current Features

- Automatic CPU, GPU, RAM, disk, Windows version, laptop and power plan detection.
- Interactive terminal menu with individual optimizations, profiles and benchmark score.
- Profiles for Gaming, Balanced, Competitive and Laptop use cases.
- Persistent log at `~/Documents/OtimizadorFPS_log.txt`.
- Persistent rollback backup at `~/Documents/OtimizadorFPS_backup.json`.
- Windows Restore Point creation before applying all optimizations.
- Optional VBS/HVCI disable flow with explicit user confirmation.
- UTF-8 with BOM compatibility for Windows PowerShell 5.1.
- GitHub-ready documentation, security policy, contribution guide and CI template.

## Safety Model

This project modifies Windows settings and must be treated as a system tool, not
as a cosmetic utility. The safe path is:

1. Detect hardware and OS state before recommending tweaks.
2. Explain risk level before applying sensitive changes.
3. Back up registry values before writing.
4. Persist rollback data outside memory.
5. Create a restore point for bulk changes.
6. Avoid disabling Windows Defender or Windows Update.
7. Show when a reboot is required.

VBS/HVCI may improve security on Windows 11 systems. Disabling it should stay
optional and only be recommended for dedicated gaming PCs.

## Why This Is Portfolio-Worthy

RealG demonstrates skills that recruiters can evaluate quickly:

- PowerShell automation with admin elevation and Windows registry work.
- Windows performance concepts: power plans, MMCSS, HAGS, ETW-ready metrics.
- Product thinking: personas, risk levels, onboarding and rollback UX.
- Software quality: parser validation, planned linting, changelog and docs.
- Security awareness: backups, restore points, warnings and non-destructive defaults.
- Roadmap thinking: CLI today, desktop app and measured benchmarking next.

## Documentation

- [Product strategy](docs/PRODUCT_STRATEGY.md)
- [Architecture and engineering roadmap](docs/ARCHITECTURE.md)
- [Design, brand and portfolio guide](docs/DESIGN_BRAND.md)
- [Guia de portfolio PT-BR](docs/GUIA_PORTFOLIO_PTBR.md)
- [Security policy](SECURITY.md)
- [Contributing guide](CONTRIBUTING.md)

## Roadmap Snapshot

| Phase | Goal |
| --- | --- |
| 1 | Harden CLI, add Pester tests, validate every tweak with dry-run mode |
| 2 | Split script into PowerShell modules and optimization manifests |
| 3 | Add real benchmarking with PresentMon/ETW CSV capture |
| 4 | Build desktop UI with profiles, charts and safe apply/rollback flows |
| 5 | Add game-specific recommendations and optional AI tuning assistant |
| 6 | Package signed releases with winget/chocolatey and installer |

## Professional Description

RealG Optimizer is a Windows performance tuning tool for competitive gamers. It
detects the user's hardware, audits gaming-related Windows settings and applies
transparent, reversible optimizations for latency, background workload, power
configuration, GPU scheduling and frametime stability.

## References

This project roadmap is informed by official and primary references:

- Microsoft: Windows 11 windowed game optimizations
  <https://support.microsoft.com/en-us/windows/optimizations-for-windowed-games-in-windows-11-3f006843-2c7e-4ed0-9a5e-f9389e535952>
- Microsoft: Windows app performance fundamentals
  <https://learn.microsoft.com/en-us/windows/apps/performance/>
- Microsoft: ETW performance tracing
  <https://learn.microsoft.com/en-us/windows-hardware/test/weg/instrumenting-your-code-with-etw>
- Intel/GameTechDev: PresentMon
  <https://github.com/GameTechDev/PresentMon>
- Razer Cortex product positioning
  <https://www.razer.com/cortex>
- AMD HYPR-RX product positioning
  <https://www.amd.com/en/products/software/adrenalin/hypr-rx.html>

## License

MIT. See [LICENSE](LICENSE).
