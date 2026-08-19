#Requires -Version 5.1
# reverse-skill routing + ops contract gates (skill-router only; no host platform runtime)
param([string] $ScratchDir = '')
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$packageRoot = Split-Path -Parent $skillsRoot
$masterRoute = Join-Path $scriptDir 'master-route.ps1'
$caseInit = Join-Path $scriptDir 'case-init.ps1'
$masterDoc = Join-Path $skillsRoot 'MASTER-ROUTING.md'
. (Join-Path $scriptDir 'lib/RouteScope.ps1')

. (Join-Path (Join-Path $scriptDir 'lib') 'HostRuntime.ps1')
$HostExe = Resolve-ReverseHostExe

$tmpBase = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
if (-not $ScratchDir) {
    $ScratchDir = Join-Path $tmpBase ("rs-verify-{0}" -f (Get-Date -Format 'yyyyMMddHHmmss'))
}
New-Item -ItemType Directory -Force -Path $ScratchDir | Out-Null
$fail = New-Object System.Collections.Generic.List[string]
function Ok($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

# --- 新事实源/产物检查（routing.json / benchmark / INDEX） ---
$routingJson = Join-Path $skillsRoot 'config/routing.json'
if (Test-Path -LiteralPath $routingJson) {
    $rj = Get-Content -LiteralPath $routingJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $rjRoutes = @($rj.routes.PSObject.Properties)
    if ($rjRoutes.Count -ge 30) { Ok "routing.json routes=$($rjRoutes.Count)" } else { Bad 'routing.json route count suspicious (<30)' }
    $badRoute = @($rjRoutes | Where-Object { -not $_.Value.label -or -not $_.Value.skill -or -not $_.Value.keywords })
    if ($badRoute.Count -eq 0) { Ok 'routing.json: all routes have label/skill/keywords' } else { Bad "routing.json routes missing fields: $($badRoute.Name -join ',')" }
    $missingRouteSkills = @($rjRoutes | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $skillsRoot ($_.Value.skill -replace '/', [IO.Path]::DirectorySeparatorChar)) -PathType Leaf)
    })
    if ($missingRouteSkills.Count -eq 0) { Ok 'routing.json: all route skills exist' } else { Bad "routing.json missing skill files: $($missingRouteSkills.Name -join ',')" }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $trackedSkills = @(& $git.Source -C $packageRoot ls-files -- 'skills/**/SKILL.md')
        if ($LASTEXITCODE -eq 0) {
            $untrackedRouteSkills = @($rjRoutes | Where-Object { ('skills/' + $_.Value.skill) -notin $trackedSkills })
            if ($untrackedRouteSkills.Count -eq 0) { Ok 'routing.json: all route skills are tracked' } else { Bad "routing.json references untracked skills: $($untrackedRouteSkills.Name -join ',')" }
        }
    }
    $routeIds = @($rjRoutes | ForEach-Object { $_.Name })
    $missingPrio = @($routeIds | Where-Object { $_ -notin @($rj.priority) })
    $extraPrio = @($rj.priority | Where-Object { $_ -notin $routeIds })
    if ($missingPrio.Count -eq 0 -and $extraPrio.Count -eq 0) { Ok 'routing.json priority covers all routes (1:1)' } else { Bad "routing.json priority mismatch: missing=$($missingPrio -join ',') extra=$($extraPrio -join ',')" }
    $masterText = Get-Content -LiteralPath $masterDoc -Raw -Encoding UTF8
    $masterIds = [regex]::Matches($masterText, '(?m)^\s*\|\s*\*\*(R\d+)\*\*') | ForEach-Object { $_.Groups[1].Value }
    $jsonPrio = @($rj.priority)
    if ($masterIds.Count -eq $jsonPrio.Count) {
        $drift = @()
        for ($i = 0; $i -lt $jsonPrio.Count; $i++) {
            if ($masterIds[$i] -ne $jsonPrio[$i]) { $drift += ("{0}:{1}->{2}" -f $i, $jsonPrio[$i], $masterIds[$i]) }
        }
        if ($drift.Count -eq 0) { Ok 'MASTER-ROUTING.md priority table matches routing.json' } else { Bad ("MASTER-ROUTING priority drift: " + ($drift -join ', ')) }
    } else {
        Bad ("MASTER-ROUTING priority count {0} != json {1}" -f $masterIds.Count, $jsonPrio.Count)
    }
} else {
    Bad 'skills/config/routing.json missing (single source of truth)'
}

