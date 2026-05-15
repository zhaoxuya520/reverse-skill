[CmdletBinding()]
param(
    [string]$OutputMarkdown,
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($OutputMarkdown)) {
    $OutputMarkdown = Join-Path $PSScriptRoot '..\tool-index.md'
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $PSScriptRoot '..\tool-index.json'
}

. (Join-Path $PSScriptRoot 'lib\ToolDiscovery.ps1')

$scriptRefs = @{
    'jadx' = @('apk-reverse/scripts/decode.ps1')
    'apktool' = @('apk-reverse/scripts/decode.ps1', 'apk-reverse/scripts/rebuild-sign-install.ps1')
    'adb' = @('apk-reverse/scripts/rebuild-sign-install.ps1')
    'java' = @('apk-reverse/scripts/decode.ps1')
    'apksigner' = @('apk-reverse/scripts/rebuild-sign-install.ps1')
    'zipalign' = @('apk-reverse/scripts/rebuild-sign-install.ps1')
    'frida' = @('apk-reverse/scripts/frida-run.ps1')
    'frida-ps' = @('apk-reverse/scripts/frida-run.ps1')
    'r2' = @('radare2/scripts/recon.ps1')
    'rabin2' = @('radare2/scripts/recon.ps1')
    'rasm2' = @('radare2/SKILL.md')
    'radiff2' = @('radare2/SKILL.md')
    'rahash2' = @('radare2/SKILL.md')
    'rax2' = @('radare2/SKILL.md')
    'python' = @('apk-reverse/scripts/frida-run.ps1')
    'pip' = @()
    'node' = @('js-reverse/SKILL.md')
    'npx' = @('js-reverse/SKILL.md')
    'jshookmcp' = @('js-reverse/SKILL.md')
    'agent-browser' = @('browser-automation/SKILL.md')
    'playwright' = @('browser-automation/SKILL.md', 'browser-automation/scripts/setup.ps1')
    'analyzeHeadless' = @('reverse-engineering/SKILL.md')
}

$reports = Get-ReverseToolReport
$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'

$markdownLines = @(
    '# 逆向工具索引',
    '',
    "- 扫描时间: $generatedAt",
    '- 路由入口: `SKILL.md` → `routing.md` → 对应子 skill',
    '- 说明: 本表由 `scripts/refresh-tool-index.ps1` 自动生成，优先用于 Claude 路由和工具路径确认。',
    '- 注意: 对于 jshookmcp 这类 MCP server，`yes` 只表示本机具备通过 node/npx 拉起它的条件，不表示它已经在 Claude MCP 配置里注册并启用。',
    '',
    '| 工具 | 归属 skill | 作用 | 可用 | 路径 | 版本 | 来源 | 脚本引用 |',
    '|---|---|---|---|---|---|---|---|'
)

foreach ($report in $reports) {
    $pathText = if ($report.ResolvedPath) { $report.ResolvedPath } else { '—' }
    $versionText = if ($report.Version) { $report.Version } else { '—' }
    $refs = $scriptRefs[$report.Name]
    $refsText = if ($refs -and $refs.Count -gt 0) { ($refs -join '<br>') } else { '—' }
    $availableText = if ($report.Available) { 'yes' } else { 'no' }
    $escapedPath = $pathText.Replace('|', '\|')
    $escapedVersion = $versionText.Replace('|', '\|')
    $escapedRefs = $refsText.Replace('|', '\|')
    $markdownLines += "| $($report.Name) | $($report.Skill) | $($report.Purpose) | $availableText | $escapedPath | $escapedVersion | $($report.Source) | $escapedRefs |"
}

$markdownContent = ($markdownLines -join [Environment]::NewLine) + [Environment]::NewLine
$markdownContent | Set-Content -LiteralPath $OutputMarkdown -Encoding utf8

# --- Capability status view ---
$capabilityNames = @('jadx', 'apktool', 'frida', 'idalib-mcp', 'jshookmcp', 'anything-analyzer', 'idapro', 'r2', 'adb', 'agent-browser')
$capabilityRows = @()
foreach ($capName in $capabilityNames) {
    $state = Get-ReverseCapabilityState -Name $capName
    if ($null -eq $state) { continue }
    $toolAvailable = $false
    try {
        $toolSpec = Resolve-ReverseToolSpec -Name $capName
        $toolAvailable = $toolSpec.Available
    }
    catch {
        # Capability exists in bootstrap manifest but not in tool catalog (e.g. MCP-only capabilities)
        $toolAvailable = $false
    }
    $capabilityRows += [pscustomobject]@{
        name = $capName
        tool_available = $toolAvailable
        mcp_registered = $state.Registered
        service_online = $state.ServiceOnline
        can_auto_install = $state.CanAutoInstall
        bootstrap_kind = $state.BootstrapKind
    }
}

# Append capability view to markdown
$markdownCapLines = @(
    '',
    '---',
    '',
    '## 能力状态视图 (Capability Status)',
    '',
    '| 能力 | 工具可用 | MCP 已注册 | 服务在线 | 可自动安装 | 安装方式 |',
    '|------|---------|-----------|---------|-----------|---------|'
)
foreach ($cap in $capabilityRows) {
    $toolText = if ($cap.tool_available) { '✓' } else { '✗' }
    $mcpText = if ($cap.mcp_registered) { '✓' } else { '—' }
    $svcText = if ($cap.service_online) { '✓' } else { '—' }
    $autoText = if ($cap.can_auto_install) { '✓' } else { '✗' }
    $kindText = if ($cap.bootstrap_kind) { $cap.bootstrap_kind } else { '—' }
    $markdownCapLines += "| $($cap.name) | $toolText | $mcpText | $svcText | $autoText | $kindText |"
}
$markdownCapLines += ''
$markdownCapLines += '> ✓ = 是 | ✗ = 否 | — = 不适用或未检测'
$markdownCapLines += ''

$capContent = ($markdownCapLines -join [Environment]::NewLine)
Add-Content -LiteralPath $OutputMarkdown -Value $capContent -Encoding utf8

$jsonRows = foreach ($report in $reports) {
    [pscustomobject]@{
        name = $report.Name
        skill = $report.Skill
        purpose = $report.Purpose
        available = $report.Available
        resolved_path = $report.ResolvedPath
        version = $report.Version
        source = $report.Source
        script_refs = @($scriptRefs[$report.Name])
    }
}

$jsonPayload = [pscustomobject]@{
    generated_at = $generatedAt
    routing_entry = @('SKILL.md', 'routing.md')
    tools = $jsonRows
    capabilities = $capabilityRows
}

$jsonPayload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputJson -Encoding utf8

"markdown=$OutputMarkdown"
"json=$OutputJson"
"tools=$($reports.Count)"

