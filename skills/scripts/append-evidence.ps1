#Requires -Version 5.1
# Append one Evidence item under work/<case>/evidence/ (ops Evidence contract).
#
# Usage (simple):
#   powershell -File skills/scripts/append-evidence.ps1 -CaseRoot work\my-case `
#     -Id E-001 -Title "Open clock API" -ReproCommand 'curl -sI https://example/' `
#     -Severity info -Status observed
#
# Special characters / spaces / quotes in excerpts (recommended for nested -File):
#   Set-Content excerpt.txt -Value '"XML parsing error" / Entities are not allowed'
#   powershell -File skills/scripts/append-evidence.ps1 ... -RawExcerptFile excerpt.txt
#
# NOTE: Nested `powershell -File` splits unquoted multi-word values. Prefer -RawExcerptFile
# or call the script in-process: & .\append-evidence.ps1 -RawExcerpt 'full text here'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $CaseRoot,

    [Parameter(Mandatory = $true)]
    [string] $Id,

    [Parameter(Mandatory = $true)]
    [string] $Title,

    [Parameter(Mandatory = $true)]
    [string] $ReproCommand,

    [string] $Severity = 'info',
    [string] $Status = 'observed',
    [string] $SourceType = 'command',
    [string] $RawExcerpt = '',
    [string] $RawExcerptFile = '',
    [string] $Location = '',
    [string] $Notes = '',
    [string] $NotesFile = '',
    [string] $ReproCommandFile = ''
)
$ErrorActionPreference = 'Stop'

# Advanced functions reject unknown positionals at bind time; keep explicit check for edge hosts.
if ($args -and $args.Count -gt 0) {
    $extra = ($args | ForEach-Object { [string]$_ }) -join ' | '
    throw ("Unexpected arguments (likely -RawExcerpt/-Title quoting broke multi-word value): {0}. Use -RawExcerptFile for special characters, or pass a single quoted string." -f $extra)
}

$allowedSeverity = @('critical', 'high', 'medium', 'low', 'info', 'n/a', 'n/a_re')
$allowedStatus = @('observed', 'candidate', 'validated', 'false_positive', 'accepted_risk')

function ConvertTo-YamlBlock([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return '    n/a' }
    $clean = ($text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    $lines = $clean -split "`r?`n", -1
    if ($lines.Count -eq 0) { return '    n/a' }
    return (($lines | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine)
}

function ConvertTo-SingleLine([string] $text) {
    if ([string]::IsNullOrEmpty($text)) { return 'n/a' }
    $t = ($text -replace '[\x00-\x1F]', ' ')
    $t = $t -replace '\s+', ' '
    return $t.Trim()
}

function Read-OptionalFile([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path"
    }
    return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $path), [System.Text.Encoding]::UTF8)
}

if (-not (Test-Path -LiteralPath $CaseRoot)) {
    throw "CaseRoot does not exist: $CaseRoot"
}

# File overrides beat inline strings (safe path for special characters under powershell -File)
$fromReproFile = Read-OptionalFile $ReproCommandFile
if ($null -ne $fromReproFile) { $ReproCommand = $fromReproFile }

$fromExcerptFile = Read-OptionalFile $RawExcerptFile
if ($null -ne $fromExcerptFile) { $RawExcerpt = $fromExcerptFile }

$fromNotesFile = Read-OptionalFile $NotesFile
if ($null -ne $fromNotesFile) { $Notes = $fromNotesFile }

$evDir = Join-Path $CaseRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evDir | Out-Null

$idSafe = ($Id -replace '[^\w\-]+', '-').Trim('-')
if ($idSafe -notmatch '^E-') { $idSafe = 'E-' + $idSafe }
$fileName = $idSafe + '.md'
$path = Join-Path $evDir $fileName

$observed = Get-Date -Format 'o'
$titleLine = ConvertTo-SingleLine $Title
$sev = (ConvertTo-SingleLine $Severity).ToLowerInvariant()
if ($allowedSeverity -notcontains $sev) {
    throw ("Invalid -Severity '{0}' (allowed: {1})" -f $Severity, ($allowedSeverity -join ', '))
}
$st = (ConvertTo-SingleLine $Status).ToLowerInvariant()
if ($allowedStatus -notcontains $st) {
    throw ("Invalid -Status '{0}' (allowed: {1})" -f $Status, ($allowedStatus -join ', '))
}
$src = ConvertTo-SingleLine $SourceType
$loc = ConvertTo-SingleLine $(if ($Location) { $Location } else { 'n/a' })
if ([string]::IsNullOrWhiteSpace($ReproCommand)) {
    throw '-ReproCommand (or -ReproCommandFile) is required and must be non-empty'
}
$reproBlock = ConvertTo-YamlBlock $ReproCommand
$excerptBlock = ConvertTo-YamlBlock $(if ($RawExcerpt) { $RawExcerpt } else { 'n/a' })
$notesBlock = ConvertTo-YamlBlock $(if ($Notes) { $Notes } else { 'n/a' })

$body = @"
### $idSafe
- title: $titleLine
- observed_at: $observed
- source_type: $src
- source_ref: append-evidence.ps1
- content_hash: n/a
- severity: $sev
- status: $st
- location: $loc
- repro_command: |
$reproBlock
- raw_excerpt: |
$excerptBlock
- linked_workitem: n/a
- supersedes: none
- notes: |
$notesBlock
"@

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $body, $utf8)

$index = Join-Path $evDir 'INDEX.md'
$line = "- $idSafe | $sev | $st | $titleLine | $fileName"
if (-not (Test-Path -LiteralPath $index)) {
    $hdr = @"
# Evidence index

| id | severity | status | title | file |
|----|----------|--------|-------|------|

"@
    [System.IO.File]::WriteAllText($index, $hdr, $utf8)
}
Add-Content -Path $index -Value $line -Encoding UTF8

Write-Host ("EVIDENCE -> {0}" -f $path) -ForegroundColor Green
Write-Host ("ID: {0} | {1} | {2}" -f $idSafe, $sev, $st)
exit 0
