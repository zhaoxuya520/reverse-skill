#Requires -Version 5.1
# In-repo test: authorization flow matrix (record-only, zero target traffic).
#
# For each task it runs the documented three-step flow:
#   case-init -AuthGranted -> scope.md -> case-guard
# and asserts the case ends ready_for_act=true with case-guard exit 0.
#
# Negative controls assert the gate still fails closed:
#   N1 no -AuthGranted              -> auth.status=pending + case-guard exit 2
#   N2 N1 with -Force               -> still exit 2 (Force never bypasses)
#   N3 -AuthStatus denied           -> case-guard exit 2
#
# -TargetUrl / -InScopeAssets values are only written into scope.md.
# Nothing here opens a socket; example.com (RFC 2606) and 10.0.0.0/8 are
# non-routable placeholders used for scope bookkeeping only.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/test-auth-flow.ps1
param(
    [string] $ScratchDir = '',
    [string] $PackageRoot = ''
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$skillsRoot = Split-Path -Parent $scriptDir
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $skillsRoot }

. (Join-Path (Join-Path $scriptDir 'lib') 'HostRuntime.ps1')
$HostExe = Resolve-ReverseHostExe

if ([string]::IsNullOrWhiteSpace($ScratchDir)) {
    $tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $ScratchDir = Join-Path $tmpBase ('rs-auth-flow-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
$sampleDir = Join-Path $ScratchDir 'samples'
New-Item -ItemType Directory -Path $sampleDir -Force | Out-Null
foreach ($name in @('sample.apk', 'libsample.so', 'firmware.bin', 'dropper.exe', 'traffic.pcap')) {
    Set-Content -LiteralPath (Join-Path $sampleDir $name) -Value 'placeholder' -Encoding Ascii
}
function SamplePath([string] $name) { return (Join-Path $sampleDir $name) }

$caseInit = Join-Path $scriptDir 'case-init.ps1'
$caseGuard = Join-Path $scriptDir 'case-guard.ps1'

$fail = New-Object System.Collections.Generic.List[string]
function Bad([string] $m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

function Invoke-CaseInit([string[]] $InitArgs) {
    & $HostExe -NoProfile -ExecutionPolicy Bypass -File $caseInit @InitArgs 2>&1 | Out-Null
    return $LASTEXITCODE
}
function Get-ScopeField([string] $caseRoot, [string] $field) {
    $scopePath = Join-Path $caseRoot 'scope.md'
    if (-not (Test-Path -LiteralPath $scopePath)) { return '' }
    $text = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8
    $m = [regex]::Match($text, ('(?m)^\s*-\s*' + [regex]::Escape($field) + ':\s*(?<v>.*?)\s*$'))
    if ($m.Success) { return $m.Groups['v'].Value.Trim() }
    return ''
}
function Invoke-Guard([string] $caseRoot, [switch] $Force) {
    $a = @('-CaseRoot', $caseRoot)
    if ($Force) { $a += '-Force' }
    & $HostExe -NoProfile -ExecutionPolicy Bypass -File $caseGuard @a 2>&1 | Out-Null
    return $LASTEXITCODE
}

# name, hint, extra case-init args
$cases = @(
    @{ n = 'apk';        hint = '逆向这个 APK，脱壳并还原登录签名算法';  args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'sample.apk')) },
    @{ n = 'native-so';  hint = '分析这个 .so，还原加密函数';            args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'libsample.so')) },
    @{ n = 'js-sign';    hint = '抓包看这个 App 的上传参数，还原签名';    args = @('-TargetUrl', 'https://example.com/') },
    @{ n = 'sqli';       hint = '对 example.com 做 SQL 注入测试';         args = @('-TargetUrl', 'https://example.com/') },
    @{ n = 'waf-bypass'; hint = '绕过这个站点的 WAF，试 union 注入';      args = @('-TargetUrl', 'https://example.com/') },
    @{ n = 'firmware';   hint = '固件解包，找里面的密钥';                 args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'firmware.bin')) },
    @{ n = 'edr-sample'; hint = '分析这个免杀样本的加载器';               args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'dropper.exe')) },
    @{ n = 'anti-debug'; hint = '这个加固 APK 有反调试，绕过它';          args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'sample.apk')) },
    @{ n = 'ransom-pcap';hint = '分析这个勒索软件的 C2 通信 pcap';        args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'traffic.pcap')) },
    @{ n = 'ad-lateral'; hint = '内网横向，用 BloodHound 找域管路径';     args = @('-TargetUrl', '10.0.0.5') },
    @{ n = 'ctf-pwn';    hint = 'CTF pwn 题，栈溢出 ROP 拿 shell';        args = @('-Preset', 'ctf-public', '-InScopeAssets', 'ctf://chal-01') },
    @{ n = 'unity';      hint = '游戏逆向，Unity IL2CPP 还原';            args = @('-Preset', 'offline-sample', '-Sample', (SamplePath 'sample.apk')) }
)