$benchJson = Join-Path $skillsRoot 'tests/routing-benchmark.json'
if (Test-Path -LiteralPath $benchJson) {
    $bj = Get-Content -LiteralPath $benchJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $bjCases = @($bj.cases)
    if ($bjCases.Count -ge 100) { Ok "benchmark cases=$($bjCases.Count)" } else { Bad "benchmark cases < 100 ($($bjCases.Count))" }
    $badExpect = @($bjCases | Where-Object { $_.expect -notmatch '^R\d+$' })
    if ($badExpect.Count -eq 0) { Ok 'benchmark expect ids well-formed' } else { Bad "benchmark bad expect: $($badExpect.Count)" }
    # benchmark expect 必须存在于 routing.json（防 benchmark 引用已删除的路由）
    if (Test-Path -LiteralPath $routingJson) {
        $rjIds = @($rjRoutes | ForEach-Object { $_.Name })
        $ghostExpect = @($bjCases | Where-Object { $_.expect -notin $rjIds })
        if ($ghostExpect.Count -eq 0) { Ok 'benchmark expects all exist in routing.json' } else { Bad "benchmark ghost expects: $(($ghostExpect | Select-Object -First 5).expect -join ',')" }
    }
} else {
    Bad 'skills/tests/routing-benchmark.json missing'
}

if (Test-Path -LiteralPath (Join-Path $skillsRoot 'INDEX.md')) { Ok 'INDEX.md present (generated)' } else { Bad 'INDEX.md missing (run extract-summaries.ps1)' }

# master-route.ps1 不得回退到硬编码路由表（防绕过 routing.json）
$mrText = Get-Content -LiteralPath (Join-Path $scriptDir 'master-route.ps1') -Raw -Encoding UTF8
if ($mrText -match '\$map\s*=\s*\[ordered\]' -or $mrText -match "R1'\s*=\s*'apk-reverse") {
    Bad 'master-route.ps1 contains hardcoded routing table (must read routing.json)'
} else {
    Ok 'master-route.ps1 has no hardcoded routing table'
}

# --- ops artifacts exist ---
$opsFiles = @(
    'ops/IDENTITY.md',
    'ops/scope-contract.md',
    'ops/evidence-finding-path.md',
    'ops/role-map.md',
    'ops/timeline-workitem.md',
    'ops/sandbox-profile.md',
    'ops/skill-supply-chain.md',
    'ops/README.md',
    'references/community-security-skills.md',
    'references/domain-coverage-map.md',
    'attack-chain/references/lifecycle-checklist.md',
    'reverse-engineering/references/re-agent-workflow.md',
    'pentest-tools/references/recon-pipeline.md',
    'MASTER-ROUTING.md',
    'scripts/master-route.ps1',
    'scripts/case-init.ps1',
    'scripts/lib/WorkRoot.ps1',
    'scripts/lib/RouteScope.ps1',
    'case-review/SKILL.md',
    'case-review/scripts/review_case.py',
    'docs-generator/references\security-report-templates.md',
    'docs-generator/references\vendor-report-rules.md',
    'field-journal/_template.md'
)
$indexLines = New-Object System.Collections.Generic.List[string]
foreach ($rel in $opsFiles) {
    $p = Join-Path $skillsRoot $rel
    if (Test-Path -LiteralPath $p) {
        Ok "artifact $rel"
        [void]$indexLines.Add("OK $rel")
    } else {
        Bad "missing $rel"
        [void]$indexLines.Add("MISS $rel")
    }
}
$indexLines | Set-Content -LiteralPath (Join-Path $ScratchDir 'artifacts-index.txt') -Encoding UTF8

# --- links from hubs (skills + RULES single source) ---
foreach ($hub in @('MASTER-ROUTING.md', 'SKILL.md', 'routing.md')) {
    $t = Get-Content (Join-Path $skillsRoot $hub) -Raw -Encoding UTF8
    if ($t -match 'ops/scope-contract|ops\\scope-contract|case-init') { Ok "hub link scope in $hub" }
    else { Bad "hub $hub missing scope/case-init link" }
    if ($t -match 'ops/IDENTITY|IDENTITY\.md') { Ok "hub identity $hub" }
    else { Bad "hub $hub missing IDENTITY" }
}
# research deposits must be reachable from hubs
$hubAll = ''
foreach ($hub in @('MASTER-ROUTING.md', 'SKILL.md', 'ops/README.md', 'routing.md')) {
    $hp = Join-Path $skillsRoot $hub
    if (Test-Path $hp) { $hubAll += (Get-Content $hp -Raw -Encoding UTF8) }
}
foreach ($n in @('community-security-skills', 'skill-supply-chain', 're-agent-workflow', 'recon-pipeline')) {
    if ($hubAll -match [regex]::Escape($n)) { Ok "hub surfaces $n" }
    else { Bad "hub missing surface for $n" }
}

# RULES.md / RULES_zh.md MUST gate case-init/scope before ACT (injection + CRITICAL + chain)
$rulesEn = Join-Path $packageRoot 'RULES.md'
$rulesZh = Join-Path $packageRoot 'RULES_zh.md'
foreach ($rp in @($rulesEn, $rulesZh)) {
    $name = Split-Path $rp -Leaf
    if (-not (Test-Path -LiteralPath $rp)) { Bad "missing $name"; continue }
    $rt = Get-Content -LiteralPath $rp -Raw -Encoding UTF8
    if ($rt -match 'case-init' -and ($rt -match 'scope-contract|scope\.md|network_profile')) {
        Ok "$name has case-init/scope gate"
    } else {
        Bad "$name missing case-init/scope/network_profile gate"
    }
    # Compact or CRITICAL must not jump routing→ACT without scope
    if ($rt -match 'auth\.status\s*=\s*granted|auth.status=granted|未就绪禁止|MUST NOT ACT against targets|禁止对目标 ACT') {
        Ok "$name has auth hard gate language"
    } else {
        Bad "$name missing auth hard-gate language"
    }
    # Post-trigger / 行为链: case-init before ACT pattern
    if ($rt -match '(?s)case-init.{0,400}ACT|scope\.md.{0,400}ACT|scope-contract.{0,400}ACT') {
        Ok "$name orders scope before ACT (nearby)"
    } else {
        Bad "$name does not place scope/case-init before ACT"
    }
}

