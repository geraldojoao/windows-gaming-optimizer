# Design, Brand and Portfolio Guide

## Name Ideas

Professional options:

- RealG Optimizer
- LatencyOS
- FrameForge
- GamePulse
- ApexTune
- CoreBoost Gaming
- ZeroLag Studio
- WinGameLab
- Frametune
- ClutchMode

Best fit for this repo: **RealG Optimizer**. It is short, memorable and less
generic than "OtimizadorFPS".

## Short GitHub Bio

> Building RealG Optimizer, a Windows gaming performance tool focused on
> latency, frametime stability, safe rollback and transparent system tuning.

## Professional Project Description

RealG Optimizer is a Windows performance tuning tool for competitive gamers. It
detects the user's hardware, audits gaming-related Windows settings and applies
transparent, reversible optimizations for latency, background workload, power
configuration, GPU scheduling and frametime stability.

## Visual Identity

Recommended direction:

- Tone: technical, premium, competitive, trustworthy.
- Palette: near-black background, graphite surfaces, electric cyan accents,
  lime status highlights, amber warnings and red critical states.
- Typography: Inter, Segoe UI Variable or Geist.
- Shape language: compact panels, sharp 6-8px radius, clear status chips.
- Avoid: purple-only gradients, fake hacker visuals, giant marketing hero cards,
  excessive neon glow and cluttered gamer stereotypes.

Logo concepts:

1. Stylized `RG` monogram inside a speedometer arc.
2. Frame graph line forming the letter `G`.
3. Minimal target/crosshair plus latency pulse.
4. Shield plus lightning mark to communicate safe performance.

## Desktop UI Concept

First screen should be the product, not a landing page.

Main navigation:

- Dashboard
- Optimize
- Profiles
- Benchmark
- History
- Safety
- Settings

Dashboard panels:

- System readiness score.
- Current profile.
- FPS/frametime card from latest benchmark.
- Background workload summary.
- Risk alerts: VBS/HVCI, Game DVR, power plan, HAGS.
- Reboot-required banner.
- Rollback status.

Optimize view:

- Table of recommendations.
- Columns: Category, Impact, Risk, Requires reboot, Current state, Action.
- Expand row to show exact registry/service/power setting.
- Primary action: Apply selected.
- Secondary action: Dry run.

Benchmark view:

- Capture length selector.
- Game/process selector.
- Frametime line chart.
- FPS average, 1% low, 0.1% low.
- Before/after comparison.
- Export report button.

## Futuristic Gamer Dashboard Ideas

Useful and impressive:

- Frametime waterfall chart.
- Latency budget bar: input, CPU queue, GPU render, display.
- Bottleneck indicator: CPU-bound, GPU-bound, memory pressure, thermal.
- Game session timeline.
- Profile switcher with keyboard/controller-friendly mode.
- Live process impact list during game mode.
- "Confidence score" for each recommendation.

Keep it readable. Futuristic should mean precise, fast and polished, not noisy.

## Animations and Effects

Good effects:

- Smooth number counters for score changes.
- Subtle chart draw-in after benchmark.
- Status pulse only for active capture.
- Micro-interactions on toggles and apply buttons.
- Command log streaming during optimization.
- Skeleton loaders for hardware scan.

Avoid:

- Permanent glowing background blobs.
- Random particle fields.
- Long intro animations.
- Motion that hides system risk details.

## Landing Page Structure

Hero:

- Headline: `RealG Optimizer`
- Subcopy: `Transparent Windows tuning for competitive gaming performance.`
- Primary CTA: `Download`
- Secondary CTA: `View GitHub`
- Visual: real product screenshot or short dashboard video, not abstract art.

Sections:

- Problem: hidden background load, inconsistent frametimes, scattered settings.
- Solution: audit, recommend, apply, measure, rollback.
- Safety: restore point, persistent backup, risk labels.
- Metrics: FPS, 1% lows, frametime p95/p99, background process delta.
- Tech: PowerShell, Windows registry, ETW, PresentMon roadmap.
- Roadmap: CLI, desktop, benchmark, AI recommendations.

## Screenshot Plan

Create polished screenshots for:

- Main terminal menu.
- Hardware detection view.
- Benchmark score view.
- Profile selection.
- Rollback/log screen.
- Future UI mockup dashboard.

Rules:

- Use a clean Windows Terminal theme.
- Crop consistently.
- Hide personal paths/usernames if needed.
- Use a high-resolution display.
- Add short captions in the README, not text baked into the image.

## Demo Video Script

Length: 60-90 seconds.

1. Show the problem: Windows gaming settings are scattered and risky.
2. Launch RealG as admin.
3. Show hardware detection.
4. Run benchmark score.
5. Apply Balanced profile.
6. Show exact changes/log.
7. Show rollback availability.
8. End with roadmap: desktop dashboard and real frametime capture.

Voiceover angle:

> I built RealG Optimizer to practice Windows automation and performance tooling,
> but designed it like a real product: hardware-aware, reversible and measurable.

## LinkedIn Post

```text
I have been building RealG Optimizer, a Windows gaming performance tool focused
on lower input latency, frametime stability and safe system tuning.

What started as a PowerShell script became a portfolio product with hardware
detection, optimization profiles, persistent rollback, logs, restore point flow
and a roadmap toward a desktop dashboard with real benchmark capture.

The most interesting part was treating performance tweaks as product decisions:
every change needs a reason, a risk level, a rollback path and eventually a
measured before/after result.

Tech: PowerShell, Windows registry, CIM/WMI, powercfg, GitHub Actions roadmap,
PresentMon/ETW research.

Repo: <link>
```

## GitHub Presentation Checklist

- Clear README with screenshot/video near the top.
- Badges for Windows, PowerShell, CI and license.
- Installation and usage in under 30 seconds.
- Safety warning without sounding scary.
- Roadmap and architecture docs.
- Release notes.
- Issues enabled with templates.
- At least one demo GIF or MP4.
- LinkedIn post linking to the repo.

## README One-Liner

> Windows gaming optimizer for latency, frametime stability and transparent,
> reversible system tuning.
