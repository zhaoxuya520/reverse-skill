#Requires -Version 5.1
# Initialize work/<case>/ with scope, timeline, workitems (reverse-skill ops contract).
# Bare invocation keeps pending/offline defaults.
# Ready-to-act example:
#   powershell -File skills/scripts/case-init.ps1 -Hint "web pentest" -CaseName my-case `
#     -AuthGranted -TargetUrl "https://app.example/" -NetworkProfile authorized_target_only
param(
    [string] $Hint = '',
    [string] $CaseName = '',
    [string] $PackageRoot = '',
    [switch] $AuthGranted,
    [string] $AuthStatus = '',
    [string] $AuthBasis = 'own_system',
    [string] $EvidenceOfAuth = '',
    [string] $TargetUrl = '',
    [string[]] $InScopeAssets = @(),
    [string] $NetworkProfile = '',
    [switch] $ReadyForAct
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $skillsRoot }

if (-not $CaseName) {
    $slug = if ($Hint) {
        ($Hint.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    } else { 'case' }
    if ($slug.Length -gt 32) { $slug = $slug.Substring(0, 32).TrimEnd('-') }
    $CaseName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $slug
}

$caseRoot = Join-Path $PackageRoot ("work\{0}" -f $CaseName)
$dirs = @('evidence', 'notes', 'report')
New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $caseRoot $d) | Out-Null
}

# Resolve auth / network / assets
# Priority: explicit -AuthStatus (only if bound) > -AuthGranted > pending.
# Never let a stray positional string overwrite AuthGranted.
$authStatusResolved = 'pending'
if ($AuthGranted) { $authStatusResolved = 'granted' }
if ($PSBoundParameters.ContainsKey('AuthStatus') -and -not [string]::IsNullOrWhiteSpace($AuthStatus)) {
    $candidate = $AuthStatus.Trim().ToLowerInvariant()
    $allowedAuth = @('pending', 'granted', 'denied', 'unknown')
    if ($allowedAuth -contains $candidate) {
        $authStatusResolved = $candidate
    } else {
        Write-Host ("WARN: ignoring invalid -AuthStatus '{0}' (allowed: pending|granted|denied|unknown)" -f $AuthStatus) -ForegroundColor Yellow
        # if user also passed AuthGranted, keep granted; else stay pending
    }
}

$evidenceAuth = if (-not [string]::IsNullOrWhiteSpace($EvidenceOfAuth)) {
    $EvidenceOfAuth
} elseif ($AuthGranted -or $authStatusResolved -eq 'granted') {
    'cli-flag AuthGranted or AuthStatus=granted'
} else {
    'FILL_ME'
}

$assets = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($TargetUrl)) { [void]$assets.Add($TargetUrl.Trim()) }
foreach ($a in @($InScopeAssets)) {
    if (-not [string]::IsNullOrWhiteSpace($a) -and -not $assets.Contains($a.Trim())) {
        [void]$assets.Add($a.Trim())
    }
}
# Also accept host-only tokens that look like domains/IPs from TargetUrl leftovers
if ($assets.Count -eq 0 -and $Hint -match 'https?://([^\s/]+)') {
    [void]$assets.Add(('https://{0}/' -f $Matches[1]))
}

$networkMode = 'offline'
if (-not [string]::IsNullOrWhiteSpace($NetworkProfile)) {
    $networkMode = $NetworkProfile.Trim()
} elseif ($assets.Count -gt 0 -and $authStatusResolved -eq 'granted') {
    # training labs / intentional vulns often use lab_only; default authorized_target_only
    $networkMode = 'authorized_target_only'
}
# normalize common aliases
$netAliases = @{
    'lab' = 'lab_only'
    'authorized' = 'authorized_target_only'
    'auth' = 'authorized_target_only'
    'offline_only' = 'offline'
}
if ($netAliases.ContainsKey($networkMode.ToLowerInvariant())) {
    $networkMode = $netAliases[$networkMode.ToLowerInvariant()]
}

# ready_for_act requires auth granted + assets + non-offline network.
# -ReadyForAct cannot skip auth (would bypass hard gate).
$ready = $false
$netAllowsAct = ($networkMode -ne 'offline' -and -not [string]::IsNullOrWhiteSpace($networkMode))
if ($authStatusResolved -eq 'granted' -and $assets.Count -gt 0 -and $netAllowsAct) {
    $ready = $true
} elseif ($ReadyForAct) {
    if ($authStatusResolved -ne 'granted') {
        Write-Host 'WARN: -ReadyForAct ignored because auth.status is not granted' -ForegroundColor Yellow
    } elseif ($assets.Count -eq 0) {
        Write-Host 'WARN: -ReadyForAct ignored because in_scope.assets is empty' -ForegroundColor Yellow
    } elseif (-not $netAllowsAct) {
        Write-Host 'WARN: -ReadyForAct ignored because network_profile is offline/empty' -ForegroundColor Yellow
    }
}

