#Requires -Version 5.1
param([string] $WorkflowPath = '')
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($WorkflowPath)) {
    $WorkflowPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.github\workflows\auto-merge-journal.yml'
}

$text = Get-Content -LiteralPath $WorkflowPath -Raw -Encoding UTF8
$failures = New-Object System.Collections.Generic.List[string]

function Check([bool] $Condition, [string] $Message) {
    if ($Condition) { Write-Host "[OK] $Message" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Message" -ForegroundColor Red; [void]$failures.Add($Message) }
}

Check ($text -match '(?m)^\s+PR_NUMBER:\s*\$\{\{\s*github\.event\.pull_request\.number\s*\}\}') 'PR number is passed through the environment'
Check ($text -match '(?m)^\s+PR_SUBJECT:\s*\$\{\{\s*format\(') 'PR subject is constructed as environment data'
Check ($text -match '(?ms)gh pr merge "\$PR_NUMBER".*--subject "\$PR_SUBJECT"') 'merge command quotes the PR number and subject'
Check ($text -notmatch '(?m)--subject[^\r\n]*github\.event\.pull_request\.title') 'PR title is not interpolated into shell source'
Check ($text -notmatch '(?m)gh pr (?:diff|merge|comment)\s+\$\{\{') 'GitHub CLI commands do not embed event expressions'

$maliciousTitle = '$(Write-Host injected) `' + [Environment]::NewLine + '"quoted"; Get-ChildItem > should-not-run'
$subject = '[field-journal] ' + $maliciousTitle
Check ($subject -eq ('[field-journal] ' + $maliciousTitle)) 'shell metacharacters remain plain subject data'

if ($failures.Count -gt 0) { exit 1 }
Write-Host 'WORKFLOW TITLE SAFETY CHECKS PASSED' -ForegroundColor Green
exit 0
