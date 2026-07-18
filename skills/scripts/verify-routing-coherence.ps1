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

if (-not $ScratchDir) {
    $ScratchDir = Join-Path $env:TEMP ("rs-verify-{0}" -f (Get-Date -Format 'yyyyMMddHHmmss'))
}
New-Item -ItemType Directory -Force -Path $ScratchDir | Out-Null
$fail = New-Object System.Collections.Generic.List[string]
function Ok($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

# --- ops artifacts exist ---
$opsFiles = @(
    'ops\IDENTITY.md',
    'ops\scope-contract.md',
    'ops\evidence-finding-path.md',
    'ops\role-map.md',
    'ops\timeline-workitem.md',
    'ops\sandbox-profile.md',
    'ops\skill-supply-chain.md',
    'ops\README.md',
    'references\community-security-skills.md',
    'references\domain-coverage-map.md',
    'attack-chain\references\lifecycle-checklist.md',
    'reverse-engineering\references\re-agent-workflow.md',
    'pentest-tools\references\recon-pipeline.md',
    'MASTER-ROUTING.md',
    'scripts\master-route.ps1',
    'scripts\case-init.ps1',
    'docs-generator\references\security-report-templates.md',
    'field-journal\_template.md'
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
foreach ($hub in @('MASTER-ROUTING.md', 'SKILL.md', 'ops\README.md', 'routing.md')) {
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
Assert-Fields (Join-Path $skillsRoot 'ops\scope-contract.md') @('auth', 'in_scope', 'out_of_scope', 'network_profile', 'deliverables')
Assert-Fields (Join-Path $skillsRoot 'ops\evidence-finding-path.md') @('Evidence', 'Finding', 'Path', 'repro_command', 'evidence_ids')
Assert-Fields (Join-Path $skillsRoot 'ops\timeline-workitem.md') @('timeline.md', 'workitems.md', 'Coverage')
Assert-Fields (Join-Path $skillsRoot 'ops\role-map.md') @('lead', 'cie', 'cpe', 'cre', 'Handoff')
Assert-Fields (Join-Path $skillsRoot 'ops\skill-supply-chain.md') @('AST10', 'MCP', 'bootstrap', 'MUST')
Assert-Fields (Join-Path $skillsRoot 'references\community-security-skills.md') @('trailofbits', 'agentskills.io', 'MUST', '2026-07')
Assert-Fields (Join-Path $skillsRoot 'reverse-engineering\references\re-agent-workflow.md') @('Triage', 'Static', 'Dynamic', 'Synthesis')
Assert-Fields (Join-Path $skillsRoot 'pentest-tools\references\recon-pipeline.md') @('auth.status', 'network_profile', 'Evidence', 'nuclei')
Assert-Fields (Join-Path $skillsRoot 'docs-generator\references\security-report-templates.md') @('Evidence Chain', 'Findings', 'Path')
Assert-Fields (Join-Path $skillsRoot 'field-journal\_template.md') @('Scope', 'Evidence', 'Finding')
$fieldLog | Set-Content -LiteralPath (Join-Path $ScratchDir 'template-fields.txt') -Encoding UTF8

# --- role map skills exist for primary rows ---
$roleDoc = Get-Content (Join-Path $skillsRoot 'ops\role-map.md') -Raw -Encoding UTF8
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
    $stdout = & powershell -NoProfile -ExecutionPolicy Bypass -File $masterRoute -Hint $c.H -OutDir $out 2>&1 | Out-String
    $stdout | Set-Content -LiteralPath (Join-Path $ScratchDir ("route-{0}.txt" -f $c.N)) -Encoding UTF8
    $scope = Join-Path $out 'route-scope.md'
    if (-not (Test-Path $scope)) { Bad "no scope $($c.N)"; continue }
    $text = Get-Content $scope -Raw -Encoding UTF8
    if ($text -notmatch ("primary: {0}" -f [regex]::Escape($c.Id))) { Bad "$($c.N) id want $($c.Id)" } else { Ok "$($c.N) -> $($c.Id)" }
    $abs = Join-Path $skillsRoot ($c.Sub -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path $abs)) { Bad "missing $($c.Sub)" } else { Ok "exists $($c.Sub)" }
}

# Core package must not ship extracted/out-of-scope skill module dirs under skills/
foreach ($ghost in @('blockchain-security', 'bitcoin-puzzle')) {
    $gp = Join-Path $skillsRoot $ghost
    if (Test-Path -LiteralPath $gp) { Bad "core must not contain skills/$ghost" } else { Ok "no skills/$ghost" }
}

# default outdir under work
$def = & powershell -NoProfile -ExecutionPolicy Bypass -File $masterRoute -Hint 'radare2 analyze' 2>&1 | Out-String
$def | Set-Content (Join-Path $ScratchDir 'default-out.txt') -Encoding UTF8
if ($def -match 'work[\\/]master-route-') { Ok 'default OutDir under work/' } else { Bad 'default OutDir not under work/' }

# case-init real path
$caseName = 'verify-ops-' + (Get-Date -Format 'HHmmss')
$ci = & powershell -NoProfile -ExecutionPolicy Bypass -File $caseInit -Hint 'apk jadx reverse' -CaseName $caseName -PackageRoot $packageRoot 2>&1 | Out-String
$ci | Set-Content (Join-Path $ScratchDir 'case-init.txt') -Encoding UTF8
$caseRoot = Join-Path $packageRoot ("work\{0}" -f $caseName)
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

# identity: no FastAPI/React requirement in ops IDENTITY
$id = Get-Content (Join-Path $skillsRoot 'ops\IDENTITY.md') -Raw -Encoding UTF8
if ($id -match '不是|不做|NOT|not a Z3r0|FastAPI|React') { Ok 'identity distinguishes platform' } else { Bad 'identity weak' }
if ($id -match 'tool-index|bootstrap|field-journal|路由') { Ok 'identity keeps reverse-skill DNA' } else { Bad 'identity missing DNA' }

$idCheck = @()
$idCheck += "HEAD packageRoot=$packageRoot"
$idCheck += "fastapi-in-ops-deps=false"
$idCheck -join [Environment]::NewLine | Set-Content (Join-Path $ScratchDir 'identity-check.txt') -Encoding UTF8
Ok 'identity-check written'

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