# Optional master-route for primary skill
$primary = 'reverse-engineering/SKILL.md'
$primaryId = 'R0'
$routeScript = Join-Path $scriptDir 'master-route.ps1'
if ((Test-Path $routeScript) -and $Hint) {
    $tmp = Join-Path $env:TEMP ("case-init-route-" + [guid]::NewGuid().ToString('n'))
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $routeScript -Hint $Hint -OutDir $tmp 2>$null | Out-Null
        $scopeRoute = Join-Path $tmp 'route-scope.md'
        if (Test-Path $scopeRoute) {
            $rt = Get-Content $scopeRoute -Raw -Encoding UTF8
            if ($rt -match 'primary_skill:\s*skills/(\S+)') { $primary = $Matches[1] }
            if ($rt -match 'primary:\s*(\S+)') { $primaryId = $Matches[1] }
        }
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

$created = Get-Date -Format 'o'
if ($assets.Count -gt 0) {
    $assetsBlock = ($assets | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
} else {
    $assetsBlock = '  []'
}

$checkAuth = if ($authStatusResolved -eq 'granted') { '[x]' } else { '[ ]' }
$checkScope = if ($assets.Count -gt 0) { '[x]' } else { '[ ]' }
$checkNet = if ($networkMode -and $networkMode -ne '') { '[x]' } else { '[ ]' }
$readyStr = if ($ready) { 'true' } else { 'false' }
$timelineNext = if ($ready) {
    'open PRIMARY SKILL.md and ACT within scope'
} else {
    'fill scope auth + in_scope; set ready_for_act'
}
$timelineSummary = if ($ready) {
    'case directory created; scope ready_for_act=true'
} else {
    'case directory created; scope pending auth'
}

$scope = @"
# Case Scope

## meta
- case_id: $CaseName
- created: $created
- operator: local
- primary_skill: $primary
- primary_id: $primaryId
- lead_role: lead
- specialist_roles: []
- hint: $Hint

## auth
- status: $authStatusResolved
- basis: $AuthBasis
- evidence_of_auth: $evidenceAuth
- MUST NOT proceed if status != granted

## in_scope
- assets:
$assetsBlock
- surfaces: []
- activities: []

## out_of_scope
- assets: []
- activities: [dos, phishing_real_users, unrestricted_exfil]

## network_profile
- mode: $networkMode
- notes: |
    offline | lab_only | authorized_target_only | unrestricted_lab
    Change mode only after auth.status = granted.

## deliverables
- report: true
- field_journal: true
- diagrams: true
- timeline: true

## constraints
- timebox: {}
- stealth: low
- data_handling: anonymize

## signoff
- ready_for_act: $readyStr
- checklist:
  - $checkAuth auth.status = granted
  - $checkScope in_scope.assets non-empty OR offline sample path set
  - $checkNet network_profile.mode chosen
  - [ ] out_of_scope reviewed
  - [ ] roles assigned (see skills/ops/role-map.md)

## ops_refs
- skills/ops/scope-contract.md
- skills/ops/evidence-finding-path.md
- skills/ops/role-map.md
- skills/ops/timeline-workitem.md
- skills/ops/IDENTITY.md
"@

$timeline = @"
# Timeline (append-only)

## $created | lead | init
- action: case-init
- command_or_ref: skills/scripts/case-init.ps1
- result_summary: $timelineSummary
- artifacts: [scope.md, workitems.md]
- evidence_ids: []
- next: $timelineNext
"@

$workitems = @"
# Work Items

| ID | title | role | targets | surface | status | evidence | notes |
|----|-------|------|---------|---------|--------|----------|-------|
| WI-001 | Establish scope and auth | lead | case | process | in_progress | | |

## Coverage
- [ ] Recon/analysis complete for in_scope assets
- [ ] Critical/High candidates triaged (or N/A for pure RE)
- [ ] Validated findings have Evidence (E-*)
- [ ] Path documented (attack/call/solve)
- [ ] Timeline continuous across major phases
- [ ] Report via docs-generator
- [ ] field-journal anonymized

## Refs
- skills/ops/timeline-workitem.md
- skills/ops/evidence-finding-path.md
"@

$utf8 = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText((Join-Path $caseRoot 'scope.md'), $scope, $utf8)
[System.IO.File]::WriteAllText((Join-Path $caseRoot 'timeline.md'), $timeline, $utf8)
[System.IO.File]::WriteAllText((Join-Path $caseRoot 'workitems.md'), $workitems, $utf8)

$readmeNext = if ($ready) {
    @"
1. Scope is ready_for_act=true (auth granted + in_scope set)
2. Open primary skill: skills/$primary
3. Append ``timeline.md``; update ``workitems.md``
4. Append Evidence: ``skills/scripts/append-evidence.ps1 -CaseRoot <this dir> ...``
5. Promote findings with Evidence chain (skills/ops/evidence-finding-path.md)
6. Report via docs-generator; journal via field-journal
"@
} else {
    @"
1. Edit ``scope.md`` — set auth.status=granted and in_scope (or re-run with -AuthGranted -TargetUrl)
2. Set ready_for_act when checklist complete
3. Open primary skill: skills/$primary
4. Append ``timeline.md``; update ``workitems.md``
5. Promote findings with Evidence chain (skills/ops/evidence-finding-path.md)
6. Report via docs-generator; journal via field-journal
"@
}

$readme = @"
# Case $CaseName

$readmeNext
"@
[System.IO.File]::WriteAllText((Join-Path $caseRoot 'README.md'), $readme, $utf8)

Write-Host ("CASE -> {0}" -f $caseRoot) -ForegroundColor Green
Write-Host ("PRIMARY skill: skills/{0} ({1})" -f $primary, $primaryId)
Write-Host ("auth.status={0} network_profile={1} ready_for_act={2}" -f $authStatusResolved, $networkMode, $readyStr)
if ($ready) {
    Write-Host 'NEXT: open PRIMARY SKILL.md and ACT within scope' -ForegroundColor Green
} else {
    Write-Host 'NEXT: fill scope.md auth + in_scope; then open PRIMARY SKILL.md'
}
