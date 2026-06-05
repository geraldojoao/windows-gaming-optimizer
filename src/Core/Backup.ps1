# Backup and rollback state helpers.

function ConvertTo-Hashtable {
    param($InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in $InputObject.Keys) {
            $hash[$key] = ConvertTo-Hashtable $InputObject[$key]
        }
        return $hash
    }

    if ($InputObject -is [pscustomobject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable $property.Value
        }
        return $hash
    }

    if ($InputObject -is [array]) {
        return @($InputObject | ForEach-Object { ConvertTo-Hashtable $_ })
    }

    return $InputObject
}

function Save-BackupState {
    try {
        $backupDir = Split-Path -Parent $Script:BACKUP_FILE
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $Script:Backup |
            ConvertTo-Json -Depth 8 |
            Set-Content -LiteralPath $Script:BACKUP_FILE -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-WARN "Falha ao salvar backup persistente: $_"
    }
}

function Load-BackupState {
    try {
        if (-not (Test-Path $Script:BACKUP_FILE)) { return @{} }

        $json = Get-Content -LiteralPath $Script:BACKUP_FILE -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($json)) { return @{} }

        $loaded = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        $backup = ConvertTo-Hashtable $loaded
        if ($backup -is [hashtable]) { return $backup }
    } catch {
        Write-WARN "Falha ao carregar backup persistente: $_"
    }

    return @{}
}

function Clear-BackupState {
    try {
        if (Test-Path $Script:BACKUP_FILE) {
            Remove-Item -LiteralPath $Script:BACKUP_FILE -Force -ErrorAction Stop
        }
    } catch {
        Write-WARN "Falha ao limpar backup persistente: $_"
    }
}

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
            Kind    = (Get-Item $Path -ErrorAction Stop).GetValueKind($Name).ToString()
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
