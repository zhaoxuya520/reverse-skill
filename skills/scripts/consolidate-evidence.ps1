#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $CaseRoot,
    [Parameter(Mandatory = $true)][string] $EvidenceIds,
    [Parameter(Mandatory = $true)][string] $FindingId,
    [Parameter(Mandatory = $true)][string] $Title,
    [Parameter(Mandatory = $true)][string] $Description,
    [string] $Severity = 'medium',
    [string] $Status = 'validated',
    [string] $Confidence = 'medium',
    [string] $Location = 'see evidence_ids'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CaseRoot)) { Write-Error "CaseRoot not found: $CaseRoot" }

$evidenceDir = Join-Path $CaseRoot "evidence"
$reportDir = Join-Path $CaseRoot "report"

$idList = @($EvidenceIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Select-Object -Unique)
if ($idList.Count -eq 0) { Write-Error "No Evidence IDs provided." }
if ($FindingId -cnotmatch '\AF-[A-Za-z0-9][A-Za-z0-9_-]*\z') { Write-Error "Expected a plain F-... record ID." }
foreach ($id in $idList) {
    if ($id -cnotmatch '\AE-[A-Za-z0-9][A-Za-z0-9_-]*\z') { Write-Error "Expected plain E-... record IDs." }
}
if ((Get-Item -LiteralPath $evidenceDir).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Write-Error "Evidence directory must be case-local, not a link."
}

$contents = @{}
foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    if (-not (Test-Path -LiteralPath $evidenceFile -PathType Leaf)) { Write-Error "Evidence file not found: $evidenceFile" }
    if ((Get-Item -LiteralPath $evidenceFile).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Error "Evidence must be a regular file, not a link: $evidenceFile"
    }
    $contents[$id] = Get-Content -LiteralPath $evidenceFile -Raw -Encoding UTF8
}

$heading = '(?m)^###\s+' + [regex]::Escape($FindingId) + '(?=\s|$)'
if (Test-Path -LiteralPath $reportDir) {
    foreach ($report in @(Get-ChildItem -LiteralPath $reportDir -Filter '*.md' -File -Recurse)) {
        if ((Get-Content -LiteralPath $report.FullName -Raw -Encoding UTF8) -cmatch $heading) {
            Write-Error "Finding already exists: $FindingId in $($report.FullName)"
        }
    }
}

if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    $content = $contents[$id]
    if ($content -match "(?m)^-\s*status:\s*.*$") {
        $content = [regex]::Replace($content, "(?m)^-\s*status:\s*.*$", "- status: superseded by $FindingId")
    } elseif ($content -match "(?m)^---\s*$") {
        $content = [regex]::Replace($content, "(?m)^---\s*$", "---`r`n- status: superseded by $FindingId", 1)
    } else {
        $content = $content.TrimEnd() + "`r`n- status: superseded by $FindingId`r`n"
    }
    Set-Content -LiteralPath $evidenceFile -Value $content -Encoding UTF8 -NoNewline
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$joined = ($idList -join ', ')
$findingBlock = @"
### $FindingId
- title: $Title
- severity: $Severity
- status: $Status
- confidence: $Confidence
- location: $Location
- evidence_ids: $joined
- consolidated_at: $timestamp

$Description
"@

$reportFile = Join-Path $reportDir "report.md"
if (Test-Path -LiteralPath $reportFile) {
    $reportContent = Get-Content -LiteralPath $reportFile -Raw -Encoding UTF8
    if ($reportContent -notmatch "(?m)^## Findings") {
        $reportContent = $reportContent.TrimEnd() + "`r`n`r`n## Findings`r`n"
    }
    Set-Content -LiteralPath $reportFile -Value ($reportContent.TrimEnd() + "`r`n`r`n" + $findingBlock + "`r`n") -Encoding UTF8 -NoNewline
} else {
    $initialReport = @"
# Case Report

## Findings

$findingBlock
"@
    Set-Content -LiteralPath $reportFile -Value $initialReport -Encoding UTF8
}