# --- template required headings ---
$fieldLog = New-Object System.Collections.Generic.List[string]
function Assert-Fields([string]$path, [string[]]$needles) {
    $t = Get-Content $path -Raw -Encoding UTF8
    foreach ($n in $needles) {
        if ($t -match [regex]::Escape($n)) {
            Ok "field '$n' in $(Split-Path $path -Leaf)"
            [void]$fieldLog.Add("OK $n @ $path")
        } else {
            Bad "field '$n' missing in $path"
            [void]$fieldLog.Add("MISS $n @ $path")
        }
    }
}
Assert-Fields (Join-Path $skillsRoot 'ops/scope-contract.md') @('auth', 'in_scope', 'out_of_scope', 'network_profile', 'deliverables')
Assert-Fields (Join-Path $skillsRoot 'ops/evidence-finding-path.md') @('Evidence', 'Finding', 'Path', 'repro_command', 'evidence_ids')
Assert-Fields (Join-Path $skillsRoot 'ops/timeline-workitem.md') @('timeline.md', 'workitems.md', 'Coverage')
Assert-Fields (Join-Path $skillsRoot 'ops/role-map.md') @('lead', 'cie', 'cpe', 'cre', 'Handoff')
Assert-Fields (Join-Path $skillsRoot 'ops/skill-supply-chain.md') @('AST10', 'MCP', 'bootstrap', 'MUST')
Assert-Fields (Join-Path $skillsRoot 'references/community-security-skills.md') @('trailofbits', 'agentskills.io', 'MUST', '2026-07')
Assert-Fields (Join-Path $skillsRoot 'reverse-engineering/references/re-agent-workflow.md') @('Triage', 'Static', 'Dynamic', 'Synthesis', 'IAT 修复铁律', 'E-iat-repair-fail', 'E-exports', 'dnSpy', '可行性门闩', 'E-self-check-crash', 'ExitProcess', '时间盒', 'E-api-hash', 'E-anti-debug-peb', 'E-wide-strings', 'A–T', 'U–AV', 'nonpe-format-cookbook')
Assert-Fields (Join-Path $skillsRoot 'pentest-tools/references/recon-pipeline.md') @('auth.status', 'network_profile', 'Evidence', 'nuclei')
Assert-Fields (Join-Path $skillsRoot 'docs-generator/references/security-report-templates.md') @('Evidence Chain', 'Findings', 'Path')
Assert-Fields (Join-Path $skillsRoot 'field-journal/_template.md') @('Scope', 'Evidence', 'Finding')
Assert-Fields (Join-Path $skillsRoot 'case-review/SKILL.md') @('ACTION REQUIRED', 'review_case.py', 'Evidence Graph Review')
$vendorRulesPath = Join-Path $skillsRoot 'docs-generator/references/vendor-report-rules.md'
$vendorRulesText = Get-Content $vendorRulesPath -Raw -Encoding UTF8
Assert-Fields (Join-Path $skillsRoot 'docs-generator/SKILL.md') @('vendor-report-rules.md', 'flavor = null', '不强制 IOC/ATT&CK')
Assert-Fields $vendorRulesPath @('flavor = null', 'explicit_malware')
if ($vendorRulesText -match '(?m)逆向工程报告\s*\|\s*默认\s*`malware`') {
    Bad 'vendor rules default generic reverse engineering to malware flavor'
} else {
    Ok 'vendor rules keep generic reverse engineering flavor-neutral'
}
if ($vendorRulesText -match '先确认 scope 并保全' -and $vendorRulesText -match '不得在证据保全前直接删除文件') {
    Ok 'malware remediation preserves evidence before destructive actions'
} else {
    Bad 'malware remediation does not require evidence preservation before destructive actions'
}
if ($vendorRulesText -match '(?m)JS/Web 签名逆向报告\s*\|[^\r\n]*malware') {
    Bad 'vendor rules route JS signature reports through malware flavor'
} else {
    Ok 'vendor rules keep JS signature reports flavor-neutral'
}
Assert-Fields $vendorRulesPath @('skills/ops/evidence-finding-path.md', '来源证据', 'securelist.com/updated-mata', 'www.huorong.cn', 'thin overlay', 'vuln')
Assert-Fields (Join-Path $skillsRoot 'malware-analysis/SKILL.md') @('IAT 修复铁律', 'E-iat-repair-fail', 'E-exports', 'E-self-check-crash', 'ExitProcess', '时间盒', '可行性', 'E-api-hash', 'E-sig-forge', 'A–T', 'U–AV', 'E-batch-deobf', 'E-vba-pcode')
Assert-Fields (Join-Path $skillsRoot 'reverse-engineering/anti-analysis.md') @('Agent 响应菜谱 A–T', 'E-anti-debug-cpuid', 'E-api-hash', 'SigCheck', 'ollvm-deobfuscation')
Assert-Fields (Join-Path $skillsRoot 'reverse-engineering/references/nonpe-format-cookbook.md') @('U–AV', 'E-batch-deobf', 'E-ps-decode-layer-N', 'E-vba-pcode', 'E-js-vmp', 'E-driver-irp-handlers', 'E-dll-tls-dllmain', 'E-android-hidden-icon-manifest', 'E-delay-import')
Assert-Fields (Join-Path $skillsRoot 'js-reverse/SKILL.md') @('E-js-vmp', 'E-js-deobf', 'nonpe-format-cookbook')
Assert-Fields (Join-Path $skillsRoot 'apk-reverse/SKILL.md') @('E-android-hidden-icon-manifest', 'nonpe-format-cookbook')
Assert-Fields (Join-Path $skillsRoot 'reverse-engineering/kernel-driver-reverse.md') @('E-driver-irp-handlers', 'E-driver-ioctl', 'E-driver-byovd')
Assert-Fields (Join-Path $skillsRoot 'docs-generator/references/security-report-templates.md') @('thin `vuln`', '1c. 漏洞技术分析')
if ($vendorRulesText -match '(?m)vuln.*默认全文' -or $vendorRulesText -match '第 3 个默认全文 flavor') {
    # presence of explicit "not third default" language is OK; flag only if it claims vuln IS a third default full flavor
}
if ($vendorRulesText -match '仅 2 个厂商全文 flavor' -or $vendorRulesText -match '不是.*第 3 个默认全文 flavor') {
    Ok 'vendor rules keep vuln as thin overlay not third default flavor'
} else {
    Bad 'vendor rules missing vuln thin-overlay constraint'
}
$fieldLog | Set-Content -LiteralPath (Join-Path $ScratchDir 'template-fields.txt') -Encoding UTF8

