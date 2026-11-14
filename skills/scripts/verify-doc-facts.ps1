<#
.SYNOPSIS
  Verify doc fact tables (capability lists, MCP ports, Burp tool count)
  against source-of-truth (bootstrap-manifest.json / McpHttpServer.java).

.DESCRIPTION
  P1-4 guard: RULES.md / RULES_zh.md / skills/SKILL.md fact tables must not
  drift from the manifest and the Burp extension source. Exit 1 on mismatch.
#>
$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fail = 0

function Check([string]$Name, [bool]$Ok, [string]$Detail) {
  if ($Ok) { Write-Host "OK   $Name" } else { $script:fail++; Write-Host "FAIL $Name : $Detail" }
}

# --- Source of truth: manifest ---
$manifestPath = Join-Path $Root 'skills\scripts\bootstrap-manifest.json'
$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$capNames = @($manifest.capabilities | ForEach-Object { $_.name } | Sort-Object)

# --- Source of truth: Burp getToolList() ---
$javaPath = Join-Path $Root 'burp-mcp-full\src\main\java\com\burpmcp\McpHttpServer.java'
$java = Get-Content $javaPath -Raw
$def = [regex]::Match($java, 'String\s+getToolList\s*\([^)]*\)\s*\{')
if (-not $def.Success) { throw 'getToolList() not found in McpHttpServer.java' }
$endIdx = $java.IndexOf("`n    }", $def.Index)
$body = $java.Substring($def.Index, $endIdx - $def.Index)
$burpTools = @([regex]::Matches($body, '\\"([a-z_0-9]+)\\"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$burpCount = $burpTools.Count

Write-Host "source-of-truth: $($capNames.Count) capabilities, Burp getToolList = $burpCount tools"

# --- Doc helpers ---
function Get-ListLine([string]$Text, [string]$Marker) {
  $lines = $Text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match [regex]::Escape($Marker)) {
      $inline = [regex]::Match($lines[$i], '）：(.+?)\s*$')
      if ($inline.Success) { return $inline.Groups[1].Value }
      if ($i + 1 -lt $lines.Count) { return $lines[$i + 1] }
    }
  }
  return ''
}

function Test-ListHasAll([string]$ListText, [string[]]$Names) {
  $tokens = @($ListText -split '[、,]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($tokens.Count -ne $Names.Count) { return $false }
  foreach ($n in $Names) { if ($tokens -notcontains $n) { return $false } }
  return $true
}

$rulesEn = Get-Content (Join-Path $Root 'RULES.md') -Raw -Encoding UTF8
$rulesZh = Get-Content (Join-Path $Root 'RULES_zh.md') -Raw -Encoding UTF8
$skillMd = Get-Content (Join-Path $Root 'skills\SKILL.md') -Raw -Encoding UTF8

$enList = Get-ListLine $rulesEn 'Supported capability names'
$zhList = Get-ListLine $rulesZh '支持的能力名'
$skList = Get-ListLine $skillMd '支持的能力'

Check 'RULES.md capability list' (Test-ListHasAll $enList $capNames) "expected $($capNames.Count) capabilities: $($capNames -join ', ')"
Check 'RULES_zh.md capability list' (Test-ListHasAll $zhList $capNames) "expected $($capNames.Count) capabilities"
Check 'SKILL.md capability list' (Test-ListHasAll $skList $capNames) "expected $($capNames.Count) capabilities"
Check 'RULES_zh.md count text' ($rulesZh.Contains("共 $($capNames.Count) 项")) "expected 共 $($capNames.Count) 项"

# --- MCP ports from manifest servicePort / servicePortRange ---
foreach ($c in $manifest.capabilities) {
  if (-not $c.PSObject.Properties['servicePort']) { continue }
  $port = [string]$c.servicePort
  Check "RULES.md port $($c.name)=$port" ($rulesEn.Contains($port)) "missing port $port for $($c.name)"
  Check "RULES_zh.md port $($c.name)=$port" ($rulesZh.Contains($port)) "missing port $port for $($c.name)"
  if ($c.PSObject.Properties['servicePortRange']) {
    $range = @($c.servicePortRange) -join '-'
    Check "RULES.md range $($c.name)=$range" ($rulesEn.Contains($range)) "missing range $range for $($c.name)"
    Check "RULES_zh.md range $($c.name)=$range" ($rulesZh.Contains($range)) "missing range $range for $($c.name)"
  }
}

# --- Burp tool count ---
Check 'RULES.md burp tool count' ($rulesEn.Contains("$burpCount-tool")) "expected '$burpCount-tool' in RULES.md"
Check 'RULES_zh.md burp tool count' ($rulesZh.Contains("$burpCount 工具全控制")) "expected '$burpCount 工具全控制' in RULES_zh.md"

# --- Routing benchmark case count (derived, not hardcoded) ---
$bmPath = Join-Path $Root 'skills\tests\routing-benchmark.json'
$bm = Get-Content $bmPath -Raw -Encoding UTF8 | ConvertFrom-Json
$caseCount = @($bm.cases).Count
Write-Host "source-of-truth: routing-benchmark cases = $caseCount"

$readmeEn = Get-Content (Join-Path $Root 'README.md') -Raw -Encoding UTF8
$readmeZh = Get-Content (Join-Path $Root 'README_zh.md') -Raw -Encoding UTF8
$relCheck = Get-Content (Join-Path $Root 'docs\RELEASE-CHECKLIST.md') -Raw -Encoding UTF8

Check 'README.md case count' ($readmeEn.Contains("$caseCount cases") -and $readmeEn.Contains("$caseCount benchmark cases") -and $readmeEn.Contains("$caseCount (hint")) "expected '$caseCount cases' / '$caseCount benchmark cases' / '$caseCount (hint' in README.md"
Check 'README_zh.md case count' ($readmeZh.Contains("$caseCount 条用例") -and $readmeZh.Contains("$caseCount 条路由回归基准") -and $readmeZh.Contains("（$caseCount 条）")) "expected $caseCount 条用例 / $caseCount 条路由回归基准 / （$caseCount 条） in README_zh.md"
Check 'RELEASE-CHECKLIST case count' ($relCheck.Contains("routing $caseCount 基准")) "expected 'routing $caseCount 基准' in docs/RELEASE-CHECKLIST.md"

Write-Host "verify-doc-facts: $fail failure(s)"
if ($fail -gt 0) { exit 1 }
