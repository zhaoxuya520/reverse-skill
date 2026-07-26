#Requires -Version 5.1
# Lightweight scope gate before ACT. Exit 0 = valid granted scope, 2 = blocked, 1 = usage/error.
# -Force is retained for caller compatibility but never bypasses the real gate.
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [switch] $Force,
    [switch] $Quiet
)
$ErrorActionPreference = 'Stop'

function Write-Info([string] $Message) {
    if (-not $Quiet) { Write-Host $Message }
}

if (-not (Test-Path -LiteralPath $CaseRoot -PathType Container)) {
    Write-Host ("ERROR: CaseRoot missing: {0}" -f $CaseRoot) -ForegroundColor Red
    exit 1
}

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$policyPath = Join-Path $scriptDir 'lib\ScopePolicy.ps1'
if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    Write-Host ("ERROR: scope policy module missing: {0}" -f $policyPath) -ForegroundColor Red
    exit 1
}
. $policyPath

$scopePath = Join-Path $CaseRoot 'scope.json'
$result = Import-ScopeDocument -Path $scopePath -RequireGranted
$issues = New-Object System.Collections.Generic.List[string]
foreach ($issue in @($result.Issues)) { [void]$issues.Add([string]$issue) }

if ($result.Valid) {
    $scope = $result.Scope
    $targets = @($scope.targets)
    if ($targets.Count -eq 0) { [void]$issues.Add('scope has no targets') }
    if (@($scope.allowedActions).Count -eq 0) { [void]$issues.Add('scope has no allowedActions') }
}

if ($issues.Count -eq 0) {
    Write-Info ("CASE-GUARD OK: {0} (scope.json)" -f $CaseRoot)
    exit 0
}

Write-Host ("CASE-GUARD BLOCKED: {0}" -f $CaseRoot) -ForegroundColor Yellow
foreach ($issue in $issues) { Write-Host (" - {0}" -f $issue) -ForegroundColor Yellow }
if ($Force) {
    Write-Host 'CASE-GUARD: -Force is diagnostic-only; authorization gate remains enforced.' -ForegroundColor Yellow
}
Write-Host 'Provide a valid, user-approved, unexpired scope.json; scope.md cannot grant authorization.' -ForegroundColor Yellow
exit 2
