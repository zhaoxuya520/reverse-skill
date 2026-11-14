#Requires -Version 5.1
# 生成 skills/INDEX.md：从各模块 SKILL.md 的 frontmatter 提取 name+description，生成导航索引。
# 幂等：重复运行输出一致（CI 用 git diff 校验防 drift）。
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/scripts/extract-summaries.ps1
#   powershell -File skills/scripts/extract-summaries.ps1 -Check   # 只校验不写（CI 模式，不一致 exit 1）
param(
    [switch] $Check
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$skillsRoot = Split-Path -Parent $scriptDir
$indexPath = Join-Path $skillsRoot 'INDEX.md'

# 扫描版本库中的模块 SKILL.md（排除本地 ignored/private trees，保证 clean clone 与开发机幂等）。
$skipDirs = @('ops', 'scripts', 'config', 'tests', 'field-journal', 'references')
$packageRoot = Split-Path -Parent $skillsRoot
$trackedSkillFiles = @()
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $trackedPaths = @(& $git.Source -C $packageRoot ls-files -- 'skills/**/SKILL.md')
    if ($LASTEXITCODE -eq 0) {
        $trackedSkillFiles = @($trackedPaths | ForEach-Object {
            $fullPath = Join-Path $packageRoot ($_ -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) { Get-Item -LiteralPath $fullPath }
        })
    }
}
$candidateSkillFiles = if ($trackedSkillFiles.Count -gt 0) {
    $trackedSkillFiles
} else {
    @(Get-ChildItem -Path $skillsRoot -Recurse -Filter 'SKILL.md')
}
$skillFiles = $candidateSkillFiles | Where-Object {
    $rel = $_.FullName.Substring($skillsRoot.Length + 1)
    $rel -ne 'SKILL.md' -and -not ($skipDirs | Where-Object { $rel.StartsWith($_ + '\') -or $rel.StartsWith($_ + '/') })
} | Sort-Object { $_.FullName.Substring($skillsRoot.Length + 1) }

$rows = New-Object System.Collections.ArrayList
foreach ($sf in $skillFiles) {
    $rel = $sf.FullName.Substring($skillsRoot.Length + 1)
    # 兼容 Windows（\）与 Linux/macOS（/）两种路径分隔符
    $dir = $rel.Split(@('\', '/'))[0]
    $head = Get-Content -LiteralPath $sf.FullName -TotalCount 15 -Encoding UTF8
    $name = ''; $desc = ''; $blockMode = $false; $inFm = $false
    foreach ($line in $head) {
        if ($line -match '^---') {
            if ($inFm) { break }   # 第二个 --- 结束 frontmatter
            $inFm = $true; continue
        }
        if (-not $inFm) { continue }
        if ($line -match '^name:\s*(.+)$') { $name = $Matches[1].Trim(); continue }
        if ($line -match '^description:\s*\|') { $blockMode = $true; continue }
        if ($line -match '^description:\s*(.+)$') { $desc = $Matches[1].Trim(); continue }
        if ($blockMode) {
            # YAML 块：缩进的文本行拼接（取首行，超长截断）
            if ($line -match '^\s{2,}(.+)$') {
                if (-not $desc) { $desc = $Matches[1].Trim() }
            } elseif ($line -match '^\S') { $blockMode = $false }
        }
    }
    if (-not $name) { $name = $dir }
    if (-not $desc) { $desc = '(无摘要)' }
    if ($desc.Length -gt 160) { $desc = $desc.Substring(0, 157) + '...' }
    [void]$rows.Add([pscustomobject]@{
        Dir  = $dir
        Name = $name
        Desc = $desc
        Path = $rel
    })
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# reverse-skill 技能导航索引')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 本文件由 `skills/scripts/extract-summaries.ps1` 自动生成，**请勿手改**。')
[void]$sb.AppendLine('> 修改摘要请编辑对应模块 `SKILL.md` 的 frontmatter `description`，然后重跑脚本。')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 模块总览')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| 模块 | 摘要 |')
[void]$sb.AppendLine('|------|------|')
foreach ($r in $rows) {
    $esc = $r.Desc -replace '\|', '\|'
    [void]$sb.AppendLine(("| [{0}]({1}) | {2} |" -f $r.Name, ($r.Path -replace '\\', '/'), $esc))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 目录树')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('```')
foreach ($r in $rows) {
    # Emit module directories, not SKILL.md file paths (see issue #151).
    # Normalize to forward slashes: Windows Split-Path returns backslashes.
    $path = $r.Path -replace '\\', '/'
    $dir = Split-Path -Parent $path
    if ([string]::IsNullOrEmpty($dir)) { $dir = $r.Name }
    $dir = $dir -replace '\\', '/'
    [void]$sb.AppendLine(("skills/{0}/" -f $dir))
}
[void]$sb.AppendLine('```')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## 路由')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('PRIMARY 路由由 `skills/config/routing.json`（唯一事实源）驱动；平台原生入口：`master-route.ps1`（Windows）/ `master-route.sh`（Linux、macOS、Kali）。')
[void]$sb.AppendLine('歧义场景读 `skills/routing.md` 全矩阵；CTF 多类型任务走 `CTF-Sandbox-Orchestrator/`。')

$newContent = $sb.ToString()
# 统一 LF 行尾：与 .gitattributes (*.md eol=lf) 保持一致，保证 clone 后 -Check 幂等
$newContent = $newContent -replace "`r`n", "`n"
$utf8 = New-Object System.Text.UTF8Encoding $true

if ($Check) {
    if (-not (Test-Path -LiteralPath $indexPath)) {
        Write-Host '[CHECK] INDEX.md missing' -ForegroundColor Red
        exit 1
    }
    # 行尾免疫：autocrlf=true 的机器上 worktree 可能是 CRLF，normalize 后再比
    $old = ([System.IO.File]::ReadAllText($indexPath)) -replace "`r`n", "`n"
    if ($old -eq $newContent) {
        Write-Host '[CHECK] INDEX.md up to date' -ForegroundColor Green
        exit 0
    }
    Write-Host '[CHECK] INDEX.md out of date (run extract-summaries.ps1)' -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllText($indexPath, $newContent, $utf8)
Write-Host ("INDEX.md regenerated: {0} modules" -f $rows.Count) -ForegroundColor Green