Write-Host ("ScratchDir={0}" -f $ScratchDir)
Write-Host ("Cases={0}" -f $cases.Count)
Write-Host ''

$rows = New-Object System.Collections.Generic.List[object]
foreach ($c in $cases) {
    $projectRoot = Join-Path $ScratchDir ("proj-" + $c.n)
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
    $initArgs = @('-Hint', $c.hint, '-CaseName', $c.n,
        '-AuthGranted', '-AuthBasis', 'own_system',
        '-EvidenceOfAuth', 'auth-layer-test: standing grant',
        '-ProjectRoot', $projectRoot) + $c.args
    $initCode = Invoke-CaseInit $initArgs
    $caseRoot = Join-Path $projectRoot ("work\" + $c.n)
    $status = Get-ScopeField $caseRoot 'status'
    $ready = Get-ScopeField $caseRoot 'ready_for_act'
    $mode = Get-ScopeField $caseRoot 'mode'
    $guardCode = Invoke-Guard $caseRoot

    $ok = ($initCode -eq 0) -and ($status -eq 'granted') -and ($ready -eq 'true') -and ($guardCode -eq 0)
    $rows.Add([pscustomobject]@{
        Case = $c.n; Init = $initCode; Status = $status; Mode = $mode; Ready = $ready; Guard = $guardCode; Pass = $ok
    })
    if (-not $ok) {
        Bad ("case '{0}': init={1} status='{2}' mode='{3}' ready='{4}' guard={5}" -f $c.n, $initCode, $status, $mode, $ready, $guardCode)
    } else {
        Write-Host ("[OK] {0,-12} {1,-14} ready={2} guard=0" -f $c.n, $status, $ready) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '--- negative controls (gate must fail closed) ---'

# N1: no -AuthGranted, network target
$p1 = Join-Path $ScratchDir 'neg-pending'
New-Item -ItemType Directory -Path $p1 -Force | Out-Null
$c1 = Invoke-CaseInit @('-Hint', '对 example.com 做 SQL 注入测试', '-CaseName', 'neg', '-TargetUrl', 'https://example.com/', '-ProjectRoot', $p1)
$r1 = Join-Path $p1 'work\neg'
$s1 = Get-ScopeField $r1 'status'
$g1 = Invoke-Guard $r1
if (($c1 -eq 0) -and ($s1 -eq 'pending') -and ($g1 -eq 2)) { Write-Host '[OK] N1 pending case blocked by case-guard' -ForegroundColor Green }
else { Bad ("N1 pending case: init={0} status='{1}' guard={2} (expected 0/pending/2)" -f $c1, $s1, $g1) }

# N2: -Force must not bypass
$g2 = Invoke-Guard $r1 -Force
if ($g2 -eq 2) { Write-Host '[OK] N2 -Force does not bypass' -ForegroundColor Green }
else { Bad ("N2 -Force: guard={0} (expected 2)" -f $g2) }

# N3: explicit denied status
$p3 = Join-Path $ScratchDir 'neg-denied'
New-Item -ItemType Directory -Path $p3 -Force | Out-Null
$c3 = Invoke-CaseInit @('-Hint', '对 example.com 做 SQL 注入测试', '-CaseName', 'neg3', '-AuthStatus', 'denied', '-TargetUrl', 'https://example.com/', '-ProjectRoot', $p3)
$r3 = Join-Path $p3 'work\neg3'
$s3 = Get-ScopeField $r3 'status'
$g3 = Invoke-Guard $r3
if (($c3 -eq 0) -and ($s3 -eq 'denied') -and ($g3 -eq 2)) { Write-Host '[OK] N3 denied case blocked by case-guard' -ForegroundColor Green }
else { Bad ("N3 denied case: init={0} status='{1}' guard={2} (expected 0/denied/2)" -f $c3, $s3, $g3) }

Write-Host ''
$rows | Format-Table -AutoSize | Out-String | Write-Host

$passed = @($rows | Where-Object { $_.Pass }).Count
Write-Host ("AUTH FLOW: {0}/{1} cases ready_for_act, negatives {2}" -f $passed, $rows.Count, $(if ($fail.Count -eq 0) { 'ok' } else { 'failed' }))
if ($fail.Count -eq 0) {
    Write-Host 'AUTH FLOW: ALL PASS'
    exit 0
}
Write-Host ("AUTH FLOW: {0} FAILURE(S)" -f $fail.Count) -ForegroundColor Red
$fail | ForEach-Object { Write-Host (" - {0}" -f $_) -ForegroundColor Red }
exit 1
