#Requires -Version 5.1
# Lightweight scope gate before ACT. Exit 0 = ok, 2 = not ready, 1 = usage/error.
# Usage:
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case
#   powershell -File skills/scripts/case-guard.ps1 -CaseRoot work\my-case -Force   # warn but exit 0
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [switch] $Force,
    [switch] $Quiet
)
$ErrorActionPreference = 'Stop'

function Write-Info([string] $m) {
    if (-not $Quiet) { Write-Host $m }
}

if (-not (Test-Path -LiteralPath $CaseRoot)) {
    Write-Host ("ERROR: CaseRoot missing: {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scopePath = Join-Path $CaseRoot 'scope.md'
if (-not (Test-Path -LiteralPath $scopePath)) {
    Write-Host ("ERROR: scope.md missing under {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8
$issues = New-Object System.Collections.Generic.List[string]

# auth.status
$authGranted = $false
if ($scope -match '(?m)^\s*-\s*status:\s*granted\s*$') { $authGranted = $true }
elseif ($scope -match '(?m)^\s*status:\s*granted\s*$') { $authGranted = $true }
if (-not $authGranted) { [void]$issues.Add('auth.status is not granted') }

# network_profile.mode
$netMode = $null
if ($scope -match '(?m)^\s*-\s*mode:\s*(\S+)\s*$') { $netMode = $Matches[1].Trim() }
if ([string]::IsNullOrWhiteSpace($netMode)) {
    [void]$issues.Add('network_profile.mode missing')
} elseif ($netMode -eq 'offline') {
    # offline is only OK if sample path mentioned in assets/notes — soft note
    if ($scope -notmatch 'sample|offline.?path|本地.?样本|\.apk\b|\.bin\b|\.exe\b') {
        [void]$issues.Add('network_profile.mode is offline without offline sample cue')
    }
}

# in_scope assets: only list items under "- assets:" inside ## in_scope
# Do NOT treat "- assets:" itself, ops_refs, or evidence_of_auth URLs as assets.
$hasAsset = $false
$inScopeSection = $null
if ($scope -match '(?ms)##\s*in_scope\s*(.*?)(?=\r?\n##\s|\z)') {
    $inScopeSection = $Matches[1]
}
if ($inScopeSection -and $inScopeSection -match '(?ms)-\s*assets:\s*\r?\n(?<body>(?:\s+.+\r?\n?|\s+\r?\n?)*)') {
    $assetBody = $Matches['body']
    # Require indented list entries: "  - value" where value is not empty [] marker
    if ($assetBody -match '(?m)^\s+-\s+(?!\[\s*\])\S+') {
        $hasAsset = $true
    }
}
if (-not $hasAsset -and $netMode -ne 'offline') {
    [void]$issues.Add('in_scope.assets appears empty')
}

# ready_for_act
$ready = $false
if ($scope -match '(?m)^\s*-\s*ready_for_act:\s*true\s*$') { $ready = $true }
if (-not $ready) { [void]$issues.Add('ready_for_act is not true') }

if ($issues.Count -eq 0) {
    Write-Info ("CASE-GUARD OK: {0}" -f $CaseRoot)
    exit 0
}

Write-Host ("CASE-GUARD NOT READY: {0}" -f $CaseRoot) -ForegroundColor Yellow
foreach ($i in $issues) { Write-Host (" - {0}" -f $i) -ForegroundColor Yellow }

if ($Force) {
    Write-Host 'CASE-GUARD: -Force set; continuing with warnings only.' -ForegroundColor Yellow
    exit 0
}

Write-Host 'Fix scope (or re-run case-init -AuthGranted -TargetUrl ...) or pass -Force.' -ForegroundColor Yellow
exit 2
