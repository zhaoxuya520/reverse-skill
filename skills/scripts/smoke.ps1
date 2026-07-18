#Requires -Version 5.1
# reverse-skill smoke entrypoint: verify + script parse + master-route sample matrix.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/smoke.ps1
#   powershell -File skills/scripts/smoke.ps1 -LogDir C:\path\to\logs
param(
    [string] $LogDir = '',
    [string] $PackageRoot = ''
)
$ErrorActionPreference = 'Continue'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $skillsRoot }

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $LogDir = Join-Path $env:TEMP ("rs-smoke-{0}" -f $stamp)
}
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$fail = New-Object System.Collections.Generic.List[string]
function Ok([string] $m) { Write-Host ("[OK] {0}" -f $m) -ForegroundColor Green }
function Bad([string] $m) {
    Write-Host ("[FAIL] {0}" -f $m) -ForegroundColor Red
    [void]$fail.Add($m)
}

Write-Host ("=== reverse-skill smoke | LogDir={0} ===" -f $LogDir)

# --- 1) routing coherence ---
$verify = Join-Path $scriptDir 'verify-routing-coherence.ps1'
if (-not (Test-Path -LiteralPath $verify)) {
    Bad 'verify-routing-coherence.ps1 missing'
    $verifyExit = 1
} else {
    $vLog = Join-Path $LogDir '01-verify.txt'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Tee-Object -FilePath $vLog | Out-Null
    $verifyExit = $LASTEXITCODE
    if ($verifyExit -eq 0) { Ok 'verify-routing-coherence exit 0' } else { Bad ("verify-routing-coherence exit {0}" -f $verifyExit) }
}

# --- 2) parse key scripts ---
$scripts = @(
    'verify-routing-coherence.ps1',
    'master-route.ps1',
    'case-init.ps1',
    'bootstrap-reverse.ps1',
    'refresh-tool-index.ps1',
    'smoke.ps1',
    'append-evidence.ps1',
    'case-guard.ps1'
)
$parseOk = 0
$parseFail = 0
$parseLog = New-Object System.Collections.Generic.List[string]
foreach ($name in $scripts) {
    $p = Join-Path $scriptDir $name
    if (-not (Test-Path -LiteralPath $p)) {
        # append-evidence is required for P0; others should exist
        if ($name -eq 'append-evidence.ps1' -or $name -eq 'smoke.ps1') {
            Bad ("script missing: {0}" -f $name)
            $parseFail++
            [void]$parseLog.Add("MISSING $name")
        }
        continue
    }
    $errs = $null
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        Bad ("parse fail {0}: {1}" -f $name, $errs[0].Message)
        $parseFail++
        [void]$parseLog.Add("FAIL $name $($errs[0].Message)")
    } else {
        Ok ("parse {0}" -f $name)
        $parseOk++
        [void]$parseLog.Add("OK $name")
    }
}
$parseLog -join [Environment]::NewLine | Set-Content (Join-Path $LogDir '02-parse.txt') -Encoding UTF8

# --- 3) master-route sample matrix ---
$mr = Join-Path $scriptDir 'master-route.ps1'
$cases = @(
    @{ Name = 'apk'; Hint = 'decompile APK with jadx apktool smali'; Expect = 'apk-reverse' },
    @{ Name = 'js'; Hint = 'js reverse frontend sign jshook encrypted param'; Expect = 'js-reverse' },
    @{ Name = 'ida'; Hint = 'IDA decompile PE binary disassemble'; Expect = 'ida-reverse' },
    @{ Name = 'pentest'; Hint = 'nmap nuclei sqlmap ffuf pentest bug bounty'; Expect = 'pentest-tools' },
    @{ Name = 'llm'; Hint = 'LLM prompt inject jailbreak agent security garak'; Expect = 'llm-security' },
    @{ Name = 'zh-apk'; Hint = '安卓 APK 加固 反编译'; Expect = 'apk-reverse' },
    @{ Name = 'zh-pentest'; Hint = '渗透测试 端口扫描 SQL注入'; Expect = 'pentest-tools' },
    @{ Name = 'zh-js'; Hint = '前端签名 JS逆向 加密参数'; Expect = 'js-reverse' }
)
$routeOk = 0
$routeFail = 0
$routeSummary = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $mr)) {
    Bad 'master-route.ps1 missing'
} else {
    foreach ($c in $cases) {
        $outFile = Join-Path $LogDir ("route-{0}.txt" -f $c.Name)
        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $mr -Hint $c.Hint 2>&1 | Out-String
        $raw | Set-Content -Path $outFile -Encoding UTF8
        if ($raw -match [regex]::Escape($c.Expect)) {
            Ok ("route {0} -> {1}" -f $c.Name, $c.Expect)
            $routeOk++
            [void]$routeSummary.Add("PASS $($c.Name)")
        } else {
            Bad ("route {0} expect {1}" -f $c.Name, $c.Expect)
            $routeFail++
            [void]$routeSummary.Add("FAIL $($c.Name)")
        }
    }
}
$routeSummary -join [Environment]::NewLine | Set-Content (Join-Path $LogDir '03-route-summary.txt') -Encoding UTF8

# --- 4) must-not product modules under skills/ ---
foreach ($ghost in @('blockchain-security', 'bitcoin-puzzle')) {
    $gp = Join-Path $skillsRoot $ghost
    if (Test-Path -LiteralPath $gp) {
        Bad ("core must not contain skills/{0}" -f $ghost)
    } else {
        Ok ("no skills/{0}" -f $ghost)
    }
}

# --- summary ---
$summary = @(
    "VERIFY_EXIT=$verifyExit",
    "PARSE ok=$parseOk fail=$parseFail",
    "ROUTE ok=$routeOk fail=$routeFail / $($cases.Count)",
    "FAIL_COUNT=$($fail.Count)",
    "LogDir=$LogDir"
)
$summary -join [Environment]::NewLine | Set-Content (Join-Path $LogDir 'SUMMARY.txt') -Encoding UTF8
Write-Host '=== SMOKE SUMMARY ==='
$summary | ForEach-Object { Write-Host $_ }
if ($fail.Count -gt 0) {
    $fail | Set-Content (Join-Path $LogDir 'failures.txt') -Encoding UTF8
    Write-Host 'OVERALL: FAIL' -ForegroundColor Red
    exit 1
}
Write-Host 'OVERALL: ALL PASS' -ForegroundColor Green
exit 0
