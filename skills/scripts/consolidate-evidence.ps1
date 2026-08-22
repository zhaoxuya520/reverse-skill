#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $CaseRoot,
    [Parameter(Mandatory = $true)][string] $EvidenceIds,
    [Parameter(Mandatory = $true)][string] $FindingId,
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Description,
    [string] $Severity = 'medium',
    [string] $Status = 'validated'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -Path $CaseRoot)) { Write-Error "CaseRoot not found: $CaseRoot" }

$evidenceDir = Join-Path $CaseRoot "evidence"
$reportDir = Join-Path $CaseRoot "report"

if (-not (Test-Path -Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

$idList = $EvidenceIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
if ($idList.Count -eq 0) { Write-Error "No Evidence IDs provided." }

foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    if (-not (Test-Path -Path $evidenceFile)) { Write-Error "Evidence file not found: $evidenceFile" }
}

foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    $content = Get-Content -Path $evidenceFile -Raw
    if ($content -match "(?m)^-\s*status:\s*.*$") {
        $content = $content -replace "(?m)^-\s*status:\s*.*$", "- status: superseded by $FindingId"
    } else {
        $content = $content -replace "(?m)^---$", "---`n- status: superseded by $FindingId"
    }
    Set-Content -Path $evidenceFile -Value $content -NoNewline
}

$reportFile = Join-Path $reportDir "report.md"
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$findingBlock = @"
### $FindingId
- title: $Title
- severity: $Severity
- status: $Status
- evidence_refs: $($idList -join ', ')
- consolidated_at: $timestamp

$Description

"@

if (Test-Path -Path $reportFile) {
    $reportContent = Get-Content -Path $reportFile -Raw
    if ($reportContent -notmatch "(?m)^## Findings") { Add-Content -Path $reportFile -Value "`n## Findings`n" }
    Add-Content -Path $reportFile -Value $findingBlock
} else {
    $initialReport = @"
# Case Report

## Findings

$findingBlock
"@
    Set-Content -Path $reportFile -Value $initialReport
}
