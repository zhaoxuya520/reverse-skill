#requires -Version 5
<#
.SYNOPSIS
  bootstrap-manifest.json 的结构回归（Windows / PowerShell 侧）。

.DESCRIPTION
  `test-bootstrap-manifest.sh` 测的是 bootstrap-reverse.sh 的 POSIX 沙箱行为，
  而那个脚本只有 Darwin / Linux 分支，在 Windows 上只能 SKIP。SKIP 意味着
  「这边没有覆盖」，不是「这边没问题」。

  本脚本补上 Windows 侧真正能测的那一半：**manifest 本身对不对**。
  它不执行安装、不联网、不写任何配置 —— 只按 bootstrap-reverse.ps1 里
  switch 分支实际读取的字段，逐个能力校验契约。

  为什么值得单独一个闸：2026-11-01 实测踩到过两个只有结构检查能提前发现的坑 ——
  ① 新加的 7 个脱壳工具只进了 catalog，没进 manifest，`refresh-tools.ps1 -Check`
     报「新装漏记 0」却是假的（工具压根不在探测范围）；
  ② `frida-dexdump` 标了 canAutoInstall=true 却没锁版本，撞上供应链断言。

  检查项
  ------
    1. JSON 合法、能力名不重复
    2. bootstrapKind 必须是 bootstrap-reverse.ps1 支持的种类
    3. 每种 kind 的必填字段齐（按脚本实际读取的字段推导，不另立一份词表）
    4. canAutoInstall=false 的能力必须带 manualInstallHint（否则用户拿不到下一步）
    5. 可自动安装的 pip / github-release 类必须锁版本或锁资产哈希（不锁 = 装到什么算什么）
    6. skills 与 kali 两份 manifest 的能力名必须对齐（kali 可多，不可少）

用法
    pwsh -NoProfile -File skills\scripts\test-bootstrap-manifest.ps1
    pwsh -NoProfile -File skills\scripts\test-bootstrap-manifest.ps1 -Verbose

退出码：0 = 全过，1 = 有失败。最后一行是 RESULT=<token>。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = $PSScriptRoot
$manifestPath = Join-Path $scriptDir 'bootstrap-manifest.json'
$bootstrapPs1 = Join-Path $scriptDir 'bootstrap-reverse.ps1'
$kaliManifest = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) 'kali\scripts\bootstrap-manifest.json'

$fail = New-Object System.Collections.Generic.List[string]
$pass = 0

function Ok([string]$msg) { Write-Host "  [OK]   $msg"; $script:pass++ }
function Bad([string]$msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:fail.Add($msg) }
function Info([string]$msg) { Write-Host "  [..]   $msg" -ForegroundColor DarkGray }

# --- 1. JSON 与重名 -------------------------------------------------------
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Bad "bootstrap-manifest.json 不存在：$manifestPath"
    Write-Host 'RESULT=bootstrap_manifest_fail'
    exit 1
}
try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Ok "manifest JSON 合法（$($manifest.capabilities.Count) 个能力）"
}
catch {
    Bad "manifest JSON 解析失败：$($_.Exception.Message)"
    Write-Host 'RESULT=bootstrap_manifest_fail'
    exit 1
}

