#Requires -Version 5.1

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath 'OtimizadorFPS_v2.ps1'

if (-not (Test-Path $mainScript)) {
    Write-Error "Arquivo principal nao encontrado: $mainScript"
    exit 1
}

& $mainScript @args
