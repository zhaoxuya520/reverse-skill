#Requires -Version 5.1
# Distill AGS .claude/skills into references/ags/*.md at a pinned commit.
# Distill = adapter header + strip duplicated Data Source / Compiled wiki footer.
# Taxonomy and workflows are kept verbatim. Do not add extra bans.
param(
    [string] $Commit = '',
    [string] $SourceRoot = '',
    [string] $DestRoot = ''
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$scriptDir = $PSScriptRoot
$skillRoot = Split-Path -Parent $scriptDir
if (-not $DestRoot) {
    $DestRoot = Join-Path $skillRoot 'references\ags'
}
New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

$pinPath = Join-Path $DestRoot 'UPSTREAM.txt'
$repo = 'gmh5225/awesome-game-security'
$pinCommit = 'bf403cf9e37f4c04f8c68a866fdd2a8f3054bfe2'
if (Test-Path -LiteralPath $pinPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($pinPath)) {
        if ($line -match '^repo=(.+)$') { $repo = $Matches[1].Trim() }
        if ($line -match '^commit=([0-9a-fA-F]+)$') { $pinCommit = $Matches[1].Trim() }
    }
}
if ($Commit) { $pinCommit = $Commit }

function Strip-DataSource([string] $text) {
    $markers = @("`n## Data Source", "`r`n## Data Source", "`n## Compiled wiki", "`r`n## Compiled wiki")
    $cut = $text.Length
    foreach ($m in $markers) {
        $i = $text.IndexOf($m)
        if ($i -ge 0 -and $i -lt $cut) { $cut = $i }
    }
    return $text.Substring(0, $cut).TrimEnd() + "`n"
}

function Rewrite-AgsLinks([string] $text) {
    $map = @{
        '../research-rigor/SKILL.md' = 'research-rigor.md'
        '../anti-cheat/SKILL.md' = 'anti-cheat.md'
        '../dma-attack/SKILL.md' = 'dma-attack.md'
        '../game-engine/SKILL.md' = 'game-engine.md'
        '../game-hacking/SKILL.md' = 'game-hacking.md'
        '../graphics-api/SKILL.md' = 'graphics-api.md'
        '../mobile-security/SKILL.md' = 'mobile-security.md'
        '../overview/SKILL.md' = 'overview.md'
        '../reverse-engineering/SKILL.md' = 'reverse-engineering.md'
        '../windows-kernel/SKILL.md' = 'windows-kernel.md'
    }
    foreach ($k in $map.Keys) {
        $text = $text.Replace($k, $map[$k])
    }
    return $text
}

function Adapter([string] $agsName, [string] $wiki, [string] $handoff) {
    $short = $pinCommit.Substring(0, [Math]::Min(12, $pinCommit.Length))
    return @"
> **reverse-skill adapter** - AGS ``$agsName`` under PRIMARY ``game-security/`` (routing **R43**). Not a second PRIMARY.
>
> **Pin:** ``$repo@$short`` (``$pinCommit``). Refresh: ``scripts/install-ags-refs.ps1``.
> **Gates that already exist (do not add more here):** reverse-skill ``case-init`` / ``auth.status=granted`` before ACT; AGS Ethical Use / authorized-testing text in this file if the upstream skill has it.
> **Handoff:** $handoff
> **Fetch:** [fetch-upstream.md](fetch-upstream.md). Wiki: ``wiki/overviews/$wiki.md``.
> **Distill:** duplicated Data Source footer only. Taxonomy and workflows kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).

"@
}

function Get-AgsSkillText([string] $dir) {
    if ($SourceRoot) {
        $src = Join-Path $SourceRoot (Join-Path $dir 'SKILL.md')
        if (-not (Test-Path -LiteralPath $src)) { throw "missing local $src" }
        return [System.IO.File]::ReadAllText($src)
    }
    $url = "https://raw.githubusercontent.com/$repo/$pinCommit/.claude/skills/$dir/SKILL.md"
    Write-Host "FETCH $url"
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("ags-" + $dir + ".md")
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'reverse-skill-ags-pin')
    try {
        $wc.DownloadFile($url, $tmp)
    } finally {
        $wc.Dispose()
    }
    if (-not (Test-Path -LiteralPath $tmp)) { throw "download failed $url" }
    $len = (Get-Item -LiteralPath $tmp).Length
    if ($len -lt 200) { throw "download too small ($len bytes): $url" }
    return [System.IO.File]::ReadAllText($tmp)
}

