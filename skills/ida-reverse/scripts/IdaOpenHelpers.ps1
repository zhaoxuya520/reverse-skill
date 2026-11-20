# Shared IDA open lock policy. Never delete .i64/.idb.
function Get-IdaOpenLockPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BinaryPath
    )
    $dir = [System.IO.Path]::GetDirectoryName($BinaryPath)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($BinaryPath)
    $lockExts = @('.id0', '.id1', '.id2', '.nam', '.til')
    $dbExts = @('.i64', '.idb')
    $hasLocked = $false
    foreach ($ext in $lockExts) {
        $f = Join-Path $dir ($base + $ext)
        if (Test-Path -LiteralPath $f) { $hasLocked = $true }
    }
    $hasDatabase = $false
    foreach ($ext in $dbExts) {
        $f = Join-Path $dir ($base + $ext)
        if (Test-Path -LiteralPath $f) { $hasDatabase = $true }
    }
    return [pscustomobject]@{
        HasLocked            = $hasLocked
        HasDatabase          = $hasDatabase
        WouldDeleteDatabase  = $false
        PreferTempCopy       = $hasLocked
    }
}

function Get-IdaMcpKeepaliveDir {
    $dir = Join-Path $env:LOCALAPPDATA 'reverse-skill\ida-mcp'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-IdaMcpLastHealthyPath {
    param([int]$Port = 13337)
    return Join-Path (Get-IdaMcpKeepaliveDir) ("last-healthy-{0}.txt" -f $Port)
}

function Get-IdaMcpOpeningLockPath {
    param(
        [int]$Port = 13337,
        [guid]$LeaseId = [guid]::Empty
    )
    if ($LeaseId -ne [guid]::Empty) {
        return Join-Path (Get-IdaMcpKeepaliveDir) ("opening-{0}-{1}.lock" -f $Port, $LeaseId.ToString('N'))
    }
    # Keep recognizing the marker written by older open.ps1 processes.
    return Join-Path (Get-IdaMcpKeepaliveDir) ("opening-{0}.lock" -f $Port)
}

function Write-IdaMcpLastHealthy {
    param([int]$Port = 13337)
    Set-Content -LiteralPath (Get-IdaMcpLastHealthyPath -Port $Port) -Value 'ok' -Encoding ASCII
}

function Read-IdaMcpLastHealthy {
    param([int]$Port = 13337)
    $path = Get-IdaMcpLastHealthyPath -Port $Port
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return (Get-Item -LiteralPath $path).LastWriteTime
}

function Set-IdaMcpOpeningLock {
    param(
        [int]$Port = 13337,
        [int]$TtlSeconds = 600
    )
    $ttl = [Math]::Max(1, $TtlSeconds)
    $until = (Get-Date).AddSeconds($ttl).ToString('o')
    $leaseId = [guid]::NewGuid()
    $path = Get-IdaMcpOpeningLockPath -Port $Port -LeaseId $leaseId
    $pendingPath = $path + '.tmp'
    try {
        # Publish a complete, immutable marker: readers must not remove a
        # partially written deadline as corrupt while an open is starting.
        [IO.File]::WriteAllText($pendingPath, $until, [Text.Encoding]::ASCII)
        [IO.File]::Move($pendingPath, $path)
    } finally {
        Remove-Item -LiteralPath $pendingPath -Force -ErrorAction SilentlyContinue
    }
    return $leaseId
}

function Clear-IdaMcpOpeningLock {
    param(
        [int]$Port = 13337,
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -ne [guid]::Empty })]
        [guid]$LeaseId
    )
    $path = Get-IdaMcpOpeningLockPath -Port $Port -LeaseId $LeaseId
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}

function Test-IdaMcpOpeningInFlight {
    param(
        [int]$Port = 13337,
        [datetime]$Now = (Get-Date)
    )
    $legacyPath = Get-IdaMcpOpeningLockPath -Port $Port
    $paths = @($legacyPath) + @(Get-ChildItem -LiteralPath (Split-Path -Parent $legacyPath) `
        -Filter ("opening-{0}-*.lock" -f $Port) -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $active = $false
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $raw = (Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            continue
        }
        try {
            $until = [datetime]::Parse($raw.Trim(), $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
        } catch {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            continue
        }
        if ($Now -gt $until) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            continue
        }
        $active = $true
    }
    return $active
}

function Test-IdaMcpKeepaliveDeadlockFromFacts {
    param(
        [bool]$GuiOwnsPort = $false,
        [bool]$OpeningInFlight = $false,
        $LastHealthy = $null,
        [datetime]$Now = (Get-Date),
        [int]$MaxUnhealthySeconds = 180
    )
    if ($GuiOwnsPort) { return $false }
    if ($OpeningInFlight) { return $false }
    if ($null -eq $LastHealthy) { return $false }
    return ($Now - [datetime]$LastHealthy).TotalSeconds -ge $MaxUnhealthySeconds
}
