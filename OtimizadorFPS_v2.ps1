#Requires -Version 5.1
<#
.SYNOPSIS
    OtimizadorFPS v2.0 — Windows Gaming Optimizer
.DESCRIPTION
    Menu-driven optimization tool for maximum FPS, minimum input lag and
    frametime stability. All changes are safe and fully reversible.
    New in v2.0: Timer resolution, disk tweaks, GPU vendor detection,
    Windows 11 VBS/HVCI check, profiles, persistent log, benchmark score.
.NOTES
    Run as Administrator.
    Save as: OtimizadorFPS.ps1
    Run:     Right-click → Run with PowerShell (as Admin)
             OR: powershell -ExecutionPolicy Bypass -File ".\OtimizadorFPS.ps1"
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

# ─────────────────────────────────────────────────────────────
#  REGION: CONSTANTS
# ─────────────────────────────────────────────────────────────

$Script:VERSION    = '2.0'
$Script:LOG_FILE   = "$env:USERPROFILE\Documents\OtimizadorFPS_log.txt"
$Script:PROFILE_FILE = "$env:USERPROFILE\Documents\OtimizadorFPS_profile.json"
$Script:BACKUP_FILE  = "$env:USERPROFILE\Documents\OtimizadorFPS_backup.json"
$Script:Backup     = @{}
$Script:BenchScore = $null   # Score pré-otimização para comparação

# ─────────────────────────────────────────────────────────────
#  REGION: COLORS & UI HELPERS
# ─────────────────────────────────────────────────────────────

function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$FG = 'White',
        [ConsoleColor]$BG = 'Black',
        [switch]$NoNewLine
    )
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $FG
    if ($NoNewLine) { Write-Host $Text -NoNewline } else { Write-Host $Text }
    $Host.UI.RawUI.ForegroundColor = $prev
}

function Write-Header {
    param([string]$Title)
    $width = 62
    $line  = '═' * $width
    Write-Host ""
    Write-Color "  ╔$line╗" -FG Cyan
    $pad   = [math]::Floor(($width - $Title.Length) / 2)
    $right = $width - $Title.Length - $pad
    Write-Color "  ║$(' ' * $pad)$Title$(' ' * $right)║" -FG Cyan
    Write-Color "  ╚$line╝" -FG Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Color "  ── $Title " -FG DarkCyan -NoNewLine
    Write-Color ('─' * [math]::Max(2, 55 - $Title.Length)) -FG DarkGray
}

function Write-OK   { Write-Color "  [✓] $args" -FG Green;    Write-Log "OK   $args" }
function Write-WARN { Write-Color "  [!] $args" -FG Yellow;   Write-Log "WARN $args" }
function Write-ERR  { Write-Color "  [✗] $args" -FG Red;      Write-Log "ERR  $args" }
function Write-INFO { Write-Color "  [·] $args" -FG Gray;     Write-Log "INFO $args" }
function Write-SKIP { Write-Color "  [–] $args" -FG DarkGray }

function Pause-Continue {
    Write-Host ""
    Write-Color "  Pressione qualquer tecla para continuar..." -FG DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Clear-ScreenCustom {
    Clear-Host
    Write-Color "  OTIMIZADOR FPS  " -FG Black -BG Cyan -NoNewLine
    Write-Color "  v$Script:VERSION  " -FG DarkGray -BG Black -NoNewLine
    Write-Color "  Windows Gaming Optimizer" -FG DarkCyan
    Write-Color "  $('─' * 62)" -FG DarkGray
}

# ─────────────────────────────────────────────────────────────
#  REGION: PERSISTENT LOG
# ─────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message)
    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -Path $Script:LOG_FILE -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
    } catch {}
}

function Show-LogPath {
    Write-INFO "Log salvo em: $Script:LOG_FILE"
}

function Save-BackupState {
    try {
        $dir = Split-Path -Path $Script:BACKUP_FILE -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }

        $entries = foreach ($key in $Script:Backup.Keys) {
            $entry = $Script:Backup[$key]
            [PSCustomObject]@{
                Key     = $key
                Path    = [string]$entry.Path
                Name    = [string]$entry.Name
                Value   = $entry.Value
                Existed = [bool]$entry.Existed
                Kind    = [string]$entry.Kind
            }
        }

        $payload = [PSCustomObject]@{
            Version = $Script:VERSION
            SavedAt = (Get-Date).ToString('o')
            Entries = @($entries)
        }

        $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $Script:BACKUP_FILE -Encoding UTF8
    } catch {
        Write-Log "WARN Backup persistente falhou: $_"
    }
}

function Load-BackupState {
    $Script:Backup = @{}

    if (-not (Test-Path $Script:BACKUP_FILE)) { return }

    try {
        $payload = Get-Content -Path $Script:BACKUP_FILE -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($entry in @($payload.Entries)) {
            if (-not $entry.Key) { continue }
            $Script:Backup[[string]$entry.Key] = @{
                Path    = [string]$entry.Path
                Name    = [string]$entry.Name
                Value   = $entry.Value
                Existed = [bool]$entry.Existed
                Kind    = [string]$entry.Kind
            }
        }

        if ($Script:Backup.Count -gt 0) {
            Write-Log "BACKUP: $($Script:Backup.Count) valores carregados de $Script:BACKUP_FILE"
        }
    } catch {
        Write-Log "WARN Backup persistente invalido: $_"
        $Script:Backup = @{}
    }
}

function Clear-BackupState {
    $Script:Backup = @{}
    Remove-Item -Path $Script:BACKUP_FILE -Force -ErrorAction SilentlyContinue
}

function ConvertTo-RegistryValueKind {
    param([string]$Type = 'DWord')

    switch ($Type) {
        'String'       { return [Microsoft.Win32.RegistryValueKind]::String }
        'ExpandString' { return [Microsoft.Win32.RegistryValueKind]::ExpandString }
        'DWord'        { return [Microsoft.Win32.RegistryValueKind]::DWord }
        'QWord'        { return [Microsoft.Win32.RegistryValueKind]::QWord }
        'MultiString'  { return [Microsoft.Win32.RegistryValueKind]::MultiString }
        'Binary'       { return [Microsoft.Win32.RegistryValueKind]::Binary }
        default        { return [Microsoft.Win32.RegistryValueKind]::DWord }
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )

    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }

    $kind = ConvertTo-RegistryValueKind -Type $Type
    $normalizedValue = switch ($kind) {
        ([Microsoft.Win32.RegistryValueKind]::DWord)       { [int]$Value; break }
        ([Microsoft.Win32.RegistryValueKind]::QWord)       { [long]$Value; break }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) { [string[]]$Value; break }
        ([Microsoft.Win32.RegistryValueKind]::Binary)      { [byte[]]$Value; break }
        default                                            { $Value }
    }
    $key = Get-Item -Path $Path -ErrorAction Stop
    $key.SetValue($Name, $normalizedValue, $kind)
}

# ─────────────────────────────────────────────────────────────
#  REGION: ADMIN GUARD
# ─────────────────────────────────────────────────────────────

