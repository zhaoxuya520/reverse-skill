#Requires -Version 5.1
param([string] $WorkflowPath = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($WorkflowPath)) {
    $WorkflowPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.github\workflows\auto-merge-journal.yml'
}
$text = Get-Content -LiteralPath $WorkflowPath -Raw -Encoding UTF8
$fail = New-Object System.Collections.Generic.List[string]
function Check([bool] $Condition, [string] $Message) {
    if ($Condition) { Write-Host "[OK] $Message" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Message" -ForegroundColor Red; [void]$fail.Add($Message) }
}

Check ($text -match '(?m)^\s{2}validate:\s*$') 'validate job exists'
Check ($text -match '(?m)^\s{2}merge:\s*$') 'merge job exists'
Check ($text -match '(?ms)validate:.*?contents:\s*read') 'validate has contents read'
Check ($text -match '(?ms)validate:.*?pull-requests:\s*read') 'validate has pull-request read'
Check ($text -match '(?ms)merge:.*?contents:\s*write') 'merge has contents write'
Check ($text -match '(?ms)merge:.*?pull-requests:\s*write') 'merge has pull-request write'
Check ($text -notmatch 'actions/checkout') 'workflow does not checkout untrusted PR code'
Check ($text -match '(?m)^\s+PR_TITLE:\s*\$\{\{') 'PR title is passed through environment'
Check ($text -match '(?m)^\s+PR_SUBJECT:\s*\$\{\{') 'PR subject is passed through environment'
Check ($text -match 'gh pr merge "\$PR_NUMBER".*--subject "\$PR_SUBJECT"') 'merge command quotes environment arguments'
Check ($text -notmatch '(?m)^\s+--subject .*github\.event\.pull_request\.title') 'no direct title interpolation in shell command'
Check ($text -match 'import ipaddress') 'workflow validates IP ranges with ipaddress'
Check ($text -notmatch 'ip\.startswith\(.*"172\.2"') 'workflow has no broad 172.2 prefix allowance'
Check ($text -match '(?m)^\s+python - <<''PY''\s*$') 'validation runs fixed inline Python from bash'

$marker = Join-Path $env:TEMP ('workflow-title-' + [guid]::NewGuid().ToString('n') + '.txt')
try {
    $env:PR_TITLE = '$(Write-Host injected) `n"quoted"; Get-ChildItem > should-not-run'
    $env:PR_SUBJECT = '[field-journal] ' + $env:PR_TITLE
    $captured = $env:PR_SUBJECT
    [System.IO.File]::WriteAllText($marker, $captured, (New-Object System.Text.UTF8Encoding $false))
    Check ((Get-Content -Raw -LiteralPath $marker) -eq $env:PR_SUBJECT) 'shell metacharacters remain data'
} finally {
    Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    Remove-Item Env:PR_TITLE -ErrorAction SilentlyContinue
    Remove-Item Env:PR_SUBJECT -ErrorAction SilentlyContinue
}

if ($fail.Count -gt 0) { exit 1 }
Write-Host 'WORKFLOW SECURITY CHECKS PASSED' -ForegroundColor Green
exit 0
