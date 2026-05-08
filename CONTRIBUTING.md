# Contributing

Thanks for helping improve RealG Optimizer.

## Development Setup

Requirements:

- Windows 10/11.
- PowerShell 5.1 or PowerShell 7+.
- Administrator rights for manual optimization testing.

Parser-only validation does not require admin:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  "$PWD\OtimizadorFPS_v2.ps1",
  [ref]$tokens,
  [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
  $errors | Format-List
  exit 1
}
```

## Contribution Rules

- Keep changes scoped.
- Document every new tweak.
- Add rollback behavior for every setting change.
- Add a risk level: Safe, Advanced or Security Tradeoff.
- Avoid tweaks that disable Defender, Windows Update or firewall.
- Prefer measured improvements over internet folklore.
- Update `CHANGELOG.md`.

## Commit Convention

Use conventional commits:

- `feat:` new capability
- `fix:` bug fix
- `docs:` documentation
- `test:` tests
- `refactor:` internal cleanup
- `perf:` performance improvement

## Pull Request Checklist

- Script parses successfully.
- README or docs updated if behavior changed.
- Rollback path exists for new Windows changes.
- Risky changes require confirmation.
- No personal machine paths or logs committed.