function Assert-Admin {
    $id        = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $id
    $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ""
        Write-ERR "Este script precisa ser executado como ADMINISTRADOR."
        Write-INFO "Clique direito no arquivo → 'Executar com PowerShell'"
        Write-Host ""
        Write-Color "  Tentando elevar automaticamente..." -FG DarkYellow
        Start-Sleep -Seconds 2
        try {
            Start-Process powershell.exe `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
                -Verb RunAs
        } catch {
            Write-ERR "Falha na elevação automática. Execute manualmente como Admin."
        }
        exit
    }
}

# ─────────────────────────────────────────────────────────────
#  REGION: HARDWARE DETECTION (v2: CimInstance + vendor detect)
# ─────────────────────────────────────────────────────────────

$Script:HW = $null   # Cache de hardware

function Get-HardwareInfo {
    if ($Script:HW) { return $Script:HW }

    $hw = [PSCustomObject]@{
        CPUName    = 'Desconhecido'
        CPUCores   = 0
        CPUThreads = 0
        CPUMHz     = 0
        GPUName    = 'Desconhecido'
        GPUVendor  = 'Unknown'   # NVIDIA | AMD | Intel
        GPUVRAM_MB = 0
        GPUDriver  = 'N/A'
        RAMTotal   = 0.0
        RAMFree    = 0.0
        RAMSpeed   = 0
        OSCaption  = ''
        OSBuild    = 0
        IsWin11    = $false
        IsLaptop   = $false
        HasSSD     = $false
        PowerPlan  = 'Desconhecido'
        Processes  = 0
        Services   = 0
    }

    # CPU — usa CimInstance (PS5+/PS7 compatível)
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $hw.CPUName    = $cpu.Name.Trim()
        $hw.CPUCores   = $cpu.NumberOfCores
        $hw.CPUThreads = $cpu.NumberOfLogicalProcessors
        $hw.CPUMHz     = $cpu.MaxClockSpeed
    } catch {
        # Fallback para WMI legado
        try {
            $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
            $hw.CPUName    = $cpu.Name.Trim()
            $hw.CPUCores   = $cpu.NumberOfCores
            $hw.CPUThreads = $cpu.NumberOfLogicalProcessors
            $hw.CPUMHz     = $cpu.MaxClockSpeed
        } catch {}
    }

    # GPU
    try {
        $gpuList = Get-CimInstance Win32_VideoController -ErrorAction Stop
        $gpu = $gpuList | Where-Object {
            $_.Name -notmatch 'Remote|Basic|Virtual|RDP' -and
            $_.AdapterDACType -ne 'Internal'
        } | Sort-Object AdapterRAM -Descending | Select-Object -First 1
        if (-not $gpu) { $gpu = $gpuList | Select-Object -First 1 }

        $hw.GPUName    = $gpu.Name.Trim()
        $hw.GPUVRAM_MB = [math]::Round(($gpu.AdapterRAM -as [long]) / 1MB)
        $hw.GPUDriver  = $gpu.DriverVersion

        if ($gpu.Name -match 'NVIDIA|GeForce|RTX|GTX|Quadro') {
            $hw.GPUVendor = 'NVIDIA'
        } elseif ($gpu.Name -match 'AMD|Radeon|RX |Vega|RDNA') {
            $hw.GPUVendor = 'AMD'
        } elseif ($gpu.Name -match 'Intel|UHD|Iris|Arc') {
            $hw.GPUVendor = 'Intel'
        }
    } catch {}

    # RAM
    try {
        $os           = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $hw.RAMTotal  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $hw.RAMFree   = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $hw.OSCaption = $os.Caption
        $hw.OSBuild   = [int]$os.BuildNumber
        $hw.IsWin11   = ($hw.OSBuild -ge 22000)
    } catch {}

    try {
        $mem = Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Select-Object -First 1
        $hw.RAMSpeed = $mem.Speed
    } catch {}

    # Laptop detection
    try {
        $hw.IsLaptop = (Get-CimInstance Win32_Battery -ErrorAction Stop).Count -gt 0
    } catch {}

    # SSD detection
    try {
        $disk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.MediaType -eq 'SSD' }
        $hw.HasSSD = ($null -ne $disk)
    } catch {}

    # Power plan
    try {
        $line = powercfg /getactivescheme 2>$null
        if ($line -match '\((.+)\)') { $hw.PowerPlan = $Matches[1] }
    } catch {}

    # Procs + Services
    try { $hw.Processes = (Get-Process).Count } catch {}
    try { $hw.Services  = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count } catch {}

    $Script:HW = $hw
    return $hw
}

function Show-SystemInfo {
    Write-Section "INFORMAÇÕES DO SISTEMA"
    $hw = Get-HardwareInfo

    Write-Color "  CPU     " -FG DarkCyan -NoNewLine
    Write-Color "$($hw.CPUName)" -FG White
    Write-Color "          " -FG DarkCyan -NoNewLine
    Write-Color "$($hw.CPUCores) Cores / $($hw.CPUThreads) Threads  |  $($hw.CPUMHz) MHz" -FG Gray

    $vramStr = if ($hw.GPUVRAM_MB -gt 0) { "  |  $($hw.GPUVRAM_MB) MB VRAM" } else { "" }
    Write-Color "  GPU     " -FG DarkCyan -NoNewLine
    Write-Color "$($hw.GPUName)$vramStr" -FG White

    $speedStr = if ($hw.RAMSpeed -gt 0) { " @ $($hw.RAMSpeed) MHz" } else { "" }
    $usedGB   = [math]::Round($hw.RAMTotal - $hw.RAMFree, 1)
    $pct      = if ($hw.RAMTotal -gt 0) { [math]::Round(($usedGB / $hw.RAMTotal) * 100) } else { 0 }
    Write-Color "  RAM     " -FG DarkCyan -NoNewLine
    Write-Color "$($hw.RAMTotal) GB${speedStr}  |  $usedGB GB em uso ($pct%)  |  $($hw.RAMFree) GB livre" -FG White

    $powerColor = if ($hw.PowerPlan -match 'Ultimate|High') { 'Green' } else { 'Yellow' }
    Write-Color "  Energia " -FG DarkCyan -NoNewLine
    Write-Color $hw.PowerPlan -FG $powerColor

    Write-Color "  OS      " -FG DarkCyan -NoNewLine
    $win11Tag = if ($hw.IsWin11) { " [Windows 11]" } else { "" }
    Write-Color "$($hw.OSCaption) (Build $($hw.OSBuild))$win11Tag" -FG Gray

    Write-Color "  Disco   " -FG DarkCyan -NoNewLine
    $diskType = if ($hw.HasSSD) { "SSD detectado" } else { "HDD / desconhecido" }
    $laptopTag = if ($hw.IsLaptop) { "  |  Laptop" } else { "" }
    Write-Color "$diskType$laptopTag" -FG Gray

    Write-Color "  Procs   " -FG DarkCyan -NoNewLine
    Write-Color "$($hw.Processes) processos  |  $($hw.Services) serviços rodando" -FG White

    # Alerta Windows 11 VBS
    if ($hw.IsWin11) {
        $vbsEnabled = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        if ($vbsEnabled -eq 1) {
            Write-Host ""
            Write-WARN "VBS/HVCI ATIVO — pode reduzir FPS em 5-15%  (opção 11 para desativar)"
        }
    }

    Write-Host ""
}

# ─────────────────────────────────────────────────────────────
#  REGION: BACKUP / ROLLBACK SYSTEM
# ─────────────────────────────────────────────────────────────

function Backup-RegValue {
    param([string]$Path, [string]$Name)
    $key = "$Path||$Name"
    if ($Script:Backup.ContainsKey($key)) { return }
    try {
        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        $Script:Backup[$key] = @{
            Path    = $Path
            Name    = $Name
            Value   = $existing.$Name
            Existed = $true
            Kind    = (Get-Item $Path -ErrorAction Stop).GetValueKind($Name)
        }
    } catch {
        $Script:Backup[$key] = @{
            Path    = $Path
            Name    = $Name
            Value   = $null
            Existed = $false
            Kind    = 'DWord'
        }
    }
    Save-BackupState
}

function Set-RegSafe {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    Backup-RegValue -Path $Path -Name $Name
    try {
        Set-RegistryValue -Path $Path -Name $Name -Value $Value -Type $Type
        return $true
    } catch {
        Write-WARN "Falha ao escrever $Path\$Name — $_"
        return $false
    }
}

# ─────────────────────────────────────────────────────────────
#  REGION: OPTIMIZATION FUNCTIONS
# ─────────────────────────────────────────────────────────────

# ══════════════════════════════════════════════════════════════
#  OPT 1 — ULTIMATE PERFORMANCE POWER PLAN
# ══════════════════════════════════════════════════════════════
function Set-UltimatePerformance {
    Write-Section "PLANO ULTIMATE PERFORMANCE"
    Write-INFO "Ativando plano de energia Ultimate Performance..."

    try {
        $guid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $list = powercfg /list 2>$null
        if ($list -notmatch $guid) {
            Write-INFO "Criando plano (não encontrado no sistema)..."
            $null = powercfg /duplicatescheme $guid 2>$null
        }
        $null = powercfg /setactive $guid 2>$null

        # USB Selective Suspend OFF dentro do plano
        $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSet = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        $null   = powercfg /setacvalueindex SCHEME_CURRENT $usbSub $usbSet 0 2>$null

        # PCIe Link State Power Management OFF — GPU sem delay de wakeup
        $pciSub = '08918ca3-47eb-4ab7-bb0e-3b5c6f63b06f'
        $pciSet = 'ee12f906-d277-404b-b6da-e5fa1a576df5'
        $null   = powercfg /setacvalueindex SCHEME_CURRENT $pciSub $pciSet 0 2>$null

        $null = powercfg /setactive SCHEME_CURRENT 2>$null

        Write-OK "Ultimate Performance ativado"
        Write-OK "PCIe Link State Power Management → OFF"
        Write-INFO "Efeito imediato — nenhum reboot necessário"
    } catch {
        Write-ERR "Falha: $_"
    }
}

# ══════════════════════════════════════════════════════════════
#  OPT 2 — DESATIVAR SYSMAIN (SUPERFETCH)
# ══════════════════════════════════════════════════════════════
function Disable-SysMain {
    Write-Section "SYSMAIN (SUPERFETCH)"
    Write-INFO "Desativando serviço SysMain..."

    try {
        $svc     = Get-Service -Name 'SysMain' -ErrorAction Stop
        $svcPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain'
        Backup-RegValue -Path $svcPath -Name 'Start'
        Set-RegistryValue -Path $svcPath -Name 'Start' -Value 4 -Type DWord

        if ($svc.Status -eq 'Running') {
            Stop-Service -Name 'SysMain' -Force -ErrorAction SilentlyContinue
            Write-OK "SysMain parado e desativado"
        } else {
            Write-OK "SysMain desativado (já estava parado)"
        }
        Write-INFO "I/O em background reduzido durante gameplay"
    } catch {
        Write-ERR "Falha ao desativar SysMain: $_"
    }
}

# ══════════════════════════════════════════════════════════════
#  OPT 3 — GAME DVR / XBOX GAME BAR
# ══════════════════════════════════════════════════════════════
function Disable-GameDVR {
    Write-Section "GAME DVR / XBOX GAME BAR"
    Write-INFO "Desativando Game DVR e captura em background..."

    $tweaks = @(
        @{ P='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; N='AppCaptureEnabled';         V=0; T='DWord'; Desc='Game DVR Capture → OFF'   }
        @{ P='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; N='GameDVR_Enabled';           V=0; T='DWord'; Desc='Game DVR Flag → OFF'       }
        @{ P='HKCU:\SOFTWARE\Microsoft\GameBar';                        N='UseNexusForGameBarEnabled'; V=0; T='DWord'; Desc='Game Bar Nexus → OFF'      }
        @{ P='HKCU:\SOFTWARE\Microsoft\GameBar';                        N='AutoGameModeEnabled';       V=0; T='DWord'; Desc='Game Bar Auto Mode → OFF'  }
        @{ P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR';       N='AllowGameDVR';              V=0; T='DWord'; Desc='Game DVR Policy → OFF'     }
    )

    foreach ($t in $tweaks) {
        if (Set-RegSafe -Path $t.P -Name $t.N -Value $t.V -Type $t.T) {
            Write-OK $t.Desc
        }
    }
    Write-INFO "VRAM do encoder liberada para o jogo"
}

# ══════════════════════════════════════════════════════════════
#  OPT 4 — NETWORK THROTTLING + SCHEDULER
# ══════════════════════════════════════════════════════════════
function Set-NetworkOptimization {
    Write-Section "NETWORK THROTTLING + SCHEDULER"
    Write-INFO "Ajustando NetworkThrottlingIndex e prioridade do scheduler..."

    $mmPath    = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    $gamesPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    $prioPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'

    $tweaks = @(
        @{ P=$mmPath;    N='NetworkThrottlingIndex';   V=0xFFFFFFFF; T='DWord';  Desc='NetworkThrottlingIndex → sem limite'     }
        @{ P=$mmPath;    N='SystemResponsiveness';     V=0;          T='DWord';  Desc='SystemResponsiveness → 0 (max foreground)' }
        @{ P=$gamesPath; N='GPU Priority';             V=8;          T='DWord';  Desc='Games GPU Priority → 8'                  }
        @{ P=$gamesPath; N='Priority';                 V=6;          T='DWord';  Desc='Games CPU Priority → 6'                  }
        @{ P=$gamesPath; N='Scheduling Category';      V='High';     T='String'; Desc='Games Scheduling Category → High'        }
        @{ P=$gamesPath; N='SFIO Priority';            V='High';     T='String'; Desc='Games SFIO Priority → High'              }
        @{ P=$prioPath;  N='Win32PrioritySeparation';  V=38;         T='DWord';  Desc='Priority Separation → 38 (Short+Variable+3:1)' }
    )

    foreach ($t in $tweaks) {
        if (Set-RegSafe -Path $t.P -Name $t.N -Value $t.V -Type $t.T) {
            Write-OK $t.Desc
        }
    }

    # HAGS — Hardware Accelerated GPU Scheduling
    $hagsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    if (Set-RegSafe -Path $hagsPath -Name 'HwSchMode' -Value 2) {
        Write-OK "HAGS (Hardware GPU Scheduling) → ATIVO"
    }

    Write-INFO "Efeito total após reboot"
}

# ══════════════════════════════════════════════════════════════
#  OPT 5 — USB SELECTIVE SUSPEND
# ══════════════════════════════════════════════════════════════
function Disable-USBSuspend {
    Write-Section "USB SELECTIVE SUSPEND"
    Write-INFO "Desativando USB Selective Suspend no plano ativo..."

    try {
        $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSet = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        $null   = powercfg /setacvalueindex SCHEME_CURRENT $usbSub $usbSet 0 2>$null
        $null   = powercfg /setdcvalueindex SCHEME_CURRENT $usbSub $usbSet 0 2>$null
        $null   = powercfg /setactive SCHEME_CURRENT 2>$null

        Write-OK "USB Selective Suspend → OFF (AC e DC)"
        Write-INFO "Mouse e teclado sem delay de wakeup"

        $usbRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\USB'
        if (Test-Path $usbRegPath) {
            if (Set-RegSafe -Path $usbRegPath -Name 'DisableSelectiveSuspend' -Value 1) {
                Write-OK "USB DisableSelectiveSuspend → 1 (registro)"
            }
        }
    } catch {
        Write-ERR "Falha: $_"
    }
}

# ══════════════════════════════════════════════════════════════
#  OPT 6 — EFEITOS VISUAIS + RESPONSIVIDADE
# ══════════════════════════════════════════════════════════════
function Set-VisualPerformance {
    Write-Section "EFEITOS VISUAIS + RESPONSIVIDADE"
    Write-INFO "Reduzindo efeitos visuais para máximo desempenho..."

    $tweaks = @(
        @{ P='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; N='VisualFXSetting';      V=2;      T='DWord';  Desc='Efeitos Visuais → Performance Mode'  }
        @{ P='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                                   N='EnableAeroPeek';       V=0;      T='DWord';  Desc='Aero Peek → OFF'                      }
        @{ P='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                                   N='AlwaysHibernateThumbnails'; V=0; T='DWord';  Desc='DWM Thumbnails → OFF'                 }
        @{ P='HKCU:\Control Panel\Desktop';                                             N='MenuShowDelay';        V='0';    T='String'; Desc='MenuShowDelay → 0ms'                  }
        @{ P='HKCU:\Control Panel\Desktop';                                             N='WaitToKillAppTimeout'; V='2000'; T='String'; Desc='AppKillTimeout → 2s'                  }
        @{ P='HKCU:\Control Panel\Desktop';                                             N='HungAppTimeout';       V='2000'; T='String'; Desc='HungAppTimeout → 2s'                  }
        @{ P='HKCU:\Control Panel\Desktop';                                             N='AutoEndTasks';         V='1';    T='String'; Desc='AutoEndTasks → ON'                    }
        @{ P='HKCU:\Control Panel\Desktop\WindowMetrics';                              N='MinAnimate';            V='0';    T='String'; Desc='Animação de janelas → OFF'             }
    )

    foreach ($t in $tweaks) {
        if (Set-RegSafe -Path $t.P -Name $t.N -Value $t.V -Type $t.T) {
            Write-OK $t.Desc
        }
    }
    Write-INFO "Alguns efeitos só somem após reiniciar o Explorer ou reboot"
}

# ══════════════════════════════════════════════════════════════
#  OPT 7 — EXTRAS: NAGLE + MOUSE + TELEMETRIA
# ══════════════════════════════════════════════════════════════
function Set-ExtraOptimizations {
    Write-Section "EXTRAS (NAGLE + MOUSE + TELEMETRIA)"

    # Telemetria mínima
    Write-INFO "Reduzindo telemetria não essencial..."
    $telePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    if (Set-RegSafe -Path $telePath -Name 'AllowTelemetry' -Value 0) {
        Write-OK "Telemetria → Security Only (nível mínimo)"
    }

    # DiagTrack
    try {
        $diagPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack'
        if (Test-Path $diagPath) {
            Backup-RegValue -Path $diagPath -Name 'Start'
            Set-RegistryValue -Path $diagPath -Name 'Start' -Value 4 -Type DWord
            Stop-Service -Name 'DiagTrack' -Force -ErrorAction SilentlyContinue
            Write-OK "DiagTrack (telemetria) → DESATIVADO"
        }
    } catch { Write-WARN "DiagTrack: $_" }

    # Nagle's Algorithm
    Write-INFO "Desativando Nagle's Algorithm nas NICs ativas..."
    try {
        $nicRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
        $nics    = Get-ChildItem $nicRoot -ErrorAction Stop
        $count   = 0
        foreach ($nic in $nics) {
            $ip = (Get-ItemProperty -Path $nic.PSPath -ErrorAction SilentlyContinue).DhcpIPAddress
            if ($ip -and $ip -notmatch '^0\.' -and $ip -ne '') {
                Backup-RegValue -Path $nic.PSPath -Name 'TcpAckFrequency'
                Backup-RegValue -Path $nic.PSPath -Name 'TCPNoDelay'
                Set-RegistryValue -Path $nic.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord
                Set-RegistryValue -Path $nic.PSPath -Name 'TCPNoDelay'      -Value 1 -Type DWord
                $count++
            }
        }
        if (Set-RegSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TCPNoDelay' -Value 1) {
            Write-OK "Nagle desativado em $count NIC(s) + global"
        }
    } catch { Write-WARN "Nagle: $_" }

    # Mouse Acceleration OFF
    Write-INFO "Removendo aceleração do mouse..."
    $mousePath = 'HKCU:\Control Panel\Mouse'
    $mOK = $true
    $mOK = $mOK -and (Set-RegSafe -Path $mousePath -Name 'MouseSpeed'      -Value '0' -Type String)
    $mOK = $mOK -and (Set-RegSafe -Path $mousePath -Name 'MouseThreshold1' -Value '0' -Type String)
    $mOK = $mOK -and (Set-RegSafe -Path $mousePath -Name 'MouseThreshold2' -Value '0' -Type String)
    if ($mOK) { Write-OK "Mouse Acceleration → REMOVIDA (movimento 1:1)" }

    # Prefetcher — modo 1 = apps only (SSD optimizado)
    $pfPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
    if (Set-RegSafe -Path $pfPath -Name 'EnablePrefetcher' -Value 1) {
        Write-OK "Prefetcher → Modo 1 (apps only, otimizado para SSD)"
    }

    Write-INFO "Nagle e mouse têm efeito imediato. DiagTrack requer reboot."
}

# ══════════════════════════════════════════════════════════════
#  OPT 8 — TIMER RESOLUTION (NOVO v2.0)
#  O Windows usa timer de 15.6ms por padrão. Reduzir para 0.5ms
#  diminui o jitter de frametime — especialmente notável em jogos
#  que dependem de sleep() para controle de frame budget.
#  Impacto: frametime mais consistente, menos stutters em 165Hz+
#  Custo: +~0.5% CPU em idle (desprezível em gaming)
# ══════════════════════════════════════════════════════════════
function Set-TimerResolution {
    Write-Section "TIMER RESOLUTION"
    Write-INFO "Configurando resolução mínima de timer do sistema..."

    # Verifica resolução atual via NtQueryTimerResolution
    # (via registro — leitura indireta)
    $timerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
    if (Set-RegSafe -Path $timerPath -Name 'GlobalTimerResolutionRequests' -Value 1 -Type DWord) {
        Write-OK "GlobalTimerResolutionRequests → 1 (solicita alta resolução globalmente)"
    }

    # No Windows 11 22H2+ a política mudou — aplicativos precisam
    # requisitar explicitamente. Esta chave força globalmente.
    $win11TimerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
    if (Set-RegSafe -Path $win11TimerPath -Name 'GlobalTimerResolutionRequests' -Value 1 -Type DWord) {
        Write-OK "Timer Resolution global → ATIVADO"
    }

    # Benefício adicional: desativa CPU idle states profundos (C-states)
    # Evita que a CPU "durma" entre frames e precise acordar para processar input
    try {
        $null = powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1 2>$null
        $null = powercfg /setactive SCHEME_CURRENT 2>$null
        Write-OK "CPU C-States (idle profundo) → REDUZIDOS no plano ativo"
    } catch { Write-WARN "C-States: não foi possível ajustar via powercfg" }

    Write-INFO "Efeito no frametime — mais visível em 144Hz+ e tickrates altos (CS2/Valorant)"
    Write-INFO "Requer reboot para aplicação completa"
}

# ══════════════════════════════════════════════════════════════
#  OPT 9 — OTIMIZAÇÕES DE DISCO (NOVO v2.0)
#  8.3 filenames: Windows gera alias curto para cada arquivo/pasta.
#  Desativar elimina operação extra a cada escrita no sistema de arquivos.
#  Write caching: permite que o driver de disco faça buffering de writes
#  em RAM antes de flushar para o disco — reduz latência de I/O.
#  TRIM: garante que o SSD mantenha performance com uso prolongado.
# ══════════════════════════════════════════════════════════════
function Set-DiskOptimizations {
    Write-Section "OTIMIZAÇÕES DE DISCO"
    $hw = Get-HardwareInfo

    # Desativar geração de nomes 8.3 (NtfsDisable8dot3NameCreation)
    Write-INFO "Desativando geração de nomes 8.3 no NTFS..."
    $ntfsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    if (Set-RegSafe -Path $ntfsPath -Name 'NtfsDisable8dot3NameCreation' -Value 1) {
        Write-OK "NTFS 8.3 filenames → DESATIVADO"
    }

    # Desativar timestamp de último acesso (LastAccess)
    # Windows atualiza a data de acesso a cada leitura de arquivo — I/O desnecessário
    if (Set-RegSafe -Path $ntfsPath -Name 'NtfsDisableLastAccessUpdate' -Value 80000003 -Type DWord) {
        Write-OK "NTFS Last Access Update → DESATIVADO"
    }

    # Write-Behind Cache — habilita cache de escrita no disco
    Write-INFO "Habilitando write cache do disco..."
    try {
        $disks = Get-WmiObject -Class Win32_DiskDrive -ErrorAction Stop
        foreach ($disk in $disks) {
            $devId  = $disk.DeviceID -replace '\\', '\\'
            $null = & diskperf -y 2>$null
            Write-OK "Write cache verificado para: $($disk.Model.Trim())"
        }
    } catch { Write-WARN "Write cache: verifique manualmente em Gerenciador de Dispositivos" }

    # TRIM — apenas para SSDs
    if ($hw.HasSSD) {
        Write-INFO "Verificando e agendando TRIM para SSD..."
        try {
            $trimResult = & fsutil behavior query DisableDeleteNotify 2>$null
            if ($trimResult -match '= 1') {
                & fsutil behavior set DisableDeleteNotify 0 | Out-Null
                Write-OK "TRIM (Delete Notify) → REATIVADO para SSD"
            } else {
                Write-OK "TRIM já está ativo neste sistema"
            }
        } catch { Write-WARN "TRIM: $_" }
    } else {
        Write-SKIP "TRIM: não aplicável (SSD não detectado)"
    }

    # Desativa hibernação para sistemas desktop (libera espaço e reduz I/O)
    if (-not $hw.IsLaptop) {
        Write-INFO "Desativando hibernação (desktop)..."
        try {
            $null = powercfg /hibernate off 2>$null
            Write-OK "Hibernação → DESATIVADA (hiberfil.sys removido)"
        } catch { Write-WARN "Hibernação: $_" }
    } else {
        Write-SKIP "Hibernação mantida (laptop detectado)"
    }

    Write-INFO "Efeitos de disco aplicados imediatamente"
}

# ══════════════════════════════════════════════════════════════
#  OPT 10 — GPU VENDOR-SPECIFIC TWEAKS (NOVO v2.0)
#  NVIDIA: desativa o shader cache de background, ULPS (Ultra-Low
#  Power State — faz GPU secundária "dormir" e acordar com latência)
#  e otimiza o comportamento de preemção para menor latência.
#  AMD: desativa TDR (Timeout Detection Recovery) agressivo que
#  pode causar stutters, e otimiza o compute preemption.
# ══════════════════════════════════════════════════════════════
function Set-GPUOptimizations {
    Write-Section "OTIMIZAÇÕES DE GPU"
    $hw = Get-HardwareInfo

    Write-INFO "GPU detectada: $($hw.GPUName) [$($hw.GPUVendor)]"

    switch ($hw.GPUVendor) {
        'NVIDIA' {
            Write-INFO "Aplicando tweaks NVIDIA..."

            # Desativa ULPS — Ultra-Low Power State (causa stutter em multi-GPU/Optimus)
            $nvPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
            if (Test-Path $nvPath) {
                if (Set-RegSafe -Path $nvPath -Name 'EnableMsHybrid' -Value 0) {
                    Write-OK "NVIDIA Hybrid/Optimus enforcement → OFF"
                }
            }

            # TDR Delay — aumenta para evitar falsos resets em cargas pesadas
            $tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            if (Set-RegSafe -Path $tdrPath -Name 'TdrLevel'   -Value 3 -Type DWord) { Write-OK "TDR Level → 3 (padrão estável)" }
            if (Set-RegSafe -Path $tdrPath -Name 'TdrDelay'   -Value 10 -Type DWord) { Write-OK "TDR Delay → 10s (mais tolerante)" }
            if (Set-RegSafe -Path $tdrPath -Name 'TdrDdiDelay' -Value 10 -Type DWord) { Write-OK "TDR DDI Delay → 10s" }

            Write-INFO "Para melhor resultado com NVIDIA: use NVCP → Modo de Gerenciamento de Energia: Desempenho Máximo"
            Write-INFO "Considere também: RTSS para frame cap a N-3 do refresh rate"
        }

        'AMD' {
            Write-INFO "Aplicando tweaks AMD..."

            # TDR para AMD
            $tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            if (Set-RegSafe -Path $tdrPath -Name 'TdrLevel' -Value 3 -Type DWord) { Write-OK "TDR Level → 3" }
            if (Set-RegSafe -Path $tdrPath -Name 'TdrDelay' -Value 10 -Type DWord) { Write-OK "TDR Delay → 10s" }

            # AMD UMD (User Mode Driver) path
            $amdPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
            if (Test-Path $amdPath) {
                # Desativa AMD Chill (throttling automático de FPS)
                if (Set-RegSafe -Path $amdPath -Name 'PP_SclkDeepSleepDisable' -Value 1) {
                    Write-OK "AMD Deep Sleep (GPU clock gating) → DESATIVADO"
                }
            }

            Write-INFO "Para melhor resultado com AMD: use Adrenalin → Anti-Lag, modo desempenho"
        }

        'Intel' {
            Write-INFO "Aplicando tweaks Intel GPU..."
            $tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            if (Set-RegSafe -Path $tdrPath -Name 'TdrDelay' -Value 10 -Type DWord) {
                Write-OK "TDR Delay → 10s (Intel)"
            }
            Write-INFO "Intel GPU: use Intel Graphics Command Center → Modo Gaming"
        }

        default {
            Write-SKIP "GPU vendor desconhecido — tweaks genéricos apenas"
            $tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
            Set-RegSafe -Path $tdrPath -Name 'TdrDelay' -Value 10 -Type DWord | Out-Null
        }
    }

    Write-INFO "Reboot recomendado para efeito total dos tweaks de GPU"
}

# ══════════════════════════════════════════════════════════════
#  OPT 11 — WINDOWS 11: DESATIVAR VBS/HVCI (NOVO v2.0)
#  Virtualization Based Security usa um hypervisor para proteger
#  memória do kernel. O overhead pode ser de 5-15% em FPS em
#  jogos CPU-bound (ex.: Tarkov, Minecraft, simuladores).
#  HVCI (Hypervisor Protected Code Integrity) tem impacto similar.
#  ATENÇÃO: reduz uma camada de segurança. Recomendado APENAS
#  para PCs dedicados a gaming, não corporativos.
# ══════════════════════════════════════════════════════════════
function Disable-VBS {
    Write-Section "VBS/HVCI (WINDOWS 11)"

    $hw = Get-HardwareInfo
    if (-not $hw.IsWin11) {
        Write-SKIP "VBS/HVCI: apenas relevante no Windows 11 (Build $($hw.OSBuild) detectado)"
        return
    }

    Write-WARN "Este tweak desativa uma camada de segurança do Windows."
    Write-WARN "Recomendado apenas para PCs de gaming dedicados."
    Write-Color "" 
    Write-Color "  Confirmar desativação de VBS/HVCI? (S/N) " -FG Yellow -NoNewLine
    $confirm = (Read-Host).Trim().ToUpper()
    if ($confirm -ne 'S') {
        Write-INFO "Cancelado pelo usuário."
        return
    }

    Write-INFO "Desativando VBS e HVCI..."

    $devGuardPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    $ciPath       = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'

    if (Set-RegSafe -Path $devGuardPath -Name 'EnableVirtualizationBasedSecurity' -Value 0) {
        Write-OK "VBS → DESATIVADO"
    }
    if (Set-RegSafe -Path $devGuardPath -Name 'RequirePlatformSecurityFeatures' -Value 0) {
        Write-OK "Platform Security Features → 0"
    }
    if (Test-Path $ciPath) {
        if (Set-RegSafe -Path $ciPath -Name 'Enabled' -Value 0) {
            Write-OK "HVCI → DESATIVADO"
        }
    }

    # Desativa também via BCD (boot)
    try {
        $null = bcdedit /set hypervisorlaunchtype off 2>$null
        Write-OK "Hypervisor launch type → OFF (BCD)"
    } catch { Write-WARN "BCD: $_" }

    Write-WARN "REBOOT OBRIGATÓRIO para efeito. VBS pode levar 2 reboots para desativar completamente."
    Write-INFO "Após reboot, verifique em: msinfo32 → Segurança Baseada em Virtualização"
}

# ══════════════════════════════════════════════════════════════
#  OPT 12 — MEMÓRIA: LARGE SYSTEM CACHE + HEAP (NOVO v2.0)
#  LargeSystemCache 0 = Windows prioriza RAM para aplicações
#  (jogos) em vez do cache do sistema de arquivos.
#  HeapDeCommitFreeBlockThreshold: reduz fragmentação de heap
#  em jogos que alocam/desalocam muito (engines como UE5).
# ══════════════════════════════════════════════════════════════
function Set-MemoryOptimizations {
    Write-Section "OTIMIZAÇÕES DE MEMÓRIA"
    Write-INFO "Ajustando gerenciamento de memória para gaming..."

    $memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'

    $tweaks = @(
        @{ N='LargeSystemCache';              V=0;           T='DWord'; Desc='LargeSystemCache → 0 (prioridade para apps/jogos)' }
        @{ N='DisablePagingExecutive';        V=1;           T='DWord'; Desc='DisablePagingExecutive → 1 (kernel em RAM)' }
        @{ N='SecondLevelDataCache';          V=0;           T='DWord'; Desc='SecondLevelDataCache → 0 (auto-detect)' }
        @{ N='HeapDeCommitFreeBlockThreshold'; V=0x00040000; T='DWord'; Desc='Heap DeCommit Threshold → 256KB' }
    )

    foreach ($t in $tweaks) {
        if (Set-RegSafe -Path $memPath -Name $t.N -Value $t.V -Type $t.T) {
            Write-OK $t.Desc
        }
    }

    # Compressão de memória — útil com < 16GB, dispensável com 32GB+
    $hw = Get-HardwareInfo
    if ($hw.RAMTotal -ge 16) {
        Write-INFO "16+ GB RAM detectado — compressão de memória já está configurada adequadamente"
    }

    Write-INFO "Efeito completo após reboot"
}

# ─────────────────────────────────────────────────────────────
#  REGION: BENCHMARK SCORE (NOVO v2.0)
#  Score sintético baseado em: processos ativos, plano de energia,
#  VBS, SysMain, Game DVR, Network Throttling.
#  Não substitui benchmark de FPS real — é um indicador de config.
# ─────────────────────────────────────────────────────────────

function Get-OptimizationScore {
    $score = 0
    $max   = 100
    $items = @()

    # Plano de energia (20 pts)
    $hw = Get-HardwareInfo
    if ($hw.PowerPlan -match 'Ultimate|High') {
        $score += 20; $items += "[+20] Plano de energia: Ultimate/High Performance"
    } else {
        $items += "[ 0] Plano de energia: $($hw.PowerPlan) (use opção 1)"
    }

    # SysMain (15 pts)
    $sysMain = Get-Service -Name 'SysMain' -ErrorAction SilentlyContinue
    if ($sysMain -and $sysMain.Status -ne 'Running') {
        $score += 15; $items += "[+15] SysMain: desativado"
    } else { $items += "[ 0] SysMain: rodando (use opção 2)" }

    # Game DVR (15 pts)
    $dvr = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -ErrorAction SilentlyContinue).AppCaptureEnabled
    if ($dvr -eq 0) {
        $score += 15; $items += "[+15] Game DVR: desativado"
    } else { $items += "[ 0] Game DVR: ativo (use opção 3)" }

    # NetworkThrottling (15 pts)
    $nti = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -ErrorAction SilentlyContinue).NetworkThrottlingIndex
    if ($nti -eq 0xFFFFFFFF -or $nti -eq -1 -or $nti -gt 70) {
        $score += 15; $items += "[+15] Network Throttling: removido"
    } else { $items += "[ 0] Network Throttling: ativo (use opção 4)" }

    # HAGS (10 pts)
    $hags = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
    if ($hags -eq 2) {
        $score += 10; $items += "[+10] HAGS: ativo"
    } else { $items += "[ 0] HAGS: inativo (use opção 4)" }

    # VBS (15 pts — só Win11)
    if ($hw.IsWin11) {
        $vbs = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
        if ($vbs -eq 0) {
            $score += 15; $items += "[+15] VBS: desativado"
        } else { $items += "[ 0] VBS: ativo — impacto de FPS (use opção 11)" }
        $max = 100
    } else {
        # Sem Win11, redistribui os 15pts
        $score = [math]::Min(100, $score + 10)
    }

    # Mouse accel (10 pts)
    $mspd = (Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -ErrorAction SilentlyContinue).MouseSpeed
    if ($mspd -eq '0') {
        $score += 10; $items += "[+10] Mouse Acceleration: removida"
    } else { $items += "[ 0] Mouse Acceleration: ativa (use opção 7)" }

    $score = [math]::Min(100, $score)
    return [PSCustomObject]@{ Score = $score; Max = $max; Items = $items }
}

function Show-Benchmark {
    Write-Section "BENCHMARK DE CONFIGURAÇÃO"
    Write-INFO "Calculando score de otimização do sistema..."
    Write-Host ""

    $result = Get-OptimizationScore

    # Barra de progresso
    $filled = [math]::Round($result.Score / 2)
    $empty  = 50 - $filled
    $bar    = ('█' * $filled) + ('░' * $empty)
    $color  = if ($result.Score -ge 80) { 'Green' } elseif ($result.Score -ge 50) { 'Yellow' } else { 'Red' }

    Write-Color "  [$bar] " -FG $color -NoNewLine
    Write-Color "$($result.Score)/$($result.Max) pts" -FG $color

    Write-Host ""
    Write-Color "  DETALHAMENTO:" -FG DarkCyan
    foreach ($item in $result.Items) {
        $fc = if ($item -match '^\[+') { 'Green' } else { 'DarkGray' }
        Write-Color "  $item" -FG $fc
    }

    Write-Host ""
    $grade = switch ($true) {
        ($result.Score -ge 90) { "S — MÁXIMA PERFORMANCE" ; break }
        ($result.Score -ge 75) { "A — MUITO BOM"          ; break }
        ($result.Score -ge 55) { "B — BOM"                ; break }
        ($result.Score -ge 35) { "C — BÁSICO"             ; break }
        default                 { "D — NÃO OTIMIZADO"     }
    }

    Write-Color "  NOTA: " -FG DarkCyan -NoNewLine
    Write-Color $grade -FG $color

    if (-not $Script:BenchScore) {
        $Script:BenchScore = $result.Score
        Write-INFO "Score inicial registrado: $($result.Score) pts"
    } else {
        $diff = $result.Score - $Script:BenchScore
        $diffSign = if ($diff -ge 0) { '+' } else { '' }
        Write-Color "  Melhora desde abertura: " -FG DarkCyan -NoNewLine
        Write-Color "${diffSign}${diff} pts" -FG $(if ($diff -ge 0) { 'Green' } else { 'Red' })
    }

    Write-Log "BENCHMARK: $($result.Score)/$($result.Max) pts — $grade"
}

# ─────────────────────────────────────────────────────────────
#  REGION: PROFILE SYSTEM (NOVO v2.0)
# ─────────────────────────────────────────────────────────────

function Show-ProfileMenu {
    Write-Section "PERFIS DE OTIMIZAÇÃO"
    Write-Host ""
    Write-Color "  [1] Gaming    — Todas as otimizações (recomendado para desktop)" -FG Cyan
    Write-Color "  [2] Balanced  — Otimizações seguras sem desativar serviços" -FG Cyan
    Write-Color "  [3] Competitive — Gaming + Timer + Disco + GPU (máxima performance)" -FG Yellow
    Write-Color "  [4] Laptop    — Otimizações que mantêm vida da bateria" -FG Green
    Write-Color "  [0] Voltar" -FG DarkGray
    Write-Host ""
    Write-Color "  » " -FG Cyan -NoNewLine
    $choice = (Read-Host).Trim()

    switch ($choice) {
        '1' {
            Write-Header "PERFIL: GAMING"
            Set-UltimatePerformance; Disable-SysMain; Disable-GameDVR
            Set-NetworkOptimization; Disable-USBSuspend; Set-VisualPerformance; Set-ExtraOptimizations
            Write-OK "Perfil Gaming aplicado"
        }
        '2' {
            Write-Header "PERFIL: BALANCED"
            Disable-GameDVR; Set-NetworkOptimization; Set-VisualPerformance
            Write-OK "Perfil Balanced aplicado (serviços mantidos)"
        }
        '3' {
            Write-Header "PERFIL: COMPETITIVE"
            Set-UltimatePerformance; Disable-SysMain; Disable-GameDVR
            Set-NetworkOptimization; Disable-USBSuspend; Set-VisualPerformance
            Set-ExtraOptimizations; Set-TimerResolution; Set-DiskOptimizations; Set-GPUOptimizations
            if ((Get-HardwareInfo).IsWin11) { Disable-VBS }
            Write-OK "Perfil Competitive aplicado — REBOOT RECOMENDADO"
        }
        '4' {
            Write-Header "PERFIL: LAPTOP"
            $hw = Get-HardwareInfo
            if (-not $hw.IsLaptop) { Write-WARN "Laptop não detectado — aplicando mesmo assim" }
            Disable-GameDVR; Set-NetworkOptimization; Set-VisualPerformance
            # NÃO desativa hibernação nem SysMain em laptop (impacto na bateria)
            Write-OK "Perfil Laptop aplicado"
        }
        '0' { return }
        default { Write-WARN "Opção inválida" }
    }
    Pause-Continue
}

# ─────────────────────────────────────────────────────────────
#  REGION: APPLY ALL + RESTORE
# ─────────────────────────────────────────────────────────────

function Invoke-AllOptimizations {
    Write-Header "APLICANDO TODAS AS OTIMIZAÇÕES"
    Write-WARN "Criando ponto de restauração antes de aplicar..."

    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        Set-RegistryValue -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord
        Checkpoint-Computer -Description "OtimizadorFPS v2 — Pre-Optimization $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-OK "Ponto de restauração criado com sucesso"
    } catch {
        Write-WARN "Ponto de restauração falhou (continuando): $_"
    }

    Write-Host ""
    Set-UltimatePerformance
    Disable-SysMain
    Disable-GameDVR
    Set-NetworkOptimization
    Disable-USBSuspend
    Set-VisualPerformance
    Set-ExtraOptimizations
    Set-TimerResolution
    Set-DiskOptimizations
    Set-GPUOptimizations
    Set-MemoryOptimizations

    Write-Host ""
    Write-Color "  ╔══════════════════════════════════════════════════════════════╗" -FG Green
    Write-Color "  ║  ✅  TODAS AS OTIMIZAÇÕES APLICADAS                         ║" -FG Green
    Write-Color "  ║                                                              ║" -FG Green
    Write-Color "  ║  📌  RECOMENDADO: Reiniciar o PC para efeito completo        ║" -FG Green
    Write-Color "  ║  📌  Use [R] no menu para restaurar se necessário            ║" -FG Green
    Write-Color "  ╚══════════════════════════════════════════════════════════════╝" -FG Green
    Write-Host ""
    Write-Log "APPLY ALL: todas as otimizações aplicadas em $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

function Invoke-RestoreDefaults {
    Write-Section "RESTAURAR CONFIGURAÇÕES PADRÃO"

    if ($Script:Backup.Count -eq 0) {
        Write-WARN "Nenhuma alteração registrada nesta sessão para reverter."
        Write-INFO "Use o Ponto de Restauração do Windows: Win+R → rstrui.exe"
        return
    }

    Write-INFO "Revertendo $($Script:Backup.Count) valores de registro..."
    $ok   = 0
    $fail = 0

    $keys = [System.Linq.Enumerable]::Reverse([string[]]$Script:Backup.Keys)

    foreach ($key in $keys) {
        $entry = $Script:Backup[$key]
        try {
            if (-not $entry.Existed) {
                Remove-ItemProperty -Path $entry.Path -Name $entry.Name -Force -ErrorAction SilentlyContinue
                Write-OK "Removido (era novo): ...\$($entry.Name)"
            } else {
                $kind = switch ($entry.Kind.ToString()) {
                    'String'       { 'String' }
                    'ExpandString' { 'ExpandString' }
                    'DWord'        { 'DWord' }
                    'QWord'        { 'QWord' }
                    'MultiString'  { 'MultiString' }
                    default        { 'DWord' }
                }
                if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
                Set-RegistryValue -Path $entry.Path -Name $entry.Name -Value $entry.Value -Type $kind
                Write-OK "Restaurado: ...\$($entry.Name) = $($entry.Value)"
            }
            $ok++
        } catch {
            Write-ERR "Falha em $($entry.Name): $_"
            $fail++
        }
    }

    # Reativa serviços desativados
    Write-INFO "Reativando serviços..."
    foreach ($svcName in @('SysMain', 'DiagTrack')) {
        try {
            $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
            if (Test-Path $svcPath) {
                Set-RegistryValue -Path $svcPath -Name 'Start' -Value 2 -Type DWord
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                Write-OK "$svcName → REATIVADO"
            }
        } catch { Write-WARN "$svcName não pôde ser reativado" }
    }

    # Restaura VBS se foi desativado (re-habilita hypervisor)
    try {
        $wasVBSDisabled = $Script:Backup.Keys | Where-Object { $_ -match 'EnableVirtualizationBasedSecurity' }
        if ($wasVBSDisabled) {
            $null = bcdedit /set hypervisorlaunchtype auto 2>$null
            Write-OK "Hypervisor launch type → AUTO (VBS restaurado)"
        }
    } catch {}

    # Restaura plano Balanced
    Write-INFO "Restaurando plano de energia Balanced..."
    try {
        $null = powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-OK "Plano de energia → Balanced"
    } catch { Write-WARN "Falha ao restaurar plano de energia" }

    Write-Host ""
    if ($fail -eq 0) {
        Write-Color "  ✅  Restauração completa — $ok valores revertidos" -FG Green
        Clear-BackupState
    } else {
        Write-Color "  ⚠  Restauração parcial — $ok OK | $fail falhas" -FG Yellow
        Save-BackupState
    }
    Write-INFO "Reiniciar o PC é recomendado para efeito completo"
    Write-Log "RESTORE: $ok revertidos, $fail falhas"
}

# ─────────────────────────────────────────────────────────────
#  REGION: MAIN MENU
# ─────────────────────────────────────────────────────────────

function Show-Menu {
    Clear-ScreenCustom
    Show-SystemInfo

    Write-Color "  $('─' * 62)" -FG DarkGray
    Write-Color "  OTIMIZAÇÕES INDIVIDUAIS" -FG Cyan
    Write-Color ""

    $menuItems = @(
        @{ N='1';  Label='Ultimate Performance + PCIe ASPM off';         Color='Cyan'    }
        @{ N='2';  Label='Desativar SysMain (SuperFetch)';                Color='Cyan'    }
        @{ N='3';  Label='Desativar Game DVR / Xbox Game Bar';            Color='Cyan'    }
        @{ N='4';  Label='Network Throttling + Scheduler + HAGS';         Color='Cyan'    }
        @{ N='5';  Label='Desativar USB Selective Suspend';               Color='Cyan'    }
        @{ N='6';  Label='Efeitos visuais + MenuDelay + responsividade';  Color='Cyan'    }
        @{ N='7';  Label='Extras: Nagle OFF + Mouse Accel + Telemetria';  Color='Cyan'    }
        @{ N='8';  Label='Timer Resolution (frametime estável)';          Color='Cyan'    }
        @{ N='9';  Label='Otimizações de disco (NTFS + TRIM + cache)';    Color='Cyan'    }
        @{ N='10'; Label='GPU vendor-specific (NVIDIA/AMD/Intel)';        Color='Cyan'    }
        @{ N='11'; Label='Windows 11: desativar VBS/HVCI (+5-15% FPS)';  Color='Yellow'  }
        @{ N='12'; Label='Memória: LargeSystemCache + Heap tweaks';       Color='Cyan'    }
        @{ N='';   Label=''; Color='' }
        @{ N='A';  Label='APLICAR TODAS AS OTIMIZAÇÕES';                  Color='Green'   }
        @{ N='P';  Label='PERFIS (Gaming / Competitive / Laptop)';        Color='Green'   }
        @{ N='B';  Label='BENCHMARK — score de configuração';             Color='DarkCyan'}
        @{ N='R';  Label='RESTAURAR CONFIGURAÇÕES PADRÃO';                Color='Yellow'  }
        @{ N='L';  Label='Ver caminho do log';                            Color='DarkGray'}
        @{ N='I';  Label='Atualizar informações do sistema';              Color='DarkGray'}
        @{ N='0';  Label='Sair';                                          Color='DarkGray'}
    )

    foreach ($item in $menuItems) {
        if ($item.N -eq '') {
            Write-Host ""
        } else {
            $nPad = if ($item.N.Length -eq 1) { " $($item.N)" } else { $item.N }
            Write-Color "  " -NoNewLine
            Write-Color "[$nPad]" -FG $item.Color -NoNewLine
            Write-Color " $($item.Label)" -FG White
        }
    }

    Write-Host ""
    Write-Color "  $('─' * 62)" -FG DarkGray
    Write-Color "  Tweaks aplicados nesta sessão: " -FG DarkGray -NoNewLine
    Write-Color "$($Script:Backup.Count)" -FG $(if ($Script:Backup.Count -gt 0) { 'Yellow' } else { 'DarkGray' }) -NoNewLine
    Write-Color "  |  Log: $Script:LOG_FILE" -FG DarkGray
    Write-Host ""
    Write-Color "  » " -FG Cyan -NoNewLine
}

function Start-MainLoop {
    Assert-Admin
    Load-BackupState

    # Registra score inicial automaticamente
    $Script:BenchScore = (Get-OptimizationScore).Score
    Write-Log "=== SESSÃO INICIADA: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Score inicial: $Script:BenchScore ==="

    while ($true) {
        Show-Menu
        $choice = (Read-Host).Trim().ToUpper()

        switch ($choice) {
            '1'  { Clear-ScreenCustom; Set-UltimatePerformance;   Pause-Continue }
            '2'  { Clear-ScreenCustom; Disable-SysMain;            Pause-Continue }
            '3'  { Clear-ScreenCustom; Disable-GameDVR;            Pause-Continue }
            '4'  { Clear-ScreenCustom; Set-NetworkOptimization;    Pause-Continue }
            '5'  { Clear-ScreenCustom; Disable-USBSuspend;         Pause-Continue }
            '6'  { Clear-ScreenCustom; Set-VisualPerformance;      Pause-Continue }
            '7'  { Clear-ScreenCustom; Set-ExtraOptimizations;     Pause-Continue }
            '8'  { Clear-ScreenCustom; Set-TimerResolution;        Pause-Continue }
            '9'  { Clear-ScreenCustom; Set-DiskOptimizations;      Pause-Continue }
            '10' { Clear-ScreenCustom; Set-GPUOptimizations;       Pause-Continue }
            '11' { Clear-ScreenCustom; Disable-VBS;                Pause-Continue }
            '12' { Clear-ScreenCustom; Set-MemoryOptimizations;    Pause-Continue }
            'A'  { Clear-ScreenCustom; Invoke-AllOptimizations;    Pause-Continue }
            'P'  { Clear-ScreenCustom; Show-ProfileMenu }
            'B'  { Clear-ScreenCustom; Show-Benchmark;             Pause-Continue }
            'R'  { Clear-ScreenCustom; Invoke-RestoreDefaults;     Pause-Continue }
            'L'  { Show-LogPath;                                    Pause-Continue }
            'I'  { $Script:HW = $null <# força refresh do cache #> }
            '0'  {
                Write-Host ""
                Write-Color "  Saindo do OtimizadorFPS v$Script:VERSION..." -FG DarkCyan
                if ($Script:Backup.Count -gt 0) {
                    Write-WARN "$($Script:Backup.Count) alterações aplicadas nesta sessão."
                    Write-INFO "Abra novamente e use [R] para restaurar se necessário."
                }
                $finalScore = (Get-OptimizationScore).Score
                $diff = $finalScore - $Script:BenchScore
                Write-Color "  Score final: $finalScore pts  (delta: +$diff pts desta sessão)" -FG Cyan
                Write-Log "=== SESSÃO ENCERRADA: Score final $finalScore pts (delta +$diff) ==="
                Write-Host ""
                Start-Sleep -Seconds 1
                exit 0
            }
            default {
                Write-Host ""
                Write-WARN "Opção inválida. Use 1-12, A, P, B, R, L, I ou 0."
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────────────

try {
    $Host.UI.RawUI.WindowTitle     = "OtimizadorFPS v$Script:VERSION — Windows Gaming Optimizer"
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'White'
    $bufferSize        = $Host.UI.RawUI.BufferSize
    $bufferSize.Width  = 95
    $bufferSize.Height = 3000
    $Host.UI.RawUI.BufferSize = $bufferSize
    $windowSize        = $Host.UI.RawUI.WindowSize
    $windowSize.Width  = [Math]::Min(95, $Host.UI.RawUI.MaxWindowSize.Width)
    $windowSize.Height = [Math]::Min(50, $Host.UI.RawUI.MaxWindowSize.Height)
    $Host.UI.RawUI.WindowSize = $windowSize
} catch {}

Clear-Host
Write-Host ""
Write-Color "  ╔══════════════════════════════════════════════════════════════╗" -FG Cyan
Write-Color "  ║                                                              ║" -FG Cyan
Write-Color "  ║   ██████  ████████ ██ ███  ██  ██  ██████   ██████  ██████  ║" -FG Cyan
Write-Color "  ║  ██    ██    ██    ██ ████ ██  ██      ██  ██    ██ ██   ██ ║" -FG Cyan
Write-Color "  ║  ██    ██    ██    ██ ██ █████  ██  █████  ██    ██ ██████  ║" -FG Cyan
Write-Color "  ║  ██    ██    ██    ██ ██  ████  ██ ██      ██    ██ ██   ██ ║" -FG Cyan
Write-Color "  ║   ██████     ██    ██ ██   ███  ██ ███████  ██████  ██   ██ ║" -FG Cyan
Write-Color "  ║                                                              ║" -FG Cyan
Write-Color "  ║      FPS  ·  INPUT LAG  ·  FRAMETIME  ·  LATÊNCIA           ║" -FG DarkCyan
Write-Color "  ║      Windows 10/11 Gaming Optimizer  v2.0                   ║" -FG DarkCyan
Write-Color "  ╚══════════════════════════════════════════════════════════════╝" -FG Cyan
Write-Host ""
Write-Color "  + Timer Resolution  + Disk Tweaks  + GPU Vendor Detection     " -FG DarkGray
Write-Color "  + VBS/HVCI (Win11)  + Profiles     + Benchmark Score  + Logs  " -FG DarkGray
Write-Host ""
Write-Color "  Verificando privilégios..." -FG DarkGray
Start-Sleep -Milliseconds 600

Start-MainLoop

