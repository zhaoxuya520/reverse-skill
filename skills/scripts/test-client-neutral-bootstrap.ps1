#requires -Version 5

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bootstrap = Join-Path $scriptDir 'bootstrap-reverse.ps1'
$toolDiscovery = Join-Path $scriptDir 'lib\ToolDiscovery.ps1'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('reverse-client-neutral-' + [guid]::NewGuid().ToString('n'))
$binDir = Join-Path $scratch 'bin'
$clientDir = Join-Path $scratch 'client'
$claudeConfig = Join-Path $clientDir 'claude.json'
$codexConfig = Join-Path $clientDir 'codex.toml'

New-Item -ItemType Directory -Force -Path $binDir, $clientDir | Out-Null
try {
    foreach ($name in @('node', 'npm', 'npx')) {
        $cmdPath = Join-Path $binDir ($name + '.cmd')
        @('@echo off', 'if "%1"=="--version" echo 1.0.0', 'exit /b 0') | Set-Content -LiteralPath $cmdPath -Encoding ascii
    }

    $oldPath = $env:PATH
    $oldClaudeConfig = $env:CLAUDE_MCP_CONFIG
    $oldCodexConfig = $env:CODEX_CONFIG_PATH
    $env:PATH = "$binDir;$oldPath"
    $env:CLAUDE_MCP_CONFIG = $claudeConfig
    $env:CODEX_CONFIG_PATH = $codexConfig

    $defaultOutput = (& $bootstrap -Capability jshookmcp -SkipRefresh | Out-String)
    if (Test-Path -LiteralPath $claudeConfig) { throw 'default bootstrap wrote Claude global config' }
    if (Test-Path -LiteralPath $codexConfig) { throw 'default bootstrap wrote Codex global config' }
    if ($defaultOutput -notmatch 'configured-not-ready') { throw 'default MCP bootstrap did not report configured-not-ready' }

    $codexOutput = (& $bootstrap -Capability jshookmcp -SkipRefresh -McpHostTarget Codex | Out-String)
    if (Test-Path -LiteralPath $claudeConfig) { throw 'Codex-only bootstrap wrote Claude config' }
    if (-not (Test-Path -LiteralPath $codexConfig)) { throw 'Codex-only bootstrap did not write Codex config' }
    if ((Get-Content -LiteralPath $codexConfig -Raw) -notmatch '(?m)^\[mcp_servers\.jshook\]\r?$') { throw 'Codex config missing jshook MCP block' }
    if ($codexOutput -notmatch '"status"\s*:\s*"ready"') { throw 'Codex-only bootstrap did not report ready' }

    . $toolDiscovery
    $tool = Resolve-ReverseToolSpec -Name 'jshookmcp'
    if ($tool.Available) { throw 'npx must not masquerade as jshookmcp tool availability' }
    $state = Get-ReverseCapabilityState -Name 'jshookmcp'
    if (-not $state.Registered) { throw 'Codex-only registration was not discovered' }
    if (-not $state.RuntimeAvailable) { throw 'npx runtime was not detected' }
    if (-not $state.Ready) { throw 'Codex registration plus npx runtime should be ready' }

    Remove-Item -LiteralPath $codexConfig -Force
    $claudeOutput = (& $bootstrap -Capability jshookmcp -SkipRefresh -McpHostTarget Claude | Out-String)
    if (-not (Test-Path -LiteralPath $claudeConfig)) { throw 'Claude-only bootstrap did not write Claude config' }
    if (Test-Path -LiteralPath $codexConfig) { throw 'Claude-only bootstrap wrote Codex config' }
    $json = Get-Content -LiteralPath $claudeConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $json.mcpServers.jshook) { throw 'Claude config missing jshook MCP server' }
    if ($claudeOutput -notmatch '"status"\s*:\s*"ready"') { throw 'Claude-only bootstrap did not report ready' }

    Remove-Item -LiteralPath $claudeConfig -Force
    $xquikDefaultOutput = (& $bootstrap -Capability xquik-mcp -SkipRefresh | Out-String)
    if (Test-Path -LiteralPath $claudeConfig) { throw 'default Xquik bootstrap wrote Claude global config' }
    if (Test-Path -LiteralPath $codexConfig) { throw 'default Xquik bootstrap wrote Codex global config' }
    if ($xquikDefaultOutput -notmatch 'configured-not-ready') { throw 'default Xquik bootstrap did not report configured-not-ready' }

    $xquikCodexOutput = (& $bootstrap -Capability xquik-mcp -SkipRefresh -McpHostTarget Codex | Out-String)
    if (Test-Path -LiteralPath $claudeConfig) { throw 'Codex-only Xquik bootstrap wrote Claude config' }
    if (-not (Test-Path -LiteralPath $codexConfig)) { throw 'Codex-only Xquik bootstrap did not write Codex config' }
    $codexText = Get-Content -LiteralPath $codexConfig -Raw
    if ($codexText -notmatch '(?m)^\[mcp_servers\.xquik\]\r?$') { throw 'Codex config missing xquik MCP block' }
    if ($codexText -notmatch '(?m)^url = "https://xquik\.com/mcp"\r?$') { throw 'Codex config has the wrong Xquik MCP URL' }
    if ($xquikCodexOutput -notmatch '"status"\s*:\s*"ready"') { throw 'Codex-only Xquik bootstrap did not report ready' }

    $xquikState = Get-ReverseCapabilityState -Name 'xquik-mcp'
    if (-not $xquikState.Registered) { throw 'Codex-only Xquik registration was not discovered' }
    if (-not $xquikState.Ready) { throw 'registered remote Xquik MCP should be ready for OAuth' }

    Remove-Item -LiteralPath $codexConfig -Force
    $xquikClaudeOutput = (& $bootstrap -Capability xquik-mcp -SkipRefresh -McpHostTarget Claude | Out-String)
    if (-not (Test-Path -LiteralPath $claudeConfig)) { throw 'Claude-only Xquik bootstrap did not write Claude config' }
    if (Test-Path -LiteralPath $codexConfig) { throw 'Claude-only Xquik bootstrap wrote Codex config' }
    $xquikJson = Get-Content -LiteralPath $claudeConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($xquikJson.mcpServers.xquik.url -ne 'https://xquik.com/mcp') { throw 'Claude config has the wrong Xquik MCP URL' }
    if ($xquikClaudeOutput -notmatch '"status"\s*:\s*"ready"') { throw 'Claude-only Xquik bootstrap did not report ready' }

    Write-Host 'client-neutral PowerShell bootstrap/discovery regression passed'
}
finally {
    if ($null -ne $oldPath) { $env:PATH = $oldPath }
    $env:CLAUDE_MCP_CONFIG = $oldClaudeConfig
    $env:CODEX_CONFIG_PATH = $oldCodexConfig
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
