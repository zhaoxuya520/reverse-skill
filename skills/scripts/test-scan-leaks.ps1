#Requires -Version 5.1
# Regression test for scan-leaks.ps1: one-line files must be scanned as a line,
# not character by character (Get-Content returns a [string] for one line).
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/test-scan-leaks.ps1
$ErrorActionPreference = 'Stop'

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'HostRuntime.ps1')
$HostExe = Resolve-ReverseHostExe
$scanner = Join-Path $PSScriptRoot 'scan-leaks.ps1'

$tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$scratch = Join-Path $tmpBase ('rs-scan-leaks-' + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $scratch | Out-Null

$failures = New-Object System.Collections.Generic.List[string]
function Check([bool] $Condition, [string] $Message) {
    if ($Condition) {
        Write-Host "[OK] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        [void]$failures.Add($Message)
    }
}

# Build the token at runtime so this file itself never contains one.
$token = 'gh' + 'p_' + ('a' * 36)

$cases = @(
    @{ Name = 'one-line json with token'; File = 'one.json'; Lines = @('{"token":"' + $token + '"}'); Expect = 1 },
    @{ Name = 'one-line md with token'; File = 'one.md'; Lines = @('# note ' + $token); Expect = 1 },
    @{ Name = 'multi-line md with token'; File = 'multi.md'; Lines = @('# note', 'token ' + $token); Expect = 1 },
    @{ Name = 'one-line clean file'; File = 'clean.md'; Lines = @('# nothing sensitive here'); Expect = 0 },
    @{ Name = 'one-line allowed sample email'; File = 'mail.md'; Lines = @('# contact admin@example.com'); Expect = 0 }
)

try {
    foreach ($c in $cases) {
        $file = Join-Path $scratch $c.File
        Set-Content -LiteralPath $file -Value $c.Lines -Encoding UTF8
        & $HostExe -NoProfile -ExecutionPolicy Bypass -File $scanner -Path $file 2>&1 | Out-Null
        $code = $LASTEXITCODE
        Check ($code -eq $c.Expect) ("{0}: exit {1} (expected {2})" -f $c.Name, $code, $c.Expect)
    }
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host ("scan-leaks regression: {0} failure(s)" -f $failures.Count) -ForegroundColor Red
    exit 1
}
Write-Host 'scan-leaks regression: ALL PASS' -ForegroundColor Green
exit 0
