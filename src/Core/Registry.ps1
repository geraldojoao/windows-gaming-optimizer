# Registry write helpers with backup-aware rollback support.

function Normalize-RegKind {
    param($Kind)

    if ($null -eq $Kind) { return 'DWord' }

    switch ($Kind.ToString()) {
        'String'       { return 'String' }
        'ExpandString' { return 'ExpandString' }
        'Binary'       { return 'Binary' }
        'DWord'        { return 'DWord' }
        'QWord'        { return 'QWord' }
        'MultiString'  { return 'MultiString' }
        default        { return 'DWord' }
    }
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
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        $kind = Normalize-RegKind $Type
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $kind -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-WARN "Falha ao escrever ${Path}\${Name} - $_"
        return $false
    }
}
