#Requires -Version 5.1
<#
.SYNOPSIS
    Stable launcher for RealG Optimizer.
.DESCRIPTION
    Keeps the public entry point stable while the implementation can evolve in
    versioned files.
#>

$ErrorActionPreference = 'Stop'

$implementation = Join-Path -Path $PSScriptRoot -ChildPath 'OtimizadorFPS_v2.ps1'

if (-not (Test-Path -LiteralPath $implementation)) {
    Write-Error "Implementation file not found: $implementation"
    exit 1
}

& $implementation @args
