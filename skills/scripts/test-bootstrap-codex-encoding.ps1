#Requires -Version 5.1
param(
    [string]$ScratchDir = ''
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ScratchDir)) {
    $ScratchDir = Join-Path ([System.IO.Path]::GetTempPath()) ('reverse-skill-codex-encoding-' + [guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

. (Join-Path $scriptDir 'lib\ToolDiscovery.ps1')

# Load only the functions under test; do not execute bootstrap installation code.
$bootstrapPath = Join-Path $scriptDir 'bootstrap-reverse.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
    throw "bootstrap-reverse.ps1 parse failed: $($errors[0].Message)"
}
foreach ($name in @('ConvertTo-TomlLiteral', 'Remove-CodexMcpServerBlocks', 'Set-CodexMcpServer')) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if ($null -eq $functionAst) {
        throw "Function not found: $name"
    }
    Invoke-Expression $functionAst.Extent.Text
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Test-CodexConfigRoundTrip {
    param(
        [string]$Name,
        [bool]$WithBom,
        [string]$Newline
    )

    $path = Join-Path $ScratchDir "$Name.toml"
    $original = @(
        "[projects.'e:\codex目录\blender脚本管理器']",
        'trust_level = "trusted"',
        '',
        '[mcp_servers.existing]',
        'command = "existing"'
    ) -join $Newline
    $original += $Newline
    [System.IO.File]::WriteAllText($path, $original, [System.Text.UTF8Encoding]::new($WithBom))

    $oldConfigPath = $env:CODEX_CONFIG_PATH
    try {
        $env:CODEX_CONFIG_PATH = $path
        Set-CodexMcpServer -ServerName 'encoding-test' -ServerDefinition @{
            type = 'stdio'
            command = 'cmd'
            args = @('/c', 'echo', '中文参数')
        }
        Set-CodexMcpServer -ServerName 'encoding-test' -ServerDefinition @{
            type = 'stdio'
            command = 'cmd'
            args = @('/c', 'echo', '中文参数')
        }
    }
    finally {
        $env:CODEX_CONFIG_PATH = $oldConfigPath
    }

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    Assert-True ($hasBom -eq $WithBom) "$Name preserves UTF-8 BOM state"

    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    Assert-True ($text.Contains("[projects.'e:\codex目录\blender脚本管理器']")) "$Name preserves Chinese TOML path and closing quote"
    Assert-True ($text.Contains('[mcp_servers.encoding-test]')) "$Name adds MCP server"
    Assert-True (([regex]::Matches($text, '(?m)^\[mcp_servers\.encoding-test\]\r?$')).Count -eq 1) "$Name updates MCP server idempotently"
    Assert-True ($text.Contains('中文参数')) "$Name preserves new Chinese values"
    if ($Newline -eq "`r`n") {
        Assert-True (-not ($text -replace "`r`n", '').Contains("`n")) "$Name preserves CRLF newlines"
    }
}

Test-CodexConfigRoundTrip -Name 'utf8-no-bom-crlf' -WithBom $false -Newline "`r`n"
Test-CodexConfigRoundTrip -Name 'utf8-bom-lf' -WithBom $true -Newline "`n"

$newPath = Join-Path $ScratchDir 'new-config.toml'
$oldConfigPath = $env:CODEX_CONFIG_PATH
try {
    $env:CODEX_CONFIG_PATH = $newPath
    Set-CodexMcpServer -ServerName 'new-config-test' -ServerDefinition @{ command = '中文命令' }
}
finally {
    $env:CODEX_CONFIG_PATH = $oldConfigPath
}
$newBytes = [System.IO.File]::ReadAllBytes($newPath)
$newHasBom = $newBytes.Length -ge 3 -and $newBytes[0] -eq 0xEF -and $newBytes[1] -eq 0xBB -and $newBytes[2] -eq 0xBF
Assert-True (-not $newHasBom) 'new config uses UTF-8 without BOM'
$newText = [System.Text.Encoding]::UTF8.GetString($newBytes)
Assert-True ($newText.Contains('[mcp_servers.new-config-test]')) 'new config contains MCP server block'
Assert-True ($newText.Contains('中文命令')) 'new config preserves Chinese values'

$invalidPath = Join-Path $ScratchDir 'invalid-utf8.toml'
[System.IO.File]::WriteAllBytes($invalidPath, [byte[]](0x5B, 0x80, 0x5D))
$oldConfigPath = $env:CODEX_CONFIG_PATH
$threw = $false
try {
    $env:CODEX_CONFIG_PATH = $invalidPath
    Set-CodexMcpServer -ServerName 'must-not-write' -ServerDefinition @{ command = 'x' }
}
catch [System.Text.DecoderFallbackException] {
    $threw = $true
}
finally {
    $env:CODEX_CONFIG_PATH = $oldConfigPath
}
Assert-True $threw 'invalid UTF-8 fails closed instead of rewriting the file'
$invalidBytes = [System.IO.File]::ReadAllBytes($invalidPath)
Assert-True ($invalidBytes.Length -eq 3 -and $invalidBytes[1] -eq 0x80) 'invalid UTF-8 file remains unchanged'

Write-Host 'OVERALL: ALL PASS' -ForegroundColor Green

