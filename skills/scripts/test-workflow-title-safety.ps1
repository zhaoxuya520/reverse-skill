#Requires -Version 5.1
param([string] $WorkflowPath = '')

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($WorkflowPath)) {
    $WorkflowPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.github\workflows\auto-merge-journal.yml'
}

$text = Get-Content -LiteralPath $WorkflowPath -Raw -Encoding UTF8
$failures = New-Object System.Collections.Generic.List[string]

function Check([bool] $Condition, [string] $Message) {
    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        [void]$failures.Add($Message)
    }
}

Check ($text -match '(?m)^\s+PR_NUMBER:\s*\$\{\{\s*github\.event\.pull_request\.number\s*\}\}') 'PR number is passed through the environment'
Check ($text -match '(?m)^\s+PR_TITLE:\s*\$\{\{\s*github\.event\.pull_request\.title\s*\}\}') 'PR title is passed through the environment'
Check ($text -match '(?m)^\s+PR_SUBJECT:\s*\$\{\{\s*format\(') 'PR subject is constructed as environment data'
Check ($text -match '(?ms)gh pr merge "\$PR_NUMBER".*--subject "\$PR_SUBJECT"') 'merge command quotes the PR number and subject'
Check ($text -notmatch '(?m)--subject[^\r\n]*github\.event\.pull_request\.title') 'PR title is not interpolated into the merge command'
Check ($text -notmatch '(?m)gh pr (?:diff|merge|comment)\s+\$\{\{') 'GitHub CLI commands do not embed event expressions'
# 'field-journal' contains the letters 'fi', so do not slice the INVALID_FILES
# branch with a non-greedy .*?fi regex.
Check ($text -match '(?s)if \[ -n "\$INVALID_FILES" \]; then.*?echo "SKIP: not a field-journal-only PR; auto-merge does not apply".*?echo "valid=skip" >> \$GITHUB_OUTPUT\s+exit 0') 'mixed (non-journal) PRs skip auto-merge with valid=skip'
Check ($text -match '(?s)if \[ -n "\$INVALID_FILES" \]; then.*?exit 0\s+fi') 'mixed PRs exit 0 so the job stays green'
Check ($text -notmatch '(?s)if \[ -n "\$INVALID_FILES" \]; then.{0,400}exit 1') 'mixed PRs must not fail the job with exit 1'
Check ($text -match "steps\.validate\.outputs\.valid == 'true'") 'auto-merge still requires valid=true'
Check ($text -match "failure\(\).*steps\.validate\.outputs\.valid == 'false'") 'failure comment runs only on journal safety failures'

$maliciousTitle = '$(Write-Host injected) `' + [Environment]::NewLine + '"quoted"; Get-ChildItem > should-not-run'
$subject = '[field-journal] ' + $maliciousTitle
Check ($subject -eq ('[field-journal] ' + $maliciousTitle)) 'shell metacharacters remain plain subject data'

if ($failures.Count -gt 0) {
    exit 1
}

Write-Host 'WORKFLOW TITLE SAFETY CHECKS PASSED' -ForegroundColor Green
exit 0