# --- role map skills exist for primary rows ---
$roleDoc = Get-Content (Join-Path $skillsRoot 'ops/role-map.md') -Raw -Encoding UTF8
foreach ($sk in @('attack-chain', 'pentest-tools', 'ida-reverse', 'docs-generator', 'llm-security')) {
    if ($roleDoc -match [regex]::Escape($sk)) { Ok "role-map mentions $sk" } else { Bad "role-map missing $sk" }
}

# --- master-route cases ---
$cases = @(
    @{ N = 'dsl'; H = 'dsl vm reverse fireye'; Id = 'R4'; Sub = 'reverse-engineering/dsl-vm-reverse/SKILL.md' },
    @{ N = 'apk'; H = 'apk jadx smali reverse'; Id = 'R1'; Sub = 'apk-reverse/SKILL.md' },
    @{ N = 'malware'; H = 'malware yara sample analysis'; Id = 'R9'; Sub = 'malware-analysis/SKILL.md' },
    @{ N = 'pentest'; H = 'nmap nuclei pentest sqlmap'; Id = 'R11'; Sub = 'pentest-tools/SKILL.md' },
    @{ N = 'attack'; H = 'full pentest attack chain from external'; Id = 'R10'; Sub = 'attack-chain/SKILL.md' },
    @{ N = 'protocol'; H = 'protobuf custom protocol reverse pcap'; Id = 'R21'; Sub = 'protocol-reverse/SKILL.md' },
    @{ N = 'ghidra'; H = 'ghidra headless decompile'; Id = 'R22'; Sub = 'ghidra-reverse/SKILL.md' },
    @{ N = 'cloud'; H = 'kubernetes k8s container escape'; Id = 'R23'; Sub = 'cloud-k8s/SKILL.md' },
    @{ N = 'ad'; H = 'bloodhound kerberoast active directory'; Id = 'R24'; Sub = 'windows-ad/SKILL.md' },
    @{ N = 'forensics'; H = 'volatility memory dump forensics'; Id = 'R25'; Sub = 'digital-forensics/SKILL.md' },
    @{ N = 'codeaudit'; H = 'semgrep code audit sast'; Id = 'R26'; Sub = 'code-audit/SKILL.md' },
    @{ N = 'hunt'; H = 'threat hunting detection engineering'; Id = 'R27'; Sub = 'threat-hunting/SKILL.md' },
    @{ N = 'ot'; H = 'scada plc modbus industrial control'; Id = 'R28'; Sub = 'ot-ics/SKILL.md' },
    @{ N = 'wifi'; H = 'wifi aircrack wireless pentest'; Id = 'R29'; Sub = 'wifi-wireless/SKILL.md' },
    @{ N = 'extension'; H = 'chrome extension crx reverse'; Id = 'R30'; Sub = 'browser-extension-reverse/SKILL.md' },
    @{ N = 'macos'; H = 'macos mach-o codesign reverse'; Id = 'R31'; Sub = 'macos-reverse/SKILL.md' },
    @{ N = 'thick'; H = 'thick client electron desktop client'; Id = 'R32'; Sub = 'thick-client/SKILL.md' },
    @{ N = 'gorust'; H = 'golang stripped go binary reverse'; Id = 'R33'; Sub = 'go-rust-reverse/SKILL.md' },
    @{ N = 'hw'; H = 'uart jtag hardware debug pads'; Id = 'R34'; Sub = 'hardware-security/SKILL.md' },
    @{ N = 'db'; H = 'database security mysql postgres redis'; Id = 'R35'; Sub = 'database-security/SKILL.md' },
    @{ N = 'email'; H = 'phishing spf dkim dmarc email security'; Id = 'R36'; Sub = 'email-security/SKILL.md' },
    @{ N = 'sso'; H = 'saml oidc sso federation'; Id = 'R37'; Sub = 'identity-federation/SKILL.md' },
    @{ N = 'sdr'; H = 'sdr hackrf gnu radio rf'; Id = 'R38'; Sub = 'radio-sdr/SKILL.md' }
)
foreach ($c in $cases) {
    $out = Join-Path $ScratchDir ("route-{0}" -f $c.N)
    $stdout = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $masterRoute -Hint $c.H -OutDir $out 2>&1 | Out-String
    $stdout | Set-Content -LiteralPath (Join-Path $ScratchDir ("route-{0}.txt" -f $c.N)) -Encoding UTF8
    $scope = Join-Path $out 'route-scope.md'
    if (-not (Test-Path $scope)) { Bad "no scope $($c.N)"; continue }
    $text = Get-Content $scope -Raw -Encoding UTF8
    $parsed = Get-ReverseRouteScopeFields -Text $text
    if ($parsed.Id -ne $c.Id) { Bad "$($c.N) id want $($c.Id) got $($parsed.Id)" } else { Ok "$($c.N) -> $($c.Id)" }
    $abs = Join-Path $skillsRoot ($c.Sub -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $abs)) { Bad "missing $($c.Sub)" } else { Ok "exists $($c.Sub)" }
}

