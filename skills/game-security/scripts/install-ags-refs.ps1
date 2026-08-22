#Requires -Version 5.1
# One-shot: distill AGS .claude/skills into references/ags/*.md
# Distill = adapter header + strip duplicated Data Source / Compiled wiki footer.
# Taxonomy and workflows are kept verbatim.
param(
    [string] $SourceRoot = 'C:\Users\Harry_win10\Desktop\_tmp-ags-skills',
    [string] $DestRoot = ''
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false

$scriptDir = $PSScriptRoot
if (-not $DestRoot) {
    $DestRoot = Join-Path (Split-Path -Parent $scriptDir) 'references\ags'
}
New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

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
    return @"
> **reverse-skill adapter** - AGS ``$agsName`` is installed as a first-class reference under PRIMARY ``game-security/`` (routing **R43**). This is not a second PRIMARY and not ``npx skills add``.
>
> **Auth:** ``case-init`` + ``auth.status=granted`` before ACT on a target. Technique catalog / threat-model / authorized-lab RE stay in scope.
> **Deliverable bound:** do not ship a live-title trainer / cheat product. Dump, observe-hook, copy-patch, AC RE, DMA/overlay/kernel catalogs remain required capabilities.
> **Handoff:** $handoff
> **Fetch links / wiki / archive:** [fetch-upstream.md](fetch-upstream.md). Upstream wiki overview: ``wiki/overviews/$wiki.md``.
> **Distill:** duplicated Data Source footer removed (one home in fetch-upstream.md). Taxonomy, workflows, and technique catalogs are kept.
>
> Source: [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) (MIT, Copyright 2022 gmh).

"@
}

$specs = @(
    @{ Dir = 'game-hacking'; Out = 'game-hacking.md'; Ags = 'game-hacking-techniques'; Wiki = 'game-hacking'
      Handoff = 'research rigor -> ``research-rigor.md`` + ``ops/evidence-finding-path.md``. Graphics overlay -> ``graphics-api.md``. DMA -> ``dma-attack.md``. Kernel ops -> ``windows-kernel.md`` then ``kernel-driver-reverse.md``. Engine dump -> ``../engines.md`` + ``../il2cpp-dump.md``.' }
    @{ Dir = 'anti-cheat'; Out = 'anti-cheat.md'; Ags = 'anti-cheat-systems'; Wiki = 'anti-cheat'
      Handoff = 'quick family-ID table -> ``../anti-cheat-families.md``. Kernel callbacks/IOCTL -> ``kernel-driver-reverse.md``. EDR-like stack -> ``edr-bypass-re/``. DMA detection depth -> ``dma-attack.md``.' }
    @{ Dir = 'dma-attack'; Out = 'dma-attack.md'; Ags = 'dma-attack-techniques'; Wiki = 'dma-attack'
      Handoff = 'defensive AC mapping -> ``anti-cheat.md``. Kernel/IOMMU ops on authorized sample -> ``windows-kernel.md`` + ``kernel-driver-reverse.md``. Live-title FPGA/pcileech against unauthorized games is out of deliverable scope.' }
    @{ Dir = 'game-engine'; Out = 'game-engine.md'; Ags = 'game-engine-resources'; Wiki = 'game-engine'
      Handoff = 'RS dump chain + tool-index -> ``../engines.md`` + ``../il2cpp-dump.md``. Mono assemblies -> ``dotnet-reverse/``. Native -> ``ida-reverse/`` / ``ghidra-reverse/``.' }
    @{ Dir = 'graphics-api'; Out = 'graphics-api.md'; Ags = 'graphics-api-hooking'; Wiki = 'graphics-api'
      Handoff = 'technique catalog pairs with ``game-hacking.md``. Present/overlay as threat-model or authorized-lab capture. Native RE -> ``ida-reverse/``.' }
    @{ Dir = 'mobile-security'; Out = 'mobile-security.md'; Ags = 'mobile-security'; Wiki = 'mobile-security'
      Handoff = 'unpack first -> ``apk-reverse/`` (Android) or ``mobile-reverse/`` (iOS), then return here for game-specific IL2CPP/root/Zygisk catalog. Dump chain -> ``../il2cpp-dump.md``.' }
    @{ Dir = 'overview'; Out = 'overview.md'; Ags = 'awesome-game-security-overview'; Wiki = 'overview'
      Handoff = 'local dispatch is this file + ``../INDEX.md``. Do not vendor the 4250-bullet README; fetch via ``fetch-upstream.md``.' }
    @{ Dir = 'research-rigor'; Out = 'research-rigor.md'; Ags = 'game-security-research-rigor'; Wiki = 'overview'
      Handoff = 'map Observation/Finding/Attribution/Decision onto ``ops/evidence-finding-path.md`` (Evidence->Finding->Path). Dest/leftover L1 rules stay in dest standing; do not promote sampler artifacts.' }
    @{ Dir = 'reverse-engineering'; Out = 'reverse-engineering.md'; Ags = 'reverse-engineering-tools'; Wiki = 'reverse-engineering'
      Handoff = 'operations: ``ida-reverse/`` ``ghidra-reverse/`` ``radare2/`` ``reverse-engineering/``. This file keeps the AGS game-RE tool/plugin/obfuscation catalog.' }
    @{ Dir = 'windows-kernel'; Out = 'windows-kernel.md'; Ags = 'windows-kernel-security'; Wiki = 'windows-kernel'
      Handoff = 'driver RE operations -> ``reverse-engineering/kernel-driver-reverse.md``. EDR-like AC analysis -> ``edr-bypass-re/``. This file keeps AGS kernel internals (callbacks, Segment Heap, HVCI, WHP).' }
)

foreach ($s in $specs) {
    $src = Join-Path $SourceRoot (Join-Path $s.Dir 'SKILL.md')
    if (-not (Test-Path -LiteralPath $src)) { throw "missing $src" }
    $raw = [System.IO.File]::ReadAllText($src)
    $body = Rewrite-AgsLinks (Strip-DataSource $raw)
    $head = Adapter $s.Ags $s.Wiki $s.Handoff
    $outPath = Join-Path $DestRoot $s.Out
    [System.IO.File]::WriteAllText($outPath, ($head + $body), $utf8)
    $bytes = (Get-Item -LiteralPath $outPath).Length
    Write-Host ("WROTE {0} ({1} bytes)" -f $s.Out, $bytes)
}

Write-Host "OK dest=$DestRoot"