$specs = @(
    @{ Dir = 'game-hacking'; Out = 'game-hacking.md'; Ags = 'game-hacking-techniques'; Wiki = 'game-hacking'
      Handoff = 'research rigor -> ``research-rigor.md`` + ``ops/evidence-finding-path.md``. Graphics overlay -> ``graphics-api.md``. DMA SSoT -> ``dma-attack.md``. Kernel ops -> ``windows-kernel.md`` then ``kernel-driver-reverse.md``. Engine dump -> ``../engines.md`` + ``../il2cpp-dump.md``.' }
    @{ Dir = 'anti-cheat'; Out = 'anti-cheat.md'; Ags = 'anti-cheat-systems'; Wiki = 'anti-cheat'
      Handoff = 'family-ID quick table (not this skill) -> ``../anti-cheat-families.md``. Kernel callbacks/IOCTL -> ``kernel-driver-reverse.md``. EDR-like stack -> ``edr-bypass-re/``. DMA detection SSoT -> ``dma-attack.md`` (AGS overlap in this file is kept; dma-attack.md wins on conflict).' }
    @{ Dir = 'dma-attack'; Out = 'dma-attack.md'; Ags = 'dma-attack-techniques'; Wiki = 'dma-attack'
      Handoff = 'this file is SSoT for pcileech / FPGA / IOMMU / DMA detection. AC mapping -> ``anti-cheat.md``. Kernel/IOMMU ops -> ``windows-kernel.md`` + ``kernel-driver-reverse.md``.' }
    @{ Dir = 'game-engine'; Out = 'game-engine.md'; Ags = 'game-engine-resources'; Wiki = 'game-engine'
      Handoff = 'RS dump-chain quick table (not this skill) -> ``../engines.md`` + ``../il2cpp-dump.md``. Mono -> ``dotnet-reverse/``. Native -> ``ida-reverse/`` / ``ghidra-reverse/``.' }
    @{ Dir = 'graphics-api'; Out = 'graphics-api.md'; Ags = 'graphics-api-hooking'; Wiki = 'graphics-api'
      Handoff = 'pairs with ``game-hacking.md``. Native RE -> ``ida-reverse/``.' }
    @{ Dir = 'mobile-security'; Out = 'mobile-security.md'; Ags = 'mobile-security'; Wiki = 'mobile-security'
      Handoff = 'unpack first -> ``apk-reverse/`` (Android) or ``mobile-reverse/`` (iOS), then return here. Dump chain -> ``../il2cpp-dump.md``.' }
    @{ Dir = 'overview'; Out = 'overview.md'; Ags = 'awesome-game-security-overview'; Wiki = 'overview'
      Handoff = 'hard-jump table is PRIMARY ``game-security/SKILL.md`` plus this file. Do not vendor the 4250-bullet README; fetch via ``fetch-upstream.md``.' }
    @{ Dir = 'research-rigor'; Out = 'research-rigor.md'; Ags = 'game-security-research-rigor'; Wiki = 'overview'
      Handoff = 'map Observation/Finding/Attribution/Decision onto ``ops/evidence-finding-path.md`` (Evidence->Finding->Path).' }
    @{ Dir = 'reverse-engineering'; Out = 'reverse-engineering.md'; Ags = 'reverse-engineering-tools'; Wiki = 'reverse-engineering'
      Handoff = 'operations: ``ida-reverse/`` ``ghidra-reverse/`` ``radare2/`` ``reverse-engineering/``. This file is the AGS game-RE catalog; ``../tools.md`` is only tool-index binding.' }
    @{ Dir = 'windows-kernel'; Out = 'windows-kernel.md'; Ags = 'windows-kernel-security'; Wiki = 'windows-kernel'
      Handoff = 'driver RE operations -> ``reverse-engineering/kernel-driver-reverse.md``. EDR-like AC analysis -> ``edr-bypass-re/``.' }
)

