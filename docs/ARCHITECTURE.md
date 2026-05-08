# Architecture and Engineering Roadmap

## Current State

The project is currently a PowerShell CLI with:

- Hardware detection through CIM/WMI.
- Menu-driven optimization functions.
- Registry backup and rollback.
- Restore point creation for bulk apply.
- Persistent logging.
- Synthetic optimization score.

Recent hardening added:

- A stable `OtimizadorFPS.ps1` launcher.
- UTF-8 with BOM compatibility for Windows PowerShell 5.1.
- A registry writer that preserves value kinds correctly.
- Persistent backup at `~/Documents/OtimizadorFPS_backup.json`.
- Correct VBS/HVCI menu reference.

## Main Technical Risks

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Registry tweaks without measurement | FPS claims become weak | Add PresentMon/ETW benchmark capture |
| Session-only rollback | User may close app before restoring | Persistent backup implemented; add tests |
| Too many global changes | Different hardware reacts differently | Use hardware-aware rules and profiles |
| Security downgrade | VBS/HVCI changes reduce protection | Keep optional, warn clearly, require consent |
| Hidden failures | PowerShell can continue after failed commands | Add strict error handling inside apply steps |
| No automated tests | Refactors become risky | Add Pester tests and CI |

## Recommended Repo Structure

Short-term PowerShell structure:

```text
realg-optimizer/
├── src/
│   ├── RealG.Cli/
│   │   └── Start-RealG.ps1
│   ├── RealG.Core/
│   │   ├── Hardware.psm1
│   │   ├── Registry.psm1
│   │   ├── Backup.psm1
│   │   ├── Profiles.psm1
│   │   └── Scoring.psm1
│   └── RealG.Optimizations/
│       ├── power.json
│       ├── input.json
│       ├── gpu.json
│       └── windows-gaming.json
├── tests/
│   ├── Registry.Tests.ps1
│   ├── Backup.Tests.ps1
│   └── Profiles.Tests.ps1
├── docs/
├── assets/
│   ├── brand/
│   └── screenshots/
├── .github/
│   ├── workflows/
│   └── ISSUE_TEMPLATE/
└── README.md
```

Future desktop product structure:

```text
realg-optimizer/
├── apps/
│   ├── desktop/          # WinUI 3, WPF or Tauri UI
│   └── landing/          # Marketing/demo site
├── packages/
│   ├── core/             # Rules, profiles, scoring
│   ├── agent/            # Privileged Windows operations
│   ├── telemetry/        # PresentMon/ETW/perf counters
│   └── shared-ui/        # Design system tokens/components
├── scripts/
├── docs/
└── tests/
```

## Optimization Manifest Pattern

Each optimization should become data plus code:

```json
{
  "id": "windows.game_dvr.disable",
  "title": "Disable Game DVR background capture",
  "category": "Windows Gaming",
  "risk": "safe",
  "requiresAdmin": true,
  "requiresReboot": false,
  "preconditions": ["windows10OrNewer"],
  "apply": [
    {
      "type": "registry",
      "path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR",
      "name": "AppCaptureEnabled",
      "value": 0,
      "kind": "DWord"
    }
  ],
  "rollback": "from-backup"
}
```

Benefits:

- Easier tests.
- Easier UI rendering.
- Safer review of each tweak.
- Versioned optimization catalog.
- Clear documentation from the same source of truth.

## Safe Apply Flow

1. Scan system state.
2. Build an action plan.
3. Show risk levels and reboot requirements.
4. Create restore point when needed.
5. Persist backup before writing.
6. Apply changes idempotently.
7. Verify post-state.
8. Write report and log.
9. Offer rollback.

The UI should never hide the exact change being applied. Advanced users should
be able to inspect keys, services and power settings.

## Metrics and Dashboard Data

Useful metrics:

- FPS average, 1% low, 0.1% low.
- Frametime average, p95, p99 and standard deviation.
- CPU utilization, highest process CPU, CPU frequency, thermal throttling.
- GPU utilization, VRAM usage, temperature, power draw if available.
- RAM usage, committed memory, available memory.
- Disk active time and game drive queue length.
- Network ping, jitter and packet loss where measurable.
- Process count and background CPU before/after.
- HAGS, Game Mode, VBS/HVCI, power plan, display refresh rate.

Data sources:

- Windows Performance Counters for system-level telemetry.
- ETW for deeper traces.
- PresentMon for frame presentation and frametime capture.
- Vendor APIs later for GPU details, if licensing allows.

## Technology Choices

### CLI and automation

- PowerShell 5.1+ for Windows reach.
- Pester for tests.
- PSScriptAnalyzer for lint.
- GitHub Actions on `windows-latest`.

### Desktop app options

| Option | Why choose it | Tradeoff |
| --- | --- | --- |
| .NET 8 + WinUI 3 | Native Windows feel, strong recruiter signal | More setup complexity |
| .NET 8 + WPF | Mature Windows desktop stack | Less modern visually |
| Tauri + React + Rust | Modern UI, small app shell, Rust agent | More moving pieces |
| Electron + React | Fastest UI iteration | Heavier desktop app |

Best portfolio route: .NET 8 + WinUI 3 for a native Windows product, or Tauri
if you want a modern frontend-heavy portfolio piece.

## Testing Plan

- Parser test for all `.ps1` and `.psm1` files.
- Unit tests for registry backup serialization/deserialization.
- Unit tests for scoring logic with mocked registry/service state.
- Dry-run snapshots for each profile.
- Windows Sandbox/manual QA checklist for risky changes.
- CI lint with PSScriptAnalyzer.

## Release Plan

- Tag semantic versions.
- Keep `CHANGELOG.md` updated.
- Generate ZIP release with scripts and docs.
- Add SHA256 checksums.
- Later: sign scripts and installer.
- Later: publish through winget/chocolatey.

## Next Engineering Milestones

1. Add `-DryRun` and `-WhatIf` support.
2. Extract registry/backup helpers into module.
3. Add Pester tests for backup and scoring.
4. Add tweak catalog with risk levels.
5. Add PresentMon benchmark command.
6. Build desktop prototype with audit dashboard.
