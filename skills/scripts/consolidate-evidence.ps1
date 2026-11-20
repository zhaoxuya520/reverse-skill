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

function ConvertFrom-ConsolidationBytes([byte[]]$Data) {
    $text = [Text.Encoding]::UTF8.GetString($Data)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { return $text.Substring(1) }
    return $text
}

function ConvertTo-ConsolidationBytes([string]$Content, [byte[]]$Original) {
    $data = [Text.Encoding]::UTF8.GetBytes($Content)
    if ($null -eq $Original -or ($Original.Length -ge 3 -and $Original[0] -eq 239 -and $Original[1] -eq 187 -and $Original[2] -eq 191)) {
        return ,([byte[]]@(239, 187, 191) + $data)
    }
    return ,$data
}

function New-ConsolidationTemporaryFile([string]$Path, [byte[]]$Data, [Collections.Generic.List[string]]$Temporary) {
    $name = Join-Path ([IO.Path]::GetDirectoryName($Path)) ('.' + [IO.Path]::GetFileName($Path) + '.consolidate-' + [guid]::NewGuid().ToString('N'))
    $stream = [IO.File]::Open($name, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $stream.Dispose()
    $Temporary.Add($name)
    # Keep the original permissions before writing the replacement. File.Replace
    # also preserves the Windows destination's ACL when publishing it.
    if ([IO.File]::Exists($Path)) {
        if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
            # Set the DACL on the empty file, before copying any case content.
            $access = [Security.AccessControl.AccessControlSections]::Access
            $acl = [Security.AccessControl.FileSecurity]::new()
            $acl.SetSecurityDescriptorSddlForm((Get-Acl -LiteralPath $Path).GetSecurityDescriptorSddlForm($access), $access)
            Set-Acl -LiteralPath $name -AclObject $acl
            if ([IO.File]::GetAttributes($Path) -band [IO.FileAttributes]::ReadOnly) {
                [IO.File]::SetAttributes($name, [IO.FileAttributes]::ReadOnly)
            }
        } else {
            $originalOwner = (Get-Item -LiteralPath $Path -Force).UnixStat
            $stagedOwner = (Get-Item -LiteralPath $name -Force).UnixStat
            if ($null -eq $originalOwner -or $null -eq $stagedOwner -or
                $originalOwner.UserId -ne $stagedOwner.UserId -or $originalOwner.GroupId -ne $stagedOwner.GroupId) {
                throw [IO.IOException]::new("Cannot safely preserve file ownership while staging $Path")
            }
            [IO.File]::Copy($Path, $name, $true)
        }
    }
    [IO.File]::WriteAllBytes($name, $Data)
    return $name
}

function Replace-ConsolidationRecord([string]$Source, [string]$Destination, [string]$Backup) {
    if ([IO.File]::Exists($Destination)) {
        if ($Backup) {
            [IO.File]::Replace($Source, $Destination, $Backup)
        } else {
            [IO.File]::Replace($Source, $Destination, [NullString]::Value)
        }
    } else {
        [IO.File]::Move($Source, $Destination)
    }
}

function Keep-ConsolidationBackup([string]$Backup, [Collections.Generic.List[string]]$Retained) {
    if (-not $Backup) { return '' }
    $Retained.Add($Backup)
    if ([IO.File]::Exists($Backup)) { return "; original bytes retained at $Backup" }
    return "; backup unavailable at $Backup, inspect the destination before retrying"
}

