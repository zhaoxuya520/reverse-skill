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
    $tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $LogDir = Join-Path $tmpBase ("rs-smoke-{0}" -f $stamp)
}
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$fail = New-Object System.Collections.Generic.List[string]
function Ok([string] $m) { Write-Host ("[OK] {0}" -f $m) -ForegroundColor Green }
function Bad([string] $m) {
    Write-Host ("[FAIL] {0}" -f $m) -ForegroundColor Red
    [void]$fail.Add($m)
}

# Prefer the same host that launched smoke (pwsh on GHA windows-latest).
# Bare "powershell" often resolves to Windows PowerShell 5.1, which mis-parses
# UTF-8 scripts without BOM when nested from pwsh.
$SmokeHostExe = $null
try {
    $procPath = (Get-Process -Id $PID -ErrorAction Stop).Path
    if ($procPath -and (Test-Path -LiteralPath $procPath)) { $SmokeHostExe = $procPath }
} catch { }
if (-not $SmokeHostExe) {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
        $SmokeHostExe = $cmd.Source
    } else {
        $SmokeHostExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }
}
Write-Host ("=== reverse-skill smoke | LogDir={0} | Host={1} ===" -f $LogDir, $SmokeHostExe)

# --- 1) routing coherence ---
$verify = Join-Path $scriptDir 'verify-routing-coherence.ps1'
if (-not (Test-Path -LiteralPath $verify)) {
    Bad 'verify-routing-coherence.ps1 missing'
    $verifyExit = 1
} else {
    $vLog = Join-Path $LogDir '01-verify.txt'
    & $SmokeHostExe -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Tee-Object -FilePath $vLog | Out-Null
    $verifyExit = $LASTEXITCODE
    if ($verifyExit -eq 0) { Ok 'verify-routing-coherence exit 0' } else { Bad ("verify-routing-coherence exit {0}" -f $verifyExit) }
}

# --- 2) parse key scripts ---
$scripts = @(
    'verify-routing-coherence.ps1',
    'master-route.ps1',
    'case-init.ps1',
    'lib\WorkRoot.ps1',
    'bootstrap-reverse.ps1',
    'refresh-tool-index.ps1',
    'smoke.ps1',
    'append-evidence.ps1',
    'case-guard.ps1',
    'test-routing.ps1',
    'extract-summaries.ps1'
    'test-bootstrap-codex-encoding.ps1'
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

# --- 3) Codex config UTF-8 round-trip regression ---
$encodingTest = Join-Path $scriptDir 'test-bootstrap-codex-encoding.ps1'
if (-not (Test-Path -LiteralPath $encodingTest)) {
    Bad 'test-bootstrap-codex-encoding.ps1 missing'
} else {
    $encodingLog = Join-Path $LogDir '03-codex-encoding.txt'
    & $SmokeHostExe -NoProfile -ExecutionPolicy Bypass -File $encodingTest `
        -ScratchDir (Join-Path $LogDir 'codex-encoding') 2>&1 |
        Tee-Object -FilePath $encodingLog | Out-Null
    $encodingExit = $LASTEXITCODE
    if ($encodingExit -eq 0) {
        Ok 'Codex config UTF-8 round-trip regression'
    } else {
        Bad ("Codex config UTF-8 regression exit {0}" -f $encodingExit)
    }
}

# --- 4) master-route sample matrix ---
$mr = Join-Path $scriptDir 'master-route.ps1'
$cases = @(
    @{ Name = 'apk'; Hint = 'decompile APK with jadx apktool smali'; Expect = 'apk-reverse' },
    @{ Name = 'js'; Hint = 'js reverse frontend sign jshook encrypted param'; Expect = 'js-reverse' },
    @{ Name = 'ida'; Hint = 'IDA decompile PE binary disassemble'; Expect = 'ida-reverse' },
    @{ Name = 'pentest'; Hint = 'nmap nuclei sqlmap ffuf pentest bug bounty'; Expect = 'pentest-tools' },
    @{ Name = 'llm'; Hint = 'LLM prompt inject jailbreak agent security garak'; Expect = 'llm-security' },
    @{ Name = 'zh-apk'; Hint = '安卓 APK 加固 反编译'; Expect = 'apk-reverse' },
    @{ Name = 'zh-pentest'; Hint = '渗透测试 端口扫描 SQL注入'; Expect = 'pentest-tools' },
    @{ Name = 'zh-js'; Hint = '前端签名 JS逆向 加密参数'; Expect = 'js-reverse' },
    @{ Name = 'evidence'; Hint = 'case review evidence chain traceability'; Expect = 'case-review' }
)
$routeOk = 0
$routeFail = 0
$routeSummary = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $mr)) {
    Bad 'master-route.ps1 missing'
} else {
    foreach ($c in $cases) {
        $outFile = Join-Path $LogDir ("route-{0}.txt" -f $c.Name)
        $raw = & $SmokeHostExe -NoProfile -ExecutionPolicy Bypass -File $mr -Hint $c.Hint 2>&1 | Out-String
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

# --- 5) Evidence ID immutability ---
$appendEvidence = Join-Path $scriptDir 'append-evidence.ps1'
$evidenceCase = Join-Path $LogDir 'evidence-immutability'
if (-not (Test-Path -LiteralPath $appendEvidence)) {
    Bad 'append-evidence.ps1 missing for immutability check'
} else {
    New-Item -ItemType Directory -Path $evidenceCase -Force | Out-Null
    & $SmokeHostExe -NoProfile -ExecutionPolicy Bypass -File $appendEvidence `
        -CaseRoot $evidenceCase `
        -Id 'E-IMMUTABLE' `
        -Title 'first write' `
        -ReproCommand 'echo first' 2>&1 | Out-Null
    $firstEvidenceExit = $LASTEXITCODE
    if ($firstEvidenceExit -ne 0) {
        Bad ("initial Evidence append exit {0}" -f $firstEvidenceExit)
    } else {
        $evidencePath = Join-Path $evidenceCase 'evidence\E-IMMUTABLE.md'
        $indexPath = Join-Path $evidenceCase 'evidence\INDEX.md'
        $beforeEvidence = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash
        $beforeIndex = (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash

        & $SmokeHostExe -NoProfile -ExecutionPolicy Bypass -File $appendEvidence `
            -CaseRoot $evidenceCase `
            -Id 'E-IMMUTABLE' `
            -Title 'second write' `
            -ReproCommand 'echo second' 2>&1 | Out-Null
        $duplicateEvidenceExit = $LASTEXITCODE

        $afterEvidence = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash
        $afterIndex = (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash
        if ($duplicateEvidenceExit -eq 0) {
            Bad 'duplicate Evidence ID was accepted'
        } elseif ($beforeEvidence -ne $afterEvidence) {
            Bad 'existing Evidence changed after duplicate append'
        } elseif ($beforeIndex -ne $afterIndex) {
            Bad 'Evidence index changed after duplicate append'
        } else {
            Ok 'duplicate Evidence ID rejected without mutation'
        }
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

