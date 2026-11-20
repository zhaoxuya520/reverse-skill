#requires -Version 5

[CmdletBinding()]
param(
    [string]$Package,

    [string]$Process,

    [string]$RemoteHost = '127.0.0.1:27042',

    [string]$ScriptPath,

    [switch]$Usb,

    [switch]$Spawn,

    [switch]$Pause,

    [switch]$ListDevices,

    [switch]$ListProcesses
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Get-PythonScriptCandidates {
    param([Parameter(Mandatory = $true)][string]$ExecutableName)

    $roots = @(
        (Join-Path $env:APPDATA 'Python'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python')
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $matches = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $matches) {
            $candidate = Join-Path $dir.FullName (Join-Path 'Scripts' $ExecutableName)
            if (Test-Path -LiteralPath $candidate) {
                $candidates.Add($candidate)
            }
        }
    }

    return $candidates
}

function Get-ToolPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    foreach ($candidate in Get-PythonScriptCandidates -ExecutableName ($Name + '.exe')) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    # Attempt auto-bootstrap for frida tools
    $bootstrapScript = Join-Path $PSScriptRoot '..\..\scripts\bootstrap-reverse.ps1'
    if (($Name -in @('frida', 'frida-ps', 'frida-ls-devices')) -and (Test-Path -LiteralPath $bootstrapScript)) {
        Write-Host "INFO: $Name not found, attempting auto-bootstrap (pip install frida-tools)..." -ForegroundColor Yellow
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript -Capability @('frida') -SkipRefresh
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-Host "INFO: $Name bootstrapped successfully." -ForegroundColor Green
            return $cmd.Source
        }
        foreach ($candidate in Get-PythonScriptCandidates -ExecutableName ($Name + '.exe')) {
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    throw "Missing required CLI tool: $Name — install with: pip install frida-tools"
}

$fridaLsDevices = Get-ToolPath -Name 'frida-ls-devices'
$fridaPs = Get-ToolPath -Name 'frida-ps'
$frida = Get-ToolPath -Name 'frida'
$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    throw 'Missing required CLI tool: python'
}

$pythonExe = $python.Source

if ($ListDevices) {
    & $pythonExe -c "import frida; [print(f'{d.id}`t{d.type}`t{d.name}') for d in frida.enumerate_devices()]"
    exit $LASTEXITCODE
}

$target = if ($Package) { $Package } elseif ($Process) { $Process } else { '' }
if ([string]::IsNullOrWhiteSpace($target) -and -not $ListProcesses) {
    throw 'Provide -Package or -Process, or use -ListProcesses.'
}

$deviceFlag = if ($Usb) { '-U' } else { '-H' }

if ($ListProcesses) {
    $processArgs = @()
    if ($Usb) {
        $processArgs += '-U'
    }
    else {
        $processArgs += @('-H', $RemoteHost)
    }
    & $fridaPs @processArgs
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Frida script not found: $ScriptPath"
}

$fridaArgs = @($deviceFlag)
if (-not $Usb) {
    $fridaArgs += $RemoteHost
}
if ($Spawn) {
    $fridaArgs += '-f'
} else {
    $fridaArgs += '-n'
}
$fridaArgs += $target
$fridaArgs += '-l'
$fridaArgs += $ScriptPath
if ($Pause) {
    $fridaArgs += '--pause'
}

& $frida @fridaArgs
exit $LASTEXITCODE