# default outdir under work
$def = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $masterRoute -Hint 'radare2 analyze' 2>&1 | Out-String
$def | Set-Content (Join-Path $ScratchDir 'default-out.txt') -Encoding UTF8
if ($def -match 'work[\\/]master-route-') { Ok 'default OutDir under work/' } else { Bad 'default OutDir not under work/' }

# project-root output must stay with the analysis project when the skill is invoked elsewhere
$projectRoot = Join-Path $ScratchDir 'analysis-project'
New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
$projectRoute = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $masterRoute `
    -Hint 'radare2 analyze' -ProjectRoot $projectRoot 2>&1 | Out-String
$projectWork = Join-Path $projectRoot 'work'
$projectRouteDirs = @(Get-ChildItem -LiteralPath $projectWork -Directory -Filter 'master-route-*' -ErrorAction SilentlyContinue)
if ($projectRouteDirs.Count -eq 1 -and (Test-Path (Join-Path $projectRouteDirs[0].FullName 'route-scope.md'))) {
    Ok 'explicit ProjectRoot keeps route artifacts in analysis project'
} else {
    Bad 'explicit ProjectRoot did not receive route artifacts'
}

$defaultProjectRoot = Join-Path $ScratchDir 'default-analysis-project'
New-Item -ItemType Directory -Force -Path $defaultProjectRoot | Out-Null
$previousLocation = Get-Location
try {
    Set-Location -LiteralPath $defaultProjectRoot
    $defaultProjectRoute = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $masterRoute `
        -Hint 'radare2 analyze' 2>&1 | Out-String
} finally {
    Set-Location -LiteralPath $previousLocation
}
$defaultProjectWork = Join-Path $defaultProjectRoot 'work'
$defaultProjectRoutes = @(Get-ChildItem -LiteralPath $defaultProjectWork -Directory -Filter 'master-route-*' -ErrorAction SilentlyContinue)
if ($defaultProjectRoutes.Count -eq 1 -and (Test-Path (Join-Path $defaultProjectRoutes[0].FullName 'route-scope.md'))) {
    Ok 'default route artifacts follow the caller project'
} else {
    Bad 'default route artifacts did not follow the caller project'
}

# case-init real path
$caseName = 'verify-ops-' + (Get-Date -Format 'HHmmss')
$ci = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $caseInit -Hint 'apk jadx reverse' -CaseName $caseName -PackageRoot $packageRoot 2>&1 | Out-String
$ci | Set-Content (Join-Path $ScratchDir 'case-init.txt') -Encoding UTF8
$caseRoot = Join-Path $packageRoot ("work/{0}" -f $caseName)
foreach ($f in @('scope.md', 'timeline.md', 'workitems.md')) {
    $fp = Join-Path $caseRoot $f
    if (Test-Path $fp) { Ok "case-init $f" } else { Bad "case-init missing $f" }
}
if (Test-Path (Join-Path $caseRoot 'scope.md')) {
    $sc = Get-Content (Join-Path $caseRoot 'scope.md') -Raw -Encoding UTF8
    foreach ($k in @('auth', 'network_profile', 'in_scope', 'ready_for_act')) {
        if ($sc -match $k) { Ok "case scope has $k" } else { Bad "case scope missing $k" }
    }
}

