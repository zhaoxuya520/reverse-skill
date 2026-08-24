#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = (Resolve-Path (Join-Path $here "..\..")).Path
$scratch = Join-Path $env:TEMP ("rs-consol-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $scratch "evidence") | Out-Null
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-001.md") (Join-Path $scratch "evidence\E-001.md")
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-002.md") (Join-Path $scratch "evidence\E-002.md")

function Assert-FindingFields([string]$report) {
    foreach ($f in @("confidence:","location:","evidence_ids:","status:")) {
        if ($report -notmatch [regex]::Escape($f)) { throw "missing field $f" }
    }
    if ($report -match "evidence_refs:") { throw "legacy evidence_refs leaked" }
}

# Python path
python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $scratch --evidence-ids "E-001,E-002" --finding-id F-CONSOL-1 --title "triage merge" --description "merged two triage notes" --severity info --status validated --confidence medium --location "see E-001 E-002" | Out-Null
$r1 = Get-Content (Join-Path $scratch "report\report.md") -Raw
Assert-FindingFields $r1
$e1 = Get-Content (Join-Path $scratch "evidence\E-001.md") -Raw
if ($e1 -notmatch "superseded by F-CONSOL-1") { throw "py did not mark superseded" }

# reset for ps1
Remove-Item (Join-Path $scratch "report") -Recurse -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-001.md") (Join-Path $scratch "evidence\E-001.md") -Force
Copy-Item (Join-Path $root "examples\ctf-demo\evidence\E-002.md") (Join-Path $scratch "evidence\E-002.md") -Force
& (Join-Path $root "skills\scripts\consolidate-evidence.ps1") -CaseRoot $scratch -EvidenceIds "E-001,E-002" -FindingId F-CONSOL-2 -Title "triage merge ps1" -Description "merged two triage notes" -Severity info -Status validated -Confidence medium -Location "see E-001 E-002"
$r2 = Get-Content (Join-Path $scratch "report\report.md") -Raw
Assert-FindingFields $r2
$e2 = Get-Content (Join-Path $scratch "evidence\E-001.md") -Raw
if ($e2 -notmatch "superseded by F-CONSOL-2") { throw "ps1 did not mark superseded" }

# review_case accepts superseded
$demo = Join-Path $scratch "ctf"
Copy-Item (Join-Path $root "examples\ctf-demo") $demo -Recurse
python (Join-Path $root "skills\scripts\consolidate_evidence.py") --case-root $demo --evidence-ids "E-001" --finding-id F-001 --title "keep contract" --description "ok" --severity info --status validated --confidence medium --location "E-001" | Out-Null
# F-001 already exists in ctf-demo report; just check parse of superseded evidence
python (Join-Path $root "skills\case-review\scripts\review_case.py") $demo --verify-hashes 2>&1 | Select-Object -Last 8
Write-Host "CONSOLIDATE_ALIGN_OK"
Remove-Item $scratch -Recurse -Force