# Security Policy

RealG Optimizer changes Windows settings and registry values. Security and
rollback behavior are part of the product, not an afterthought.

## Supported Versions

| Version | Supported |
| --- | --- |
| 2.x | Yes |
| 1.x | No |

## Safety Principles

- Do not disable Windows Defender.
- Do not disable Windows Update.
- Do not silently disable VBS/HVCI.
- Back up registry values before writing.
- Keep rollback data persistent.
- Prefer reversible system changes.
- Warn clearly when a change reduces security or requires reboot.

## Reporting a Vulnerability

Open a private security advisory on GitHub if available, or create an issue with
the `security` label and avoid posting sensitive personal system information.

Please include:

- Windows version and build.
- Script version.
- Action/profile used.
- Expected behavior.
- Actual behavior.
- Relevant log lines from `~/Documents/OtimizadorFPS_log.txt`.

Do not include license keys, account names, private paths or machine IDs.