$projectCaseName = 'verify-project-root-' + (Get-Date -Format 'HHmmss')
& $HostExe -NoProfile -ExecutionPolicy Bypass -File $caseInit `
    -Hint 'apk jadx reverse' -CaseName $projectCaseName -PackageRoot $packageRoot `
    -ProjectRoot $projectRoot 2>&1 | Out-Null
$projectCaseRoot = Join-Path $projectWork $projectCaseName
if ((Test-Path (Join-Path $projectCaseRoot 'scope.md')) -and
    (Test-Path (Join-Path $projectCaseRoot 'timeline.md')) -and
    (Test-Path (Join-Path $projectCaseRoot 'workitems.md'))) {
    Ok 'explicit ProjectRoot keeps case artifacts in analysis project'
} else {
    Bad 'explicit ProjectRoot did not receive case artifacts'
}

$defaultCaseName = 'verify-default-project-' + (Get-Date -Format 'HHmmss')
try {
    Set-Location -LiteralPath $defaultProjectRoot
    & $HostExe -NoProfile -ExecutionPolicy Bypass -File $caseInit `
        -Hint 'apk jadx reverse' -CaseName $defaultCaseName 2>&1 | Out-Null
} finally {
    Set-Location -LiteralPath $previousLocation
}
$defaultCaseRoot = Join-Path (Join-Path $defaultProjectRoot 'work') $defaultCaseName
if ((Test-Path (Join-Path $defaultCaseRoot 'scope.md')) -and
    (Test-Path (Join-Path $defaultCaseRoot 'timeline.md')) -and
    (Test-Path (Join-Path $defaultCaseRoot 'workitems.md'))) {
    Ok 'default case artifacts follow the caller project'
} else {
    Bad 'default case artifacts did not follow the caller project'
}

# ghost dsl
foreach ($rel in @('SKILL.md', 'routing.md', 'MASTER-ROUTING.md', 'scripts\master-route.ps1')) {
    $p = Join-Path $skillsRoot $rel
    if (-not (Test-Path $p)) { continue }
    $t = Get-Content $p -Raw -Encoding UTF8
    if ($t -match '`dsl-vm-reverse/' -and $t -notmatch 'reverse-engineering/dsl-vm-reverse') {
        Bad "ghost dsl path in $rel"
    }
}
Ok 'ghost dsl scan done'

# refresh-tool-index parses
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $scriptDir 'refresh-tool-index.ps1'), [ref]$null, [ref]$e)
if ($e -and $e.Count -gt 0) { Bad ("refresh-tool-index parse: {0}" -f $e[0]) } else { Ok 'refresh-tool-index parses' }

# --- bootstrap-manifest parity (skills vs kali) ---
$skillsManifest = Join-Path $scriptDir 'bootstrap-manifest.json'
$kaliManifest = Join-Path $packageRoot 'kali/scripts/bootstrap-manifest.json'
$skillsCaps = @()
if (Test-Path -LiteralPath $skillsManifest) {
    $sm = Get-Content -LiteralPath $skillsManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $skillsCaps = @($sm.capabilities | ForEach-Object { $_.name })
    if ($skillsCaps.Count -ge 10) { Ok "skills manifest $($skillsCaps.Count) capabilities" } else { Bad 'skills manifest capability count suspicious' }
} else {
    Bad 'skills bootstrap-manifest.json missing'
}
if (Test-Path -LiteralPath $kaliManifest) {
    $km = Get-Content -LiteralPath $kaliManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $kaliCaps = @($km.capabilities | ForEach-Object { $_.name })
    foreach ($missing in ($skillsCaps | Where-Object { $_ -notin $kaliCaps })) {
        Bad "kali manifest missing capability: $missing"
    }
    foreach ($missing in ($kaliCaps | Where-Object { $_ -notin $skillsCaps })) {
        Ok "kali-only capability: $missing"
    }
} else {
    Bad 'kali bootstrap-manifest.json missing'
}

