#Requires -Version 5.1
# Skill metadata contract: every SKILL.md declares a portable, globally unique name.
#
# A client that discovers two skills under one name keeps the first definition and
# silently skips the other, so a duplicate name is a functional loss, not a warning.
# Regression lock for the core router / Codex adapter collision (issue #163).
param(
    [string]$PackageRoot = ''
)
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$skillsRoot = Split-Path -Parent $scriptDir
if (-not $PackageRoot) { $PackageRoot = Split-Path -Parent $skillsRoot }

$fail = New-Object System.Collections.Generic.List[string]
function Ok($m) { Write-Host "[OK] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; [void]$fail.Add($m) }

# Declared frontmatter name, or $null when the file exposes no usable name.
function Get-SkillName($path) {
    $text = [System.IO.File]::ReadAllText($path) -replace "`r`n", "`n"
    if (-not $text.StartsWith("---`n")) { return $null }
    $end = $text.IndexOf("`n---", 3)
    if (-not $end -or $end -lt 0) { return $null }
    $front = $text.Substring(4, $end - 3)
    $m = [regex]::Match($front, '(?m)^name:[ \t]*(.+?)[ \t]*$')
    if (-not $m.Success) { return $null }
    $name = $m.Groups[1].Value.Trim()
    if (-not $name) { return $null }
    return $name
}

if (-not (Test-Path -LiteralPath $PackageRoot)) { throw "package root not found: $PackageRoot" }
$root = (Resolve-Path -LiteralPath $PackageRoot).ProviderPath.TrimEnd([char[]]@('\', '/'))

$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'SKILL.md' |
    Where-Object { $_.FullName -notmatch '[\\/][.]git[\\/]' } |
    Sort-Object FullName)
if ($files.Count -eq 0) { throw "no SKILL.md found under $root" }
Ok ("scanned {0} SKILL.md files under {1}" -f $files.Count, $root)

$byName = @{}
$byDir = @{}
$declared = 0
$coreRouter = $null

foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart([char[]]@('\', '/')) -replace '\\', '/'
    $dirName = Split-Path (Split-Path $f.FullName -Parent) -Leaf
    $name = Get-SkillName $f.FullName
    if (-not $name) {
        Bad ("{0} declares no YAML frontmatter name" -f $rel)
        continue
    }
    $declared++
    if ($name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        Bad ("{0} declares non-portable name '{1}' (expected lowercase kebab-case)" -f $rel, $name)
    }
    if (-not $byName.ContainsKey($name)) { $byName[$name] = @() }
    $byName[$name] = @($byName[$name]) + $rel
    if (-not $byDir.ContainsKey($dirName)) { $byDir[$dirName] = @() }
    $byDir[$dirName] = @($byDir[$dirName]) + $rel
    if ($rel -eq 'skills/SKILL.md') { $coreRouter = $name }
}

$dupNames = @($byName.Keys | Where-Object { $byName[$_].Count -gt 1 } | Sort-Object)
if ($dupNames.Count -eq 0) {
    Ok ("{0} declared skill names are unique across the repository" -f $declared)
} else {
    foreach ($n in $dupNames) {
        Bad ("duplicate skill name '{0}' declared by {1}" -f $n, ($byName[$n] -join ' and '))
    }
}

$dupDirs = @($byDir.Keys | Where-Object { $byDir[$_].Count -gt 1 } | Sort-Object)
if ($dupDirs.Count -eq 0) {
    Ok ("{0} skill directory names are unique across the repository" -f $byDir.Count)
} else {
    foreach ($d in $dupDirs) {
        Bad ("duplicate skill directory name '{0}' used by {1}" -f $d, ($byDir[$d] -join ' and '))
    }
}

# The core router keeps its published name on purpose: renaming it breaks every
# existing /skill:reverse-skill-router invocation, so it must stay deliberate.
if ($coreRouter -eq 'reverse-skill-router') {
    Ok 'skills/SKILL.md still publishes the core router name reverse-skill-router'
} else {
    Bad ("skills/SKILL.md publishes '{0}'; the core router must stay reverse-skill-router" -f $coreRouter)
}

if ($fail.Count -gt 0) {
    Write-Host ("FAILED {0}" -f $fail.Count) -ForegroundColor Red
    $fail | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Host 'ALL SKILL NAME CONTRACTS PASSED' -ForegroundColor Green
exit 0