$caps = @($manifest.capabilities)
$names = @($caps | ForEach-Object { [string]$_.name })
$dupes = @($names | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
if ($dupes.Count -eq 0) { Ok '能力名无重复' } else { Bad ("能力名重复：" + ($dupes -join ', ')) }

# --- 2. bootstrapKind 必须是脚本支持的种类 ---------------------------------
# 从脚本里现读 case 分支，不维护第二份名单：脚本加了新 kind，这里自动跟上。
$bootstrapSrc = Get-Content -LiteralPath $bootstrapPs1 -Raw -Encoding UTF8
$switchStart = $bootstrapSrc.IndexOf('switch ($definition.bootstrapKind)')
$switchEnd = $bootstrapSrc.IndexOf('Unsupported bootstrap kind')
if ($switchStart -lt 0 -or $switchEnd -lt 0) {
    Bad 'bootstrap-reverse.ps1 里找不到 bootstrapKind 的 switch 块（结构变了，本闸需要更新）'
    $supportedKinds = @()
}
else {
    $switchBlock = $bootstrapSrc.Substring($switchStart, $switchEnd - $switchStart)
    $supportedKinds = @([regex]::Matches($switchBlock, "(?m)^\s{8}'([a-z0-9-]+)' \{") |
        ForEach-Object { $_.Groups[1].Value })
    # 'manual' 走的是 canAutoInstall=false 的提前返回，不会进 switch，但它是一个合法写法
    $supportedKinds = @($supportedKinds + 'manual' | Sort-Object -Unique)
    Info ("脚本支持的 kind：" + ($supportedKinds -join ', '))
}

$badKind = @()
foreach ($cap in $caps) {
    $kind = [string]$cap.bootstrapKind
    if ([string]::IsNullOrWhiteSpace($kind)) { $badKind += "$($cap.name):(空)"; continue }
    if ($supportedKinds -notcontains $kind) { $badKind += "$($cap.name):$kind" }
}
if ($badKind.Count -eq 0) { Ok "所有能力都是脚本支持的 bootstrapKind" }
else { Bad ("不支持的 kind：" + ($badKind -join ', ')) }

# --- 3. 每种 kind 的必填字段 ----------------------------------------------
# 字段表按「脚本里实际读了什么」推导，避免词表分叉（这是本仓反复踩过的坑）。
$requiredByKind = @{
    'github-release-zip'          = @('repo', 'assetRegex', 'installDir')
    'git-clone'                   = @('repo', 'installDir', 'pinnedCommit')
    'github-release-jar-wrapper'  = @('repo', 'assetRegex', 'installDir')
    'pip-package'                 = @('pipPackage')
    'winget-package'              = @('wingetId')
    'npm-mcp'                     = @('mcpCommand', 'mcpNames')
    'remote-http-mcp'             = @('mcpUrl', 'mcpNames')
    'npm-global'                  = @('npmPackage')
    'local-http-mcp'              = @('mcpUrl', 'servicePort')
    'go-install'                  = @('goPackage')
    'manual'                      = @()
}

$missingFields = @()
foreach ($cap in $caps) {
    $kind = [string]$cap.bootstrapKind
    if (-not $requiredByKind.ContainsKey($kind)) { continue }
    foreach ($field in $requiredByKind[$kind]) {
        $val = $cap.PSObject.Properties[$field]
        if ($null -eq $val -or ($val.Value -is [string] -and [string]::IsNullOrWhiteSpace($val.Value))) {
            $missingFields += "$($cap.name).$field"
        }
    }
}
if ($missingFields.Count -eq 0) { Ok '每种 bootstrapKind 的必填字段齐' }
else { Bad ("必填字段缺失：" + ($missingFields -join ', ')) }

# --- 4. manual 能力必须带 manualInstallHint -------------------------------
$noHint = @()
foreach ($cap in $caps) {
    if ($cap.PSObject.Properties['canAutoInstall'] -and $cap.canAutoInstall -eq $false) {
        $hint = $cap.PSObject.Properties['manualInstallHint']
        if ($null -eq $hint -or [string]::IsNullOrWhiteSpace([string]$hint.Value)) {
            $noHint += [string]$cap.name
        }
    }
}
if ($noHint.Count -eq 0) { Ok '不可自动安装的能力都带 manualInstallHint' }
else { Bad ("缺 manualInstallHint：" + ($noHint -join ', ')) }

# --- 5. 可自动安装的 pip / github 类必须可复现 ----------------------------
# 不锁 = 每次 bootstrap 装到什么算什么；供应链审查要求可复现。
# 两种合法写法：
#   * 锁版本（pinnedVersion / pipPackage 里带 ==或@ / pinnedCommit）
#   * github-release-zip 用 preferApiDigest=true 走 GitHub API 的 sha256 动态校验
#     （radare2 / Ghidra 发版频繁，pin 死的 assetSha256 很快就失效——manifest 里 note 写明了）
# 真不合法的是「既没版本、也没摘要」。
$unpinned = @()
foreach ($cap in $caps) {
    if (-not ($cap.PSObject.Properties['canAutoInstall'] -and $cap.canAutoInstall -eq $true)) { continue }
    $kind = [string]$cap.bootstrapKind
    if ($kind -eq 'pip-package') {
        $spec = [string]$cap.pipPackage
        $pinnedVer = $cap.PSObject.Properties['pinnedVersion'] -and -not [string]::IsNullOrWhiteSpace([string]$cap.pinnedVersion)
        $pinnedCommit = $cap.PSObject.Properties['pinnedCommit'] -and -not [string]::IsNullOrWhiteSpace([string]$cap.pinnedCommit)
        $specPinned = $spec -match '==|@'
        if (-not ($pinnedVer -or $pinnedCommit -or $specPinned)) { $unpinned += "$($cap.name) (pip-package: $spec)" }
    }
    if ($kind -eq 'github-release-zip') {
        $hasSha = $cap.PSObject.Properties['assetSha256'] -and -not [string]::IsNullOrWhiteSpace([string]$cap.assetSha256)
        $hasDigest = $cap.PSObject.Properties['preferApiDigest'] -and $cap.preferApiDigest -eq $true
        if (-not ($hasSha -or $hasDigest)) {
            $unpinned += "$($cap.name) (github-release-zip: 既无 assetSha256 也无 preferApiDigest)"
        }
    }
    if ($kind -eq 'git-clone') {
        $hasCommit = $cap.PSObject.Properties['pinnedCommit'] -and -not [string]::IsNullOrWhiteSpace([string]$cap.pinnedCommit)
        if (-not $hasCommit) { $unpinned += "$($cap.name) (git-clone: 无 pinnedCommit，会跟 HEAD 漂)" }
    }
}
if ($unpinned.Count -eq 0) { Ok '可自动安装的能力都可复现（锁版本 / 锁提交 / API digest）' }
else { Bad ("不可复现：" + ($unpinned -join ', ')) }

# --- 6. skills 与 kali 能力名对齐 -----------------------------------------
if (-not (Test-Path -LiteralPath $kaliManifest)) {
    Info "未找到 kali manifest，跳过对齐检查：$kaliManifest"
}
else {
    $kali = Get-Content -LiteralPath $kaliManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $kaliNames = @($kali.capabilities | ForEach-Object { [string]$_.name })
    $onlySkills = @($names | Where-Object { $kaliNames -notcontains $_ })
    if ($onlySkills.Count -eq 0) {
        Ok "kali manifest 覆盖了 skills 侧的全部能力（kali 独有 $(@($kaliNames | Where-Object { $names -notcontains $_ }).Count) 项，允许）"
    }
    else {
        Bad ("kali manifest 缺少能力：" + ($onlySkills -join ', '))
    }
}

# --- 结论 -----------------------------------------------------------------
Write-Host ''
if ($fail.Count -gt 0) {
    Write-Host ("FAILED {0}（通过 {1}）" -f $fail.Count, $pass) -ForegroundColor Red
    $fail | ForEach-Object { Write-Host " - $_" }
    Write-Host 'RESULT=bootstrap_manifest_fail'
    exit 1
}
Write-Host ("bootstrap manifest structure regression passed（{0} 项）" -f $pass) -ForegroundColor Green
Write-Host 'RESULT=bootstrap_manifest_ok'
exit 0