# --- supply-chain pin gate: auto-install download sources MUST be pinned ---
# 统一判定：pinnedVersion / pinnedCommit / pinPolicy 三选一；
# github-release-* 额外接受 assetSha256 / preferApiDigest（GitHub 官方发布资产哈希）。
# local-http-mcp 只有在不获取外部源码时才可免 pin。
$pinKinds = @('pip-package', 'npm-mcp', 'npm-global', 'go-install', 'git-clone')
foreach ($mf in @($skillsManifest, $kaliManifest)) {
    if (-not (Test-Path -LiteralPath $mf)) { continue }
    $mn = Split-Path $mf -Leaf
    $mc = Get-Content -LiteralPath $mf -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($dependencyProperty in @($mc.bootstrapDependencies.PSObject.Properties)) {
        $dependency = $dependencyProperty.Value
        $expectedSuffix = '(?:==|@)' + [regex]::Escape([string]$dependency.version) + '$'
        if ([string]::IsNullOrWhiteSpace([string]$dependency.package) -or
            [string]::IsNullOrWhiteSpace([string]$dependency.version) -or
            [string]$dependency.package -notmatch $expectedSuffix) {
            Bad "unpinned bootstrap dependency: $($dependencyProperty.Name) in $mn"
        } else {
            Ok "pinned bootstrap dependency $($dependencyProperty.Name) in $mn"
        }
    }
    foreach ($cap in $mc.capabilities) {
        $capMap = @{}
        foreach ($prop in $cap.PSObject.Properties) { $capMap[$prop.Name] = $prop.Value }
        if (-not $capMap['canAutoInstall']) { continue }
        $hasPin = ($capMap['pinnedVersion'] -or $capMap['pinnedCommit'] -or $capMap['pinPolicy'])
        switch ($capMap['bootstrapKind']) {
            'github-release-zip' { $hasPin = $hasPin -or $capMap['assetSha256'] -or $capMap['preferApiDigest'] }
            'github-release-jar-wrapper' { $hasPin = $hasPin -or $capMap['assetSha256'] }
            'github-release-tar' { $hasPin = $hasPin -or $capMap['assetSha256'] -or $capMap['preferApiDigest'] }
            'local-http-mcp' {
                $fetchesExternalSource = $capMap['repoUrl'] -or $capMap['repo']
                $hasPin = (-not $fetchesExternalSource) -or $capMap['pinnedCommit'] -or $capMap['pinnedVersion']
            }
            'remote-http-mcp' {
                $hasPin = (-not $capMap['repoUrl']) -and (-not $capMap['repo']) -and $capMap['pinPolicy']
            }
            'winget-package' { $hasPin = $hasPin } # winget-latest 属于 pinPolicy
            'apt-package' { $hasPin = $true }      # 发行版仓库自带（Kali 侧）
            'docker-image' { $hasPin = $true }     # fallback 通道
            'manual' { $hasPin = $true }           # 手工安装
            default { $hasPin = $hasPin }
        }
        if (-not $hasPin) {
            Bad "unpinned auto-install capability: $($capMap['name']) in $mn ($($capMap['bootstrapKind']))"
        } else {
            Ok "pinned $($capMap['name']) in $mn"
        }
    }
}

# identity: no FastAPI/React requirement in ops IDENTITY
$id = Get-Content (Join-Path $skillsRoot 'ops/IDENTITY.md') -Raw -Encoding UTF8
if ($id -match '不是|不做|NOT|not a Z3r0|FastAPI|React') { Ok 'identity distinguishes platform' } else { Bad 'identity weak' }
if ($id -match 'tool-index|bootstrap|field-journal|路由') { Ok 'identity keeps reverse-skill DNA' } else { Bad 'identity missing DNA' }

$idCheck = @()
$idCheck += "HEAD packageRoot=$packageRoot"
$idCheck += "fastapi-in-ops-deps=false"
$idCheck -join [Environment]::NewLine | Set-Content (Join-Path $ScratchDir 'identity-check.txt') -Encoding UTF8
Ok 'identity-check written'

# Decision-delta / genuine-decision-boundary contract
$transitionContract = Join-Path $PackageRoot "skills/ops/timeline-workitem.md"
if (Test-Path -LiteralPath $transitionContract) {
    $transitionText = Get-Content -LiteralPath $transitionContract -Raw -Encoding UTF8
    if ($transitionText -like "*decision_delta*" -and $transitionText -like "*carry_forward_refs*") { Ok "timeline transition has delta-by-reference contract" } else { Bad "timeline transition missing delta-by-reference contract" }
    if ($transitionText -like "*authoritative state*" -and $transitionText -like "*MUST NOT*" -and $transitionText -like "*genuine decision boundary*") { Ok "timeline contract forbids unchanged context re-materialization" } else { Bad "timeline contract missing unchanged-context boundary" }
} else { Bad "timeline-workitem.md missing" }
$masterSkillText = Get-Content -LiteralPath (Join-Path $PackageRoot "skills/SKILL.md") -Raw -Encoding UTF8
if ($masterSkillText -like "*genuine decision boundary*" -and $masterSkillText -like "*decision_delta*" -and $masterSkillText -like "*carry_forward_refs*") { Ok "master skill gates menus on genuine decisions" } else { Bad "master skill missing genuine decision boundary contract" }
$routingText = Get-Content -LiteralPath (Join-Path $PackageRoot "skills/routing.md") -Raw -Encoding UTF8
if ($routingText -like "*genuine decision boundary*" -and $routingText -notlike "*Always provide a next-step menu*") { Ok "routing ambiguity path no longer forces unconditional menu" } else { Bad "routing still forces unconditional next-step menu" }
$contribText = Get-Content -LiteralPath (Join-Path $PackageRoot "skills/CONTRIBUTING.md") -Raw -Encoding UTF8
if ($contribText -like "*genuine decision boundary*" -and $contribText -notlike "*每个阶段结束时提供 3-6 个编号*") { Ok "new-skill contract uses genuine decision boundaries" } else { Bad "new-skill contract still requires per-stage menus" }
$reWorkflowText = Get-Content -LiteralPath (Join-Path $PackageRoot "skills/reverse-engineering/references/re-agent-workflow.md") -Raw -Encoding UTF8
if ($reWorkflowText -like "*decision_delta*" -and $reWorkflowText -like "*carry_forward_refs*" -and $reWorkflowText -like "*consumer 必须先继承 refs*") { Ok "representative RE workflow consumes delta by reference" } else { Bad "representative RE workflow missing delta consumer contract" }