foreach ($s in $specs) {
    $raw = Get-AgsSkillText $s.Dir
    $body = Rewrite-AgsLinks (Strip-DataSource $raw)
    $head = Adapter $s.Ags $s.Wiki $s.Handoff
    $outPath = Join-Path $DestRoot $s.Out
    [System.IO.File]::WriteAllText($outPath, ($head + $body), $utf8)
    $bytes = (Get-Item -LiteralPath $outPath).Length
    Write-Host ("WROTE {0} ({1} bytes)" -f $s.Out, $bytes)
}

$overviewPath = Join-Path $DestRoot 'overview.md'
$overview = [System.IO.File]::ReadAllText($overviewPath)
$oldTable = @'
| Query topic | Primary skill | Related skills |
|---|---|---|
| EAC, BattlEye, Vanguard, detection, heartbeat, screenshot | anti-cheat | windows-kernel |
| pcileech, FPGA, DMA, IOMMU, Thunderbolt | dma-attack | anti-cheat |
| Unreal SDK, Unity IL2CPP, engine structs, Godot, Lumix | game-engine | game-hacking |
| Memory hacking, injection, overlays, driver comm, HWID spoof | game-hacking | graphics-api |
| D3D/Vulkan/OpenGL hooks, Present hook, shader interception | graphics-api | game-hacking |
| Android root, Frida, iOS jailbreak, KernelSU, APatch | mobile-security | game-hacking |
| IDA, Ghidra, DBI, deobfuscation, binary diffing, MCP RE tools, trap-and-emulate CFT, WHP tracing | reverse-engineering | anti-cheat, windows-kernel |
| Drivers, callbacks, PatchGuard, HVCI, ETW, pool forensics, WHP API | windows-kernel | anti-cheat, reverse-engineering |
| Claim validation, citation checks, detector evaluation, evidence conflicts | research-rigor | the matching domain skill |
| Adding resources, README format, link validation | overview | (any) |
'@
$newTable = @'
| Query topic | MUST open (full skill) | Related |
|---|---|---|
| EAC, BattlEye, Vanguard, detection, heartbeat, screenshot | [anti-cheat.md](anti-cheat.md) | [windows-kernel.md](windows-kernel.md) |
| pcileech, FPGA, DMA, IOMMU, Thunderbolt | [dma-attack.md](dma-attack.md) (SSoT) | [anti-cheat.md](anti-cheat.md) |
| Unreal SDK, Unity IL2CPP, engine structs, Godot, Lumix | [game-engine.md](game-engine.md) | [game-hacking.md](game-hacking.md) |
| Memory hacking, injection, overlays, driver comm, HWID spoof | [game-hacking.md](game-hacking.md) | [graphics-api.md](graphics-api.md) |
| D3D/Vulkan/OpenGL hooks, Present hook, shader interception | [graphics-api.md](graphics-api.md) | [game-hacking.md](game-hacking.md) |
| Android root, Frida, iOS jailbreak, KernelSU, APatch | [mobile-security.md](mobile-security.md) | [game-hacking.md](game-hacking.md) |
| IDA, Ghidra, DBI, deobfuscation, binary diffing, MCP RE tools, trap-and-emulate CFT, WHP tracing | [reverse-engineering.md](reverse-engineering.md) | anti-cheat, windows-kernel |
| Drivers, callbacks, PatchGuard, HVCI, ETW, pool forensics, WHP API | [windows-kernel.md](windows-kernel.md) | anti-cheat, reverse-engineering |
| Claim validation, citation checks, detector evaluation, evidence conflicts | [research-rigor.md](research-rigor.md) | the matching domain skill |
| Adding resources, README format, link validation | [overview.md](overview.md) | (any) |
'@
if ($overview.Contains($oldTable)) {
    $overview = $overview.Replace($oldTable, $newTable)
    [System.IO.File]::WriteAllText($overviewPath, $overview, $utf8)
    Write-Host 'PATCHED overview.md skill routing table to hard-jump links'
} else {
    Write-Host 'WARN overview routing table not patched (upstream format changed)'
}

$pinOut = @"
repo=$repo
commit=$pinCommit
pinned=2026-08-22
"@
[System.IO.File]::WriteAllText($pinPath, $pinOut, $utf8)
Write-Host ("OK dest=$DestRoot pin=$pinCommit")
