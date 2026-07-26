#Requires -Version 5.1
# In-repo test: drives real smoke / case-init / append-evidence entrypoints.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/test-p0-friction.ps1
#   powershell -File skills/scripts/test-p0-friction.ps1 -ScratchDir $env:TEMP\my-scratch
param(
    [string] $ScratchDir = '',
    [string] $PackageRoot = ''
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$skillsRoot = Split-Path -Parent $scriptDir
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $skillsRoot }

if ([string]::IsNullOrWhiteSpace($ScratchDir)) {
    $ScratchDir = Join-Path $env:TEMP ('rs-p0-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
$CasePackageRoot = $ScratchDir

$scopeFixturePath = Join-Path $ScratchDir 'approved-scope.json'
$scopeFixture = [ordered]@{
    schemaVersion = '1'
    scopeId = 'fixture-approved-scope'
    status = 'granted'
    approvalId = 'fixture-ticket-001'
    issuedAt = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('o')
    expiresAt = (Get-Date).ToUniversalTime().AddHours(1).ToString('o')
    targets = @([ordered]@{
        type = 'network'
        scheme = 'https'
        host = 'app.example.invalid'
        port = 443
        pathPrefixes = @('/')
    })
    allowedActions = @('passive.read', 'request.send', 'replay.send', 'scan.active')
    notes = 'test fixture only'
}
$scopeFixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $scopeFixturePath -Encoding UTF8

$fail = New-Object System.Collections.Generic.List[string]
function Ok($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

Write-Host "ScratchDir=$ScratchDir"
Write-Host "PackageRoot=$PackageRoot"

# 1) smoke entrypoint
$smokeLog = Join-Path $ScratchDir 'smoke.log'
$smoke = Join-Path $scriptDir 'smoke.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $smoke -LogDir (Join-Path $ScratchDir 'smoke-logs') -PackageRoot $PackageRoot 2>&1 |
    Tee-Object -FilePath $smokeLog | Out-Null
$smokeExit = $LASTEXITCODE
if ($smokeExit -eq 0) { Ok 'smoke exit 0' } else { Bad "smoke exit $smokeExit" }
$smokeText = Get-Content $smokeLog -Raw -Encoding UTF8
if ($smokeText -match 'verify-routing-coherence|VERIFY_EXIT=0|ALL PASS') { Ok 'smoke log has verify/pass signal' } else { Bad 'smoke log missing verify/pass signal' }
if ($smokeText -match 'route apk|parse master-route|parse case-init') { Ok 'smoke log has parse/route activity' } else { Bad 'smoke log missing parse/route activity' }

# 2) case-init imports only a valid user-provided scope.json
$caseName = 'p0-ready-' + (Get-Date -Format 'HHmmss')
$ciLog = Join-Path $ScratchDir 'case-init.log'
$ci = Join-Path $scriptDir 'case-init.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $ci `
    -Hint 'web pentest nmap nuclei' `
    -CaseName $caseName `
    -PackageRoot $CasePackageRoot `
    -ScopeFile $scopeFixturePath `
    -AuthGranted `
    -TargetUrl 'https://app.example.invalid/' `
    -NetworkProfile 'authorized_target_only' 2>&1 |
    Tee-Object -FilePath $ciLog | Out-Null
$caseRoot = Join-Path $CasePackageRoot ("work\{0}" -f $caseName)
$scopeJsonPath = Join-Path $caseRoot 'scope.json'
if (Test-Path $scopeJsonPath) { Ok 'scope.json written' } else { Bad 'scope.json missing' }
$scopePath = Join-Path $caseRoot 'scope.md'
if (-not (Test-Path $scopePath)) { Bad "scope.md missing at $scopePath" }
else {
    $scope = Get-Content $scopePath -Raw -Encoding UTF8
    $scope | Set-Content (Join-Path $ScratchDir 'scope.md') -Encoding UTF8
    if ($scope -match 'status:\s*granted' -and $scope -match 'source_of_truth:\s*scope\.json') { Ok 'scope auth derived from scope.json' } else { Bad 'scope auth/source missing' }
    if ($scope -match 'app\.example\.invalid') { Ok 'scope in_scope has target' } else { Bad 'scope missing target asset' }
    if ($scope -match 'mode:\s*authorized_target_only') { Ok 'scope network authorized_target_only' } else { Bad 'scope network not authorized_target_only' }
    if ($scope -match 'ready_for_act:\s*true') { Ok 'scope ready_for_act true' } else { Bad 'scope ready_for_act not true' }
}

# 3) bare case-init creates a draft and AuthGranted cannot self-grant
$bareName = 'p0-bare-' + (Get-Date -Format 'HHmmss')
& powershell -NoProfile -ExecutionPolicy Bypass -File $ci -CaseName $bareName -PackageRoot $CasePackageRoot -AuthGranted -TargetUrl 'https://app.example.invalid/' -NetworkProfile authorized_target_only 2>&1 | Out-Null
$bareRoot = Join-Path $CasePackageRoot ("work\{0}" -f $bareName)
$bareScope = Get-Content (Join-Path $bareRoot 'scope.md') -Raw -Encoding UTF8
if ($bareScope -match 'status:\s*draft' -and $bareScope -match 'ready_for_act:\s*false' -and (Test-Path (Join-Path $bareRoot 'scope.json'))) {
    Ok 'bare/AuthGranted case-init remains draft/offline'
} else {
    Bad 'bare/AuthGranted case-init incorrectly granted'
}

# 4) append-evidence
$evCase = Join-Path $ScratchDir 'case-ev'
New-Item -ItemType Directory -Path (Join-Path $evCase 'evidence') -Force | Out-Null
# minimal case tree
'placeholder' | Set-Content (Join-Path $evCase 'scope.md') -Encoding UTF8
$ae = Join-Path $scriptDir 'append-evidence.ps1'
$aeLog = Join-Path $ScratchDir 'append-evidence.log'
& powershell -NoProfile -ExecutionPolicy Bypass -File $ae `
    -CaseRoot $evCase `
    -Id 'E-001' `
    -Title 'Smoke evidence item' `
    -ReproCommand 'curl -sI https://app.example.invalid/' `
    -Severity info `
    -Status observed `
    -RawExcerpt 'HTTP/1.1 200 OK' 2>&1 |
    Tee-Object -FilePath $aeLog | Out-Null
$evFile = Join-Path $evCase 'evidence\E-001.md'
if (-not (Test-Path $evFile)) { Bad 'E-001.md not written' }
else {
    $ev = Get-Content $evFile -Raw -Encoding UTF8
    $ev | Set-Content (Join-Path $ScratchDir 'E-001.md') -Encoding UTF8
    if ($ev -match 'title:\s*Smoke evidence item') { Ok 'evidence title' } else { Bad 'evidence title missing' }
    if ($ev -match 'repro_command:') { Ok 'evidence repro_command' } else { Bad 'evidence repro_command missing' }
    if ($ev -match 'curl -sI') { Ok 'evidence repro body' } else { Bad 'evidence repro body missing' }
}

# 5) recon-pipeline topics present
$recon = Join-Path $skillsRoot 'pentest-tools\references\recon-pipeline.md'
$rt = Get-Content $recon -Raw -Encoding UTF8
foreach ($topic in @('Origin:', 'Referer:', 'eth0', 'append-evidence', 'Access-Control', 'nmap -sT')) {
    # looser checks
}
if ($rt -match 'Origin:' -and $rt -match 'Referer:') { Ok 'recon-pipeline browser Origin/Referer' } else { Bad 'recon-pipeline missing Origin/Referer' }
if ($rt -match 'eth0' -or $rt -match 'nmap -sT') { Ok 'recon-pipeline Windows nmap note' } else { Bad 'recon-pipeline missing nmap note' }
if ($rt -match 'append-evidence') { Ok 'recon-pipeline Evidence append' } else { Bad 'recon-pipeline missing append-evidence' }

# 6) no web3 product modules
foreach ($g in @('blockchain-security', 'bitcoin-puzzle')) {
    if (Test-Path (Join-Path $skillsRoot $g)) { Bad "skills/$g exists" } else { Ok "no skills/$g" }
}

# 7) verify alone
$vLog = Join-Path $ScratchDir 'verify.log'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'verify-routing-coherence.ps1') 2>&1 |
    Tee-Object -FilePath $vLog | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'verify-routing-coherence exit 0' } else { Bad "verify exit $LASTEXITCODE" }

# 8) Chinese route samples (P1)
$mr = Join-Path $scriptDir 'master-route.ps1'
$zhCases = @(
    @{ Hint = '安卓 APK 加固 反编译'; Expect = 'apk-reverse' },
    @{ Hint = '渗透测试 端口扫描 SQL注入'; Expect = 'pentest-tools' },
    @{ Hint = '前端签名 JS逆向'; Expect = 'js-reverse' }
)
foreach ($zc in $zhCases) {
    $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $mr -Hint $zc.Hint 2>&1 | Out-String
    if ($raw -match [regex]::Escape($zc.Expect)) { Ok ("zh route -> {0}" -f $zc.Expect) }
    else { Bad ("zh route miss {0}: {1}" -f $zc.Expect, ($raw.Substring(0, [Math]::Min(120, $raw.Length)))) }
}

# 9) case-guard: valid scope exits 0; draft and -Force remain blocked
$cg = Join-Path $scriptDir 'case-guard.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $caseRoot 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'case-guard ready exit 0' } else { Bad "case-guard ready exit $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $bareRoot 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard pending exit 2' } else { Bad "case-guard pending expected 2 got $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $bareRoot -Force 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard -Force remains blocked' } else { Bad "case-guard -Force expected 2 got $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $caseRoot -Capability 'request.send' -Target 'https://app.example.invalid/api/v1' 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard active action requires confirmation' } else { Bad "case-guard active action without confirmation expected 2 got $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $caseRoot -Capability 'request.send' -Target 'https://app.example.invalid/api/v1' -Confirmed 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'case-guard confirmed in-scope action allowed' } else { Bad "case-guard confirmed in-scope action expected 0 got $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $caseRoot -Capability 'request.send' -Target 'https://outside.example.invalid/api/v1' -Confirmed 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard confirmed out-of-scope target blocked' } else { Bad "case-guard out-of-scope target expected 2 got $LASTEXITCODE" }
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $caseRoot -Capability 'cookie.write' -Target 'https://app.example.invalid/' -Confirmed 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard disallowed action blocked' } else { Bad "case-guard disallowed action expected 2 got $LASTEXITCODE" }

# 10) authorization and malformed-scope regression cases
$scopeCases = @(
    @{ Name = 'missing'; Content = $null; Expect = 'blocked' },
    @{ Name = 'malformed'; Content = '{"schemaVersion":'; Expect = 'blocked' },
    @{ Name = 'expired'; Content = (($scopeFixture | ConvertTo-Json -Depth 8) -replace '"expiresAt"\s*:\s*"[^"]+"', ('"expiresAt": "{0}"' -f (Get-Date).ToUniversalTime().AddMinutes(-1).ToString('o'))); Expect = 'blocked' },
    @{ Name = 'missing-approval'; Content = (($scopeFixture | ConvertTo-Json -Depth 8) -replace '"approvalId"\s*:\s*"[^"]+"', '"approvalId": ""'); Expect = 'blocked' },
    @{ Name = 'wildcard'; Content = (($scopeFixture | ConvertTo-Json -Depth 8) -replace 'app\.example\.invalid', '*.example.invalid'); Expect = 'blocked' },
    @{ Name = 'path-wildcard'; Content = (($scopeFixture | ConvertTo-Json -Depth 8) -replace '"pathPrefixes"\s*:\s*\[\s*"/"\s*\]', '"pathPrefixes": ["/*"]'); Expect = 'blocked' }
)
foreach ($scopeCase in $scopeCases) {
    $name = 'p0-scope-' + $scopeCase.Name + '-' + (Get-Date -Format 'HHmmssfff')
    $input = $scopeFixturePath
    if ($scopeCase.Name -eq 'missing') { $input = Join-Path $ScratchDir 'does-not-exist.json' }
    elseif ($scopeCase.Content) {
        $input = Join-Path $ScratchDir ($scopeCase.Name + '.json')
        Set-Content -LiteralPath $input -Value $scopeCase.Content -Encoding UTF8
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ci -CaseName $name -PackageRoot $CasePackageRoot -ScopeFile $input -TargetUrl 'https://app.example.invalid/' -NetworkProfile authorized_target_only 2>&1 | Out-Null
    $root = Join-Path $CasePackageRoot ("work\{0}" -f $name)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $root 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 2) { Ok ("scope {0} blocked" -f $scopeCase.Name) } else { Bad ("scope {0} expected blocked, got {1}" -f $scopeCase.Name, $LASTEXITCODE) }
}

$outOfScopeName = 'p0-out-of-scope-' + (Get-Date -Format 'HHmmssfff')
& powershell -NoProfile -ExecutionPolicy Bypass -File $ci -CaseName $outOfScopeName -PackageRoot $CasePackageRoot -ScopeFile $scopeFixturePath -TargetUrl 'https://outside.example.invalid/' -NetworkProfile authorized_target_only 2>&1 | Out-Null
$outOfScopeRoot = Join-Path $CasePackageRoot ("work\{0}" -f $outOfScopeName)
$outOfScopeJson = Get-Content (Join-Path $outOfScopeRoot 'scope.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($outOfScopeJson.targets[0].host -eq 'app.example.invalid') { Ok 'scope target comes from scope.json, not TargetUrl' } else { Bad 'TargetUrl changed imported scope' }
. (Join-Path $scriptDir 'lib\ScopePolicy.ps1')
$loadedScope = Import-ScopeDocument -Path $scopeFixturePath -RequireGranted
if (-not (Test-ScopeTargetMatch -Scope $loadedScope -Target 'https://outside.example.invalid/' -Action 'request.send')) { Ok 'out-of-scope host rejected' } else { Bad 'out-of-scope host matched' }
if (-not (Test-ScopeTargetMatch -Scope $loadedScope -Target 'http://app.example.invalid/' -Action 'request.send')) { Ok 'out-of-scope scheme rejected' } else { Bad 'out-of-scope scheme matched' }
if (-not (Test-ScopeTargetMatch -Scope $loadedScope -Target 'https://app.example.invalid:8443/' -Action 'request.send')) { Ok 'out-of-scope port rejected' } else { Bad 'out-of-scope port matched' }
$prefixScope = (($scopeFixture | ConvertTo-Json -Depth 8) | ConvertFrom-Json)
$prefixScope.targets[0].pathPrefixes = @('/api')
$prefixScopePath = Join-Path $ScratchDir 'path-prefix-scope.json'
$prefixScope | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $prefixScopePath -Encoding UTF8
$prefixLoadedScope = Import-ScopeDocument -Path $prefixScopePath -RequireGranted
if (Test-ScopeTargetMatch -Scope $prefixLoadedScope -Target 'https://app.example.invalid/api/v1' -Action 'request.send') { Ok 'path prefix child accepted' } else { Bad 'path prefix child rejected' }
if (-not (Test-ScopeTargetMatch -Scope $prefixLoadedScope -Target 'https://app.example.invalid/apix' -Action 'request.send')) { Ok 'path boundary rejects /apix' } else { Bad 'path boundary accepted /apix' }
if (-not (Test-ScopeTargetMatch -Scope $prefixLoadedScope -Target 'https://app.example.invalid/api/%2e%2e/admin' -Action 'request.send')) { Ok 'encoded path traversal rejected' } else { Bad 'encoded path traversal matched' }
if (-not (Test-ScopeRedirectChain -Scope $prefixLoadedScope -Targets @('https://app.example.invalid/api/start', 'https://outside.example.invalid/api/final') -Action 'request.send')) { Ok 'redirect chain rejects out-of-scope hop' } else { Bad 'redirect chain accepted out-of-scope hop' }
. (Join-Path $scriptDir 'lib\CapabilityPolicy.ps1')
$passivePolicy = Test-CapabilityPolicy -Capability 'passive.read' -Authenticated
$activePolicy = Test-CapabilityPolicy -Capability 'request.send' -Authenticated -ScopeValid
if ($passivePolicy.Status -eq 'allowed') { Ok 'passive.read allowed after authentication' } else { Bad 'passive.read policy blocked unexpectedly' }
if ($activePolicy.Status -eq 'confirmation_required') { Ok 'active policy requires confirmation' } else { Bad 'active policy did not require confirmation' }

# 11) append-evidence: special-char excerpt via -File + -RawExcerptFile (real nested CLI path)
$ae2 = Join-Path $ScratchDir 'case-ev'
New-Item -ItemType Directory -Path (Join-Path $ae2 'evidence') -Force | Out-Null
'x' | Set-Content (Join-Path $ae2 'scope.md') -Encoding UTF8
$excerptPayload = '"XML parsing error" / Entities are not allowed'
$excerptFile = Join-Path $ScratchDir 'excerpt-payload.txt'
# UTF-8 no BOM for portability
[System.IO.File]::WriteAllText($excerptFile, $excerptPayload, (New-Object System.Text.UTF8Encoding $false))
& powershell -NoProfile -ExecutionPolicy Bypass -File $ae `
    -CaseRoot $ae2 `
    -Id 'E-XML' `
    -Title 'Stock API error sample' `
    -ReproCommand 'curl -s -X POST https://example/stock --data-binary @x.xml' `
    -RawExcerptFile $excerptFile `
    -Severity medium `
    -Status observed 2>&1 |
    Tee-Object -FilePath (Join-Path $ScratchDir 'append-evidence.log') | Out-Null
if ($LASTEXITCODE -ne 0) { Bad "append-evidence -File exit $LASTEXITCODE" }
$evXml = Join-Path $ae2 'evidence\E-XML.md'
if (Test-Path $evXml) {
    $ex = Get-Content $evXml -Raw -Encoding UTF8
    $ex | Set-Content (Join-Path $ScratchDir 'E-XML.md') -Encoding UTF8
    if ($ex -match '(?m)^- title:\s*Stock API error sample\s*$' -and $ex -match 'repro_command:') {
        Ok 'evidence has title+repro'
    } else { Bad 'evidence missing title/repro' }
    # Assert specifically inside raw_excerpt block (not title)
    $excerptBlockOk = $false
    if ($ex -match '(?ms)^- raw_excerpt:\s*\|\r?\n(?<block>.*?)(?=\r?\n- |\z)') {
        $block = $Matches['block']
        if ($block -match 'XML parsing error' -and $block -match 'Entities are not allowed' -and $block -match '"') {
            $excerptBlockOk = $true
        }
    }
    if ($excerptBlockOk) { Ok 'raw_excerpt block preserves special payload' } else { Bad 'raw_excerpt block lost special payload' }
    if ($ex -match '(?m)^- location:\s*n/a\s*$') { Ok 'location remains n/a' } else { Bad 'location polluted by arg split' }
    if ($ex -match '(?m)^- source_type:\s*command\s*$') { Ok 'source_type remains command' } else { Bad 'source_type polluted by arg split' }
} else { Bad 'E-XML.md not written' }

# 11b) broken multi-word -RawExcerpt under -File must fail loud (not silently corrupt fields)
$ae3 = Join-Path $ScratchDir 'case-ev-broken'
New-Item -ItemType Directory -Path (Join-Path $ae3 'evidence') -Force | Out-Null
'x' | Set-Content (Join-Path $ae3 'scope.md') -Encoding UTF8
$brokenLog = Join-Path $ScratchDir 'append-evidence-broken.log'
# Intentionally unquoted multi-word after -RawExcerpt to simulate nested -File quote loss
cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$ae`" -CaseRoot `"$ae3`" -Id E-BAD -Title `"T`" -ReproCommand `"curl -sI https://example/`" -RawExcerpt XML parsing error / Entities -Severity info -Status observed >`"$brokenLog`" 2>&1"
if ($LASTEXITCODE -ne 0) { Ok 'broken multi-word RawExcerpt fails loud' } else { Bad 'broken multi-word RawExcerpt should not exit 0' }

# 12) client-side + recon playbook topics
$play = Join-Path $skillsRoot 'pentest-tools\references\client-side-lab-playbook.md'
$recon = Join-Path $skillsRoot 'pentest-tools\references\recon-pipeline.md'
if (Test-Path $play) {
    $pt = Get-Content $play -Raw -Encoding UTF8
    if ($pt -match 'globoff' -and $pt -match 'innerHTML' -and $pt -match 'agent-browser' -and $pt -match 'observed') {
        Ok 'client-side-lab-playbook topics'
    } else { Bad 'client-side-lab-playbook missing topics' }
} else { Bad 'client-side-lab-playbook missing' }
if (Test-Path $recon) {
    $rt = Get-Content $recon -Raw -Encoding UTF8
    if ($rt -match 'Origin:' -and $rt -match 'Referer:' -and $rt -match 'globoff' -and ($rt -match 'nmap -sT' -or $rt -match 'eth0')) {
        Ok 'recon-pipeline topic families'
    } else { Bad 'recon-pipeline missing topic family' }
} else { Bad 'recon-pipeline missing' }

# 13) ReadyForAct alone must NOT mark ready without auth/assets
$forceName = 'p0-forceonly-' + (Get-Date -Format 'HHmmss')
& powershell -NoProfile -ExecutionPolicy Bypass -File $ci `
    -CaseName $forceName -PackageRoot $CasePackageRoot -ReadyForAct 2>&1 | Out-Null
$forceScope = Get-Content (Join-Path $CasePackageRoot ("work\{0}\scope.md" -f $forceName)) -Raw -Encoding UTF8
if ($forceScope -match 'ready_for_act:\s*false' -and $forceScope -match 'status:\s*draft') {
    Ok 'ReadyForAct alone does not bypass auth'
} else {
    Bad 'ReadyForAct alone incorrectly set ready/granted'
}

# 14) case-guard must not treat ops_refs paths as in_scope assets
$ghostCase = Join-Path $ScratchDir 'case-guard-ghost-asset'
New-Item -ItemType Directory -Force -Path $ghostCase | Out-Null
$ghostScope = @'
# Case Scope
## auth
- status: granted
## in_scope
- assets:
  []
## network_profile
- mode: lab_only
## signoff
- ready_for_act: true
## ops_refs
- skills/ops/scope-contract.md
- https://example.com/docs-only-not-asset
'@
Set-Content (Join-Path $ghostCase 'scope.md') $ghostScope -Encoding UTF8
& powershell -NoProfile -ExecutionPolicy Bypass -File $cg -CaseRoot $ghostCase 2>&1 | Out-Null
if ($LASTEXITCODE -eq 2) { Ok 'case-guard rejects empty assets despite ops_refs URLs' }
else { Bad "case-guard should fail empty assets; exit=$LASTEXITCODE" }

# 15) workflow PR-title injection regression
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'test-workflow-security.ps1') 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { Ok 'workflow security regression checks' } else { Bad "workflow security checks exit $LASTEXITCODE" }

# 13) copy smoke primary log alias for harness
$smokeLogs = Join-Path $ScratchDir 'smoke-logs'
if (Test-Path (Join-Path $smokeLogs 'SUMMARY.txt')) {
    Copy-Item (Join-Path $smokeLogs 'SUMMARY.txt') (Join-Path $ScratchDir 'smoke-summary.txt') -Force
}
if (Test-Path $smokeLog) {
    # already smoke.log
}

# OPT summary
$opt = @(
    "entrypoints: smoke.ps1, case-init.ps1, append-evidence.ps1, case-guard.ps1, master-route.ps1, verify-routing-coherence.ps1, test-p0-friction.ps1",
    "docs: recon-pipeline.md (Origin/Referer, nmap -sT/eth0, globoff, append-evidence); client-side-lab-playbook.md (innerHTML sink, agent-browser, observed vs validated, PP)",
    "ghost_skills: blockchain-security=$(Test-Path (Join-Path $skillsRoot 'blockchain-security')) bitcoin-puzzle=$(Test-Path (Join-Path $skillsRoot 'bitcoin-puzzle'))",
    "FAIL_COUNT=$($fail.Count)",
    "ScratchDir=$ScratchDir"
)
$opt -join [Environment]::NewLine | Set-Content (Join-Path $ScratchDir 'OPT-SUMMARY.txt') -Encoding UTF8

$summary = "FAIL_COUNT=$($fail.Count)`nScratchDir=$ScratchDir"
$summary | Set-Content (Join-Path $ScratchDir 'TEST-SUMMARY.txt') -Encoding UTF8
Write-Host '=== TEST-P0 SUMMARY ==='
Write-Host $summary
if ($fail.Count -gt 0) {
    $fail | Set-Content (Join-Path $ScratchDir 'failures.txt') -Encoding UTF8
    exit 1
}
Write-Host 'OVERALL: ALL PASS' -ForegroundColor Green
exit 0