# Issue #77 — analysis decision framework anchors (MUST run before fail gate)
$adf = Join-Path $PackageRoot "skills/ops/analysis-decision-framework.md"
if (Test-Path -LiteralPath $adf) { Ok "analysis-decision-framework.md present (issue #77)" } else { Bad "analysis-decision-framework.md missing (issue #77)" }
if (Test-Path -LiteralPath $adf) {
    $adfText = Get-Content -LiteralPath $adf -Raw -Encoding UTF8
    foreach ($pair in @(
        @("R4*", "ADF R4* validated sufficiency"),
        @("E-insufficient-evidence", "ADF E-insufficient-evidence"),
        @("E-hypothesis-confirmed", "ADF hypothesis evidence"),
        @("ungrounded", "ADF ungrounded flag"),
        @("Not** a second master", "ADF not second master workflow"),
        @("analysis-blindspot-cookbook", "ADF links blindspot cookbook")
    )) {
        if ($adfText -like ("*" + $pair[0] + "*")) { Ok $pair[1] } else { Bad ("missing: " + $pair[1]) }
    }
}
$efp77 = Join-Path $PackageRoot "skills/ops/evidence-finding-path.md"
if (Test-Path -LiteralPath $efp77) {
    $efpText = Get-Content -LiteralPath $efp77 -Raw -Encoding UTF8
    if ($efpText -like "*analysis-decision-framework*") { Ok "evidence-finding-path hooks ADF" } else { Bad "evidence-finding-path missing ADF hook" }
    if ($efpText -like "*E-insufficient-evidence*") { Ok "evidence-finding-path R4* id" } else { Bad "evidence-finding-path missing E-insufficient-evidence" }
} else { Bad "evidence-finding-path.md missing" }
$wf77 = Join-Path $PackageRoot "skills/reverse-engineering/references/re-agent-workflow.md"
if (Test-Path -LiteralPath $wf77) {
    $wfText = Get-Content -LiteralPath $wf77 -Raw -Encoding UTF8
    if ($wfText -like "*analysis-decision-framework*") { Ok "re-agent-workflow hooks ADF" } else { Bad "re-agent-workflow missing ADF hook" }
    if ($wfText -like "*analysis-blindspot-cookbook*") { Ok "re-agent-workflow hooks blindspot cookbook" } else { Bad "re-agent-workflow missing blindspot cookbook hook" }
} else { Bad "re-agent-workflow.md missing" }
$rules77 = Join-Path $PackageRoot "RULES.md"
if (Test-Path -LiteralPath $rules77) {
    $rulesText = Get-Content -LiteralPath $rules77 -Raw -Encoding UTF8
    if ($rulesText -like "*analysis-decision-framework*") { Ok "RULES.md hooks ADF" } else { Bad "RULES.md missing ADF hook" }
} else { Bad "RULES.md missing" }

# Issue #77 batch 2 — blindspot cookbook anchors
$bsc = Join-Path $PackageRoot "skills/ops/analysis-blindspot-cookbook.md"
if (Test-Path -LiteralPath $bsc) { Ok "analysis-blindspot-cookbook.md present (issue77 R52-R81)" } else { Bad "analysis-blindspot-cookbook.md missing (issue77 R52-R81)" }
if (Test-Path -LiteralPath $bsc) {
    $bscText = Get-Content -LiteralPath $bsc -Raw -Encoding UTF8
    foreach ($pair in @(
        @("R52", "BSC R52 Rust"),
        @("E-rust-identified", "BSC E-rust-identified"),
        @("E-vmp-protected", "BSC E-vmp-protected"),
        @("E-llm-hallucination", "BSC E-llm-hallucination"),
        @("E-kernel-protect-tamper", "BSC kernel detect-only id"),
        @("Not** a third master", "BSC not third master workflow"),
        @("no bypass tutorial", "BSC no bypass tutorial")
    )) {
        if ($bscText -like ("*" + $pair[0] + "*")) { Ok $pair[1] } else { Bad ("missing: " + $pair[1]) }
    }
}

Write-Host "Scratch=$ScratchDir"
if ($fail.Count -gt 0) {
    Write-Host ("FAILED {0}" -f $fail.Count) -ForegroundColor Red
    $fail | ForEach-Object { Write-Host " - $_" }
    $fail | Set-Content (Join-Path $ScratchDir 'failures.txt') -Encoding UTF8
    exit 1
}
Write-Host 'ALL ROUTING COHERENCE CHECKS PASSED' -ForegroundColor Green
'ALL ROUTING COHERENCE CHECKS PASSED' | Set-Content (Join-Path $ScratchDir 'verify.txt') -Encoding UTF8
exit 0