function Publish-Consolidation([object[]]$Records) {
    # This recovers caught write failures, not concurrent writers or process loss.
    $temporary = [Collections.Generic.List[string]]::new()
    $retained = [Collections.Generic.List[string]]::new()
    $prepared = [Collections.Generic.List[object]]::new()
    $attempted = [Collections.Generic.List[object]]::new()
    $publicationHandled = $false
    try {
        foreach ($record in $Records) {
            $pending = New-ConsolidationTemporaryFile $record.Path $record.Data $temporary
            $backup = $null
            if ($null -ne $record.Original) {
                $backup = New-ConsolidationTemporaryFile $record.Path $record.Original $temporary
            }
            $prepared.Add([pscustomobject]@{ Path = $record.Path; Pending = $pending; Backup = $backup })
        }
        try {
            foreach ($record in $prepared) {
                # Include the attempted destination if a native metadata error
                # occurs after replacement, so it is also recovered.
                $attempted.Add($record)
                Replace-ConsolidationRecord $record.Pending $record.Path $record.Backup
            }
            $publicationHandled = $true
        } catch {
            $failure = $_
            $recoveryErrors = [Collections.Generic.List[string]]::new()
            for ($i = $attempted.Count - 1; $i -ge 0; $i--) {
                $record = $attempted[$i]
                if ($record.Path -eq $Records[0].Path -and $recoveryErrors.Count -gt 0) {
                    $message = "Kept Finding in $($record.Path); restore Evidence before restoring the report"
                    $message += Keep-ConsolidationBackup $record.Backup $retained
                    $recoveryErrors.Add($message)
                    continue
                }
                try {
                    if ($null -eq $record.Backup) {
                        [IO.File]::Delete($record.Path)
                    } else {
                        Replace-ConsolidationRecord $record.Backup $record.Path
                    }
                } catch {
                    $message = "Could not restore $($record.Path)"
                    $message += Keep-ConsolidationBackup $record.Backup $retained
                    $recoveryErrors.Add($message + ': ' + $_.Exception.Message)
                }
            }
            $detail = 'Original records restored.'
            if ($recoveryErrors.Count -gt 0) { $detail = $recoveryErrors -join '; ' }
            $publicationHandled = $true
            throw "Consolidation failed: $($failure.Exception.Message). $detail"
        }
    } finally {
        if ($attempted.Count -gt 0 -and -not $publicationHandled) {
            foreach ($record in $attempted) {
                $message = Keep-ConsolidationBackup $record.Backup $retained
                Write-Warning ("Publication interrupted for $($record.Path)" + $message)
            }
        }
        foreach ($name in $temporary) {
            if (-not $retained.Contains($name)) {
                try { [IO.File]::Delete($name) }
                catch { Write-Warning "Could not remove temporary file ${name}: $($_.Exception.Message)" }
            }
        }
    }
}

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CaseRoot)) { Write-Error "CaseRoot not found: $CaseRoot" }
$CaseRoot = (Resolve-Path -LiteralPath $CaseRoot).ProviderPath

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
$originals = @{}
foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    if (-not (Test-Path -LiteralPath $evidenceFile -PathType Leaf)) { Write-Error "Evidence file not found: $evidenceFile" }
    if ((Get-Item -LiteralPath $evidenceFile).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Error "Evidence must be a regular file, not a link: $evidenceFile"
    }
    $originals[$id] = [IO.File]::ReadAllBytes($evidenceFile)
    $contents[$id] = ConvertFrom-ConsolidationBytes $originals[$id]
}

$heading = '(?m)^###\s+' + [regex]::Escape($FindingId) + '(?=\s|$)'
if (Test-Path -LiteralPath $reportDir) {
    foreach ($report in @(Get-ChildItem -LiteralPath $reportDir -Filter '*.md' -File -Recurse)) {
        if ((Get-Content -LiteralPath $report.FullName -Raw -Encoding UTF8) -cmatch $heading) {
            Write-Error "Finding already exists: $FindingId in $($report.FullName)"
        }
    }
}

$evidenceRecords = @()
foreach ($id in $idList) {
    $evidenceFile = Join-Path $evidenceDir "$id.md"
    $content = $contents[$id]
    $newline = "`n"
    if ($content.Contains("`r`n")) { $newline = "`r`n" }
    if ($content -match "(?m)^-[ \t]*status:[^\r\n]*") {
        $content = [regex]::Replace($content, "(?m)^-[ \t]*status:[^\r\n]*", "- status: superseded by $FindingId")
    } elseif ($content -match "(?m)^---[ \t]*(?=\r?$)") {
        $content = [regex]::Replace($content, "(?m)^---[ \t]*(?=\r?$)", "---${newline}- status: superseded by $FindingId", 1)
    } else {
        $content = $content.TrimEnd() + "${newline}- status: superseded by $FindingId${newline}"
    }
    $evidenceRecords += [pscustomobject]@{
        Path = $evidenceFile; Data = (ConvertTo-ConsolidationBytes $content $originals[$id]); Original = $originals[$id]
    }
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
$reportOriginal = $null
$newline = "`r`n"
if (Test-Path -LiteralPath $reportFile) {
    $reportOriginal = [IO.File]::ReadAllBytes($reportFile)
    $reportContent = ConvertFrom-ConsolidationBytes $reportOriginal
    if (-not $reportContent.Contains("`r`n")) { $newline = "`n" }
    if ($reportContent -notmatch "(?m)^## Findings") {
        $reportContent = $reportContent.TrimEnd() + $newline + $newline + "## Findings${newline}"
    }
    $reportContent = $reportContent.TrimEnd() + $newline + $newline + ($findingBlock -replace "`r?`n", $newline) + $newline
} else {
    $reportContent = "# Case Report${newline}${newline}## Findings${newline}${newline}" + ($findingBlock -replace "`r?`n", $newline) + $newline
}
$reportRecord = [pscustomobject]@{
    Path = $reportFile; Data = (ConvertTo-ConsolidationBytes $reportContent $reportOriginal); Original = $reportOriginal
}
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
Publish-Consolidation (@($reportRecord) + $evidenceRecords)
