#requires -Version 5

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Capability,

    [switch]$SkipRefresh,

    [switch]$StartServices,

    [ValidateSet('Claude', 'Codex', 'Both')]
    [string]$McpHostTarget = 'Both'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

. (Join-Path $PSScriptRoot 'lib\ToolDiscovery.ps1')

$Capability = @(
    foreach ($item in @($Capability)) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }
        foreach ($name in ($item -split ',')) {
            $trimmed = $name.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $trimmed
            }
        }
    }
) | Select-Object -Unique

function Get-FirstCommandPath {
    param(
        [string[]]$Names,
        [switch]$PreferApplication
    )

    foreach ($name in $Names) {
        $commands = @(Get-Command $name -All -ErrorAction SilentlyContinue)
        if ($PreferApplication) {
            $preferred = $commands | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
            if ($preferred) {
                return $preferred.Source
            }
        }
        $cmd = $commands | Select-Object -First 1
        if ($cmd) {
            return $cmd.Source
        }
    }
    return ''
}

function Get-PreferredPowerShellPath {
    $pwsh = Get-FirstCommandPath -Names @('pwsh.exe', 'pwsh') -PreferApplication
    if (-not [string]::IsNullOrWhiteSpace($pwsh)) {
        return $pwsh
    }
    return Get-FirstCommandPath -Names @('powershell.exe', 'powershell') -PreferApplication
}

function Get-NodeCommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)

    return Get-FirstCommandPath -Names @("$Name.cmd", "$Name.exe", $Name) -PreferApplication
}

function Test-SuccessExitCode {
    param([int]$ExitCode)

    return $ExitCode -in @(0, 3010, 1641)
}

function Get-McpHostTargets {
    switch ($McpHostTarget) {
        'Claude' { return @('Claude') }
        'Codex' { return @('Codex') }
        default { return @('Claude', 'Codex') }
    }
}

function Test-ReverseIsWindows {
    return $env:OS -eq 'Windows_NT'
}

function Test-ReverseIsElevated {
    if (-not (Test-ReverseIsWindows)) {
        return $true
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-WingetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Override
    )

    $winget = Get-FirstCommandPath -Names @('winget')
    if ([string]::IsNullOrWhiteSpace($winget)) {
        throw "Cannot auto-install $Label because winget is not available."
    }

    $arguments = @(
        'install',
        '--id', $Id,
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        $arguments += @('--override', $Override)
    }

    & $winget @arguments
    if (-not (Test-SuccessExitCode -ExitCode $LASTEXITCODE)) {
        throw "winget install failed for $Label ($Id)."
    }
}

function Ensure-NodeRuntime {
    if (-not (Get-FirstCommandPath -Names @('node'))) {
        Ensure-WingetPackage -Id 'OpenJS.NodeJS.22' -Label 'Node.js 22'
    }
    if (-not (Get-NodeCommandPath -Name 'npx')) {
        Ensure-WingetPackage -Id 'OpenJS.NodeJS.22' -Label 'Node.js 22'
    }
}

function Ensure-PythonRuntime {
    if (-not (Get-FirstCommandPath -Names @('python', 'python3'))) {
        Ensure-WingetPackage -Id 'Python.Python.3.13' -Label 'Python 3.13'
    }
}

function Ensure-JavaRuntime {
    if (-not (Get-FirstCommandPath -Names @('java'))) {
        Ensure-WingetPackage -Id 'Microsoft.OpenJDK.21' -Label 'OpenJDK 21'
    }
}

function Ensure-Pnpm {
    Ensure-NodeRuntime
    if (-not (Get-NodeCommandPath -Name 'pnpm')) {
        $npm = Get-NodeCommandPath -Name 'npm'
        if ([string]::IsNullOrWhiteSpace($npm)) {
            throw 'npm is not available after Node.js installation.'
        }
        & $npm install -g pnpm
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to install pnpm globally.'
        }
    }
}

function Get-AnythingAnalyzerUserDataPaths {
    $candidates = @(
        (Join-Path $env:APPDATA 'anything-analyzer'),
        (Join-Path $env:APPDATA 'Anything Analyzer')
    )

    $existing = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container })
    if ($existing.Count -gt 0) {
        return @($existing | Sort-Object -Unique)
    }

    return @($candidates | Sort-Object -Unique)
}

function Ensure-AnythingAnalyzerMcpConfig {
    param([int]$Port = 23816)

    $payload = [ordered]@{
        enabled = $true
        port = $Port
        authEnabled = $false
        authToken = ''
    }

    foreach ($userDataPath in Get-AnythingAnalyzerUserDataPaths) {
        if (-not (Test-Path -LiteralPath $userDataPath)) {
            New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
        }
        $configPath = Join-Path $userDataPath 'mcp-server-config.json'
        $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding utf8
    }
}

function Test-VsBuildToolsInstalled {
    $roots = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\BuildTools')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($root in $roots) {
        $vcToolsPath = Join-Path $root 'VC\Tools\MSVC'
        if (Test-Path -LiteralPath $vcToolsPath -PathType Container) {
            return $true
        }
    }

    return $false
}

function Ensure-VsBuildTools {
    if (Test-VsBuildToolsInstalled) {
        return
    }

    $override = '--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    try {
        Ensure-WingetPackage -Id 'Microsoft.VisualStudio.2022.BuildTools' -Label 'Visual Studio Build Tools 2022' -Override $override
    }
    catch {
        if (-not (Test-ReverseIsElevated)) {
            throw "$($_.Exception.Message) Current PowerShell process is not elevated; Visual Studio Build Tools may require an administrator/UAC install."
        }
        throw
    }

    if (-not (Test-VsBuildToolsInstalled)) {
        throw 'Visual Studio Build Tools installed command completed, but the C++ workload was not detected.'
    }
}

function Test-AnythingAnalyzerElectronHealthy {
    param(
        [Parameter(Mandatory = $true)][string]$RepoDir,
        [Parameter(Mandatory = $true)][string]$PnpmPath
    )

    Push-Location $RepoDir
    try {
        & $PnpmPath exec electron --version *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
    finally {
        Pop-Location
    }
}

function Set-AnythingAnalyzerPnpmBuildApprovals {
    param(
        [Parameter(Mandatory = $true)][string]$RepoDir,
        [Parameter(Mandatory = $true)][string[]]$Packages
    )

    $workspacePath = Join-Path $RepoDir 'pnpm-workspace.yaml'
    $lines = @()
    if (Test-Path -LiteralPath $workspacePath) {
        $lines = @(Get-Content -LiteralPath $workspacePath)
    }

    $existingPackages = New-Object System.Collections.Generic.List[string]
    $preserved = New-Object System.Collections.Generic.List[string]
    $skipOnlyBuilt = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*onlyBuiltDependencies\s*:') {
            $skipOnlyBuilt = $true
            continue
        }

        if ($skipOnlyBuilt) {
            if ($line -match '^\s*-\s*(.+?)\s*$') {
                $existingPackages.Add($matches[1].Trim("'`""))
                continue
            }
            if ($line -match '^\s+' -or [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $skipOnlyBuilt = $false
        }

        $preserved.Add($line)
    }

    while ($preserved.Count -gt 0 -and [string]::IsNullOrWhiteSpace($preserved[$preserved.Count - 1])) {
        $preserved.RemoveAt($preserved.Count - 1)
    }

    $approvedPackages = @($existingPackages + @($Packages)) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    if ($preserved.Count -gt 0) {
        $preserved.Add('')
    }
    $preserved.Add('onlyBuiltDependencies:')
    foreach ($package in $approvedPackages) {
        $preserved.Add("  - $package")
    }

    Set-Content -LiteralPath $workspacePath -Value @($preserved) -Encoding utf8
}

function Approve-AnythingAnalyzerBuildScripts {
    param(
        [Parameter(Mandatory = $true)][string]$RepoDir,
        [Parameter(Mandatory = $true)][string]$PnpmPath
    )

    $buildPackages = @('electron', 'esbuild', 'better-sqlite3')

    Push-Location $RepoDir
    try {
        $approveExitCode = 1
        try {
            $approveOutput = & $PnpmPath approve-builds --all 2>&1
            $approveExitCode = $LASTEXITCODE
        }
        catch {
            $approveOutput = $_.Exception.Message
            $approveExitCode = 1
        }

        if ($approveExitCode -eq 0) {
            return
        }

        Write-Warning 'pnpm approve-builds --all is unavailable or failed; writing pnpm-workspace.yaml build approvals directly.'
    }
    finally {
        Pop-Location
    }

    Set-AnythingAnalyzerPnpmBuildApprovals -RepoDir $RepoDir -Packages $buildPackages
}

function Get-GitHubLatestReleaseAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$AssetRegex,
        [string]$ReleaseTag = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($ReleaseTag)) {
        $uri = "https://api.github.com/repos/$Repo/releases/tags/$ReleaseTag"
    }
    else {
        $uri = "https://api.github.com/repos/$Repo/releases/latest"
    }
    $release = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'reverse-skill-bootstrap' }
    $asset = @($release.assets) | Where-Object { $_.name -match $AssetRegex } | Select-Object -First 1
    if ($null -eq $asset) {
        throw "No release asset matched $AssetRegex for $Repo (tag=$ReleaseTag)"
    }
    return $asset
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Assert-DownloadedFileIntegrity {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        $Definition = $null,
        $Asset = $null
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Integrity check failed: file missing $Path"
    }

    $actual = Get-FileSha256Hex -Path $Path
    $expected = $null
    $source = $null

    if ($null -ne $Definition -and $Definition.PSObject.Properties['assetSha256'] -and -not [string]::IsNullOrWhiteSpace([string]$Definition.assetSha256)) {
        $expected = ([string]$Definition.assetSha256 -replace '^(?i)sha256:', '').Trim().ToLowerInvariant()
        $source = 'manifest.assetSha256'
    }
    elseif ($null -ne $Asset -and $Asset.PSObject.Properties['digest'] -and -not [string]::IsNullOrWhiteSpace([string]$Asset.digest)) {
        $expected = ([string]$Asset.digest -replace '^(?i)sha256:', '').Trim().ToLowerInvariant()
        $source = 'github.api.digest'
    }

    if (-not [string]::IsNullOrWhiteSpace($expected)) {
        if ($actual -ne $expected) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            throw "SHA256 mismatch for $(Split-Path -Leaf $Path) (via $source): expected $expected got $actual — file deleted"
        }
        Write-Host ("[integrity] SHA256 OK ({0}): {1}" -f $source, $actual) -ForegroundColor Green
        return $actual
    }

    Write-Warning ("[integrity] No pinned digest for {0}; recorded sha256={1} (supply-chain residual — prefer assetSha256 in manifest)" -f (Split-Path -Leaf $Path), $actual)
    return $actual
}

function Expand-ArchiveIntoDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $tempExtract = Join-Path $env:TEMP ("reverse-bootstrap-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $tempExtract -Force

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    $children = Get-ChildItem -LiteralPath $tempExtract
    if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
        $sourceDir = $children[0].FullName
    }
    else {
        $sourceDir = $tempExtract
    }

    Get-ChildItem -LiteralPath $sourceDir -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $Destination -Force
    }

    Remove-Item -LiteralPath $tempExtract -Recurse -Force
}

function Ensure-DownloadDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-GitHubZipInstall {
    param(
        [Parameter(Mandatory = $true)]$Definition,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$VerifyName
    )

    $existing = Resolve-ReverseToolSpec -Name $VerifyName
    if ($existing.Available) {
        return $existing
    }

    $releaseTag = if ($Definition.PSObject.Properties['releaseTag']) { [string]$Definition.releaseTag } else { '' }
    $asset = Get-GitHubLatestReleaseAsset -Repo $Definition.repo -AssetRegex $Definition.assetRegex -ReleaseTag $releaseTag
    $downloadUrl = if ($asset.PSObject.Properties['browser_download_url']) { $asset.browser_download_url } else { $asset.url }
    $downloadPath = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -Headers @{ 'Accept' = 'application/octet-stream' }
    Assert-DownloadedFileIntegrity -Path $downloadPath -Definition $Definition -Asset $asset | Out-Null
    Ensure-DownloadDirectory -Path (Split-Path -Path $TargetPath -Parent)
    Expand-ArchiveIntoDirectory -ZipPath $downloadPath -Destination $TargetPath
    Remove-Item -LiteralPath $downloadPath -Force

    # Refresh PATH so newly installed tools are discoverable
    $binCandidates = @(
        (Join-Path $TargetPath 'bin'),
        $TargetPath
    )
    foreach ($binDir in $binCandidates) {
        if ((Test-Path -LiteralPath $binDir) -and ($env:PATH -notlike "*$binDir*")) {
            $env:PATH = "$binDir;$env:PATH"
        }
    }

    return (Resolve-ReverseToolSpec -Name $VerifyName)
}

function Ensure-ApktoolInstall {
    param([Parameter(Mandatory = $true)]$Definition)

    $existing = Resolve-ReverseToolSpec -Name 'apktool'
    if ($existing.Available) {
        return $existing
    }

    Ensure-JavaRuntime
    $releaseTag = if ($Definition.PSObject.Properties['releaseTag']) { [string]$Definition.releaseTag } else { '' }
    $asset = Get-GitHubLatestReleaseAsset -Repo $Definition.repo -AssetRegex $Definition.assetRegex -ReleaseTag $releaseTag
    $installDir = $Definition.installDir
    Ensure-DownloadDirectory -Path $installDir

    $jarName = [System.IO.Path]::GetFileName($asset.name)
    $jarPath = Join-Path $installDir 'apktool.jar'
    $downloadUrl = if ($asset.PSObject.Properties['browser_download_url']) { $asset.browser_download_url } else { $asset.url }
    Invoke-WebRequest -Uri $downloadUrl -OutFile $jarPath -Headers @{ 'Accept' = 'application/octet-stream' }
    Assert-DownloadedFileIntegrity -Path $jarPath -Definition $Definition -Asset $asset | Out-Null

    $wrapperPath = Join-Path $installDir $Definition.wrapperName
    @(
        '@echo off',
        'setlocal',
        'java -jar "%~dp0apktool.jar" %*'
    ) | Set-Content -LiteralPath $wrapperPath -Encoding ascii

    # Add to PATH so discovery can find it immediately
    if ($env:PATH -notlike "*$installDir*") {
        $env:PATH = "$installDir;$env:PATH"
    }

    return (Resolve-ReverseToolSpec -Name 'apktool')
}

function Ensure-PipPackageInstall {
    param([Parameter(Mandatory = $true)]$Definition)

    Ensure-PythonRuntime
    $python = Get-FirstCommandPath -Names @('python', 'python3')
    # Use pipSource (git URL) if available, otherwise use pipPackage name
    $installTarget = if ($Definition.PSObject.Properties['pipSource'] -and -not [string]::IsNullOrWhiteSpace($Definition.pipSource)) {
        $Definition.pipSource
    } else {
        $Definition.pipPackage
    }
    & $python -m pip install --upgrade $installTarget
    if ($LASTEXITCODE -ne 0) {
        throw "pip install failed for $installTarget"
    }
}

function Get-ClaudeMcpConfig {
    $path = Get-ClaudeMcpConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ path = $path; json = @{ mcpServers = @{} } }
    }

    $json = Read-ReverseJsonAsHashtable -Path $path
    if ($null -eq $json) {
        $json = @{ mcpServers = @{} }
    }
    if (-not $json.Contains('mcpServers')) {
        $json['mcpServers'] = @{}
    }
    return @{ path = $path; json = $json }
}

function Save-ClaudeMcpConfig {
    param([Parameter(Mandatory = $true)]$Config)

    $parent = Split-Path -Path $Config.path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Config.json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Config.path -Encoding utf8
}

function ConvertTo-TomlLiteral {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return [string]$Value
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = foreach ($item in $Value) {
            ConvertTo-TomlLiteral -Value $item
        }
        return "[{0}]" -f ($items -join ', ')
    }

    $escaped = ([string]$Value).Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Remove-CodexMcpServerBlocks {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$ServerName
    )

    $targetPattern = '^\[mcp_servers\.{0}(?:\.env)?\]\s*$' -f [regex]::Escape($ServerName)
    $result = New-Object System.Collections.Generic.List[string]
    $skipBlock = $false

    if ($null -eq $Lines) {
        return @()
    }

    foreach ($line in $Lines) {
        if ($line -match '^\[') {
            if ($line -match $targetPattern) {
                $skipBlock = $true
                continue
            }

            if ($skipBlock) {
                $skipBlock = $false
            }
        }

        if (-not $skipBlock) {
            $result.Add($line)
        }
    }

    return @($result)
}

function Set-CodexMcpServer {
    param(
        [Parameter(Mandatory = $true)][string]$ServerName,
        [Parameter(Mandatory = $true)][hashtable]$ServerDefinition
    )

    $path = Get-CodexConfigPath
    $parent = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $lines = @()
    if (Test-Path -LiteralPath $path) {
        $rawLines = @(Get-Content -LiteralPath $path)
        if ($rawLines.Count -eq 1 -and [string]::IsNullOrEmpty($rawLines[0])) {
            $lines = @()
        }
        else {
            $lines = $rawLines
        }
    }
    $lines = @(Remove-CodexMcpServerBlocks -Lines $lines -ServerName $ServerName)

    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[-1])) {
        $lines = if ($lines.Count -gt 1) { $lines[0..($lines.Count - 2)] } else { @() }
    }
    if ($lines.Count -gt 0) {
        $lines += ''
    }

    $lines += "[mcp_servers.$ServerName]"
    foreach ($key in @('type', 'url', 'command', 'args', 'bearer_token_env_var')) {
        if ($ServerDefinition.Contains($key)) {
            $lines += "$key = $(ConvertTo-TomlLiteral -Value $ServerDefinition[$key])"
        }
    }
    foreach ($key in ($ServerDefinition.Keys | Where-Object { $_ -notin @('type', 'url', 'command', 'args', 'bearer_token_env_var', 'env') } | Sort-Object)) {
        $lines += "$key = $(ConvertTo-TomlLiteral -Value $ServerDefinition[$key])"
    }

    if ($ServerDefinition.Contains('env') -and $ServerDefinition['env'] -is [System.Collections.IDictionary] -and $ServerDefinition['env'].Count -gt 0) {
        $lines += ''
        $lines += "[mcp_servers.$ServerName.env]"
        foreach ($envKey in ($ServerDefinition['env'].Keys | Sort-Object)) {
            $lines += "$envKey = $(ConvertTo-TomlLiteral -Value $ServerDefinition['env'][$envKey])"
        }
    }

    Set-Content -LiteralPath $path -Value $lines -Encoding utf8
}

function Ensure-McpServer {
    param(
        [Parameter(Mandatory = $true)][string]$ServerName,
        [Parameter(Mandatory = $true)][hashtable]$ServerDefinition
    )

    foreach ($target in Get-McpHostTargets) {
        switch ($target) {
            'Claude' {
                $config = Get-ClaudeMcpConfig
                $config.json.mcpServers[$ServerName] = $ServerDefinition
                Save-ClaudeMcpConfig -Config $config
            }
            'Codex' {
                Set-CodexMcpServer -ServerName $ServerName -ServerDefinition $ServerDefinition
            }
        }
    }
}

function Get-McpCommandServerDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [hashtable]$Env = @{}
    )

    if ((Test-ReverseIsWindows) -and $Command -in @('npx', 'pnpm', 'npm')) {
        return @{
            type = 'stdio'
            command = 'cmd'
            args = @('/c', $Command) + @($Arguments)
            env = $Env
        }
    }

    return @{
        type = 'stdio'
        command = $Command
        args = @($Arguments)
        env = $Env
    }
}

function Wait-ForPort {
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-ReverseTcpPort -Port $Port) {
            return $true
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Start-AnythingAnalyzerService {
    param([Parameter(Mandatory = $true)]$Definition)

    if (Test-ReverseTcpPort -Port ([int]$Definition.servicePort)) {
        return
    }

Ensure-Pnpm
$vsBuildToolsError = ''
if (Test-ReverseIsWindows) {
    try {
        Ensure-VsBuildTools
    }
    catch {
        $vsBuildToolsError = $_.Exception.Message
        Write-Warning "Visual Studio Build Tools auto-install failed; continuing with pnpm prebuilt/native rebuild path. $vsBuildToolsError"
    }
}

    $repoDir = @($Definition.startupDirCandidates) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($repoDir)) {
        $installDir = $Definition.installDir
        $gh = Get-FirstCommandPath -Names @('gh')
        $git = Get-FirstCommandPath -Names @('git')
        if ($gh) {
            & $gh repo clone 'Mouseww/anything-analyzer' $installDir
        }
        elseif ($git) {
            & $git clone $Definition.repoUrl $installDir
        }
        else {
            throw 'Cannot clone anything-analyzer because neither gh nor git is available.'
        }
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to clone anything-analyzer.'
        }
        $repoDir = $installDir
    }

    Ensure-AnythingAnalyzerMcpConfig -Port ([int]$Definition.servicePort)

    $pnpm = Get-NodeCommandPath -Name 'pnpm'
    if ([string]::IsNullOrWhiteSpace($pnpm)) {
        throw 'pnpm is not available after installation.'
    }

    Push-Location $repoDir
    try {
        Approve-AnythingAnalyzerBuildScripts -RepoDir $repoDir -PnpmPath $pnpm

        if (-not (Test-AnythingAnalyzerElectronHealthy -RepoDir $repoDir -PnpmPath $pnpm)) {
            $nodeModules = Join-Path $repoDir 'node_modules'
            if (Test-Path -LiteralPath $nodeModules) {
                Remove-Item -LiteralPath $nodeModules -Recurse -Force
            }
        }

        & $pnpm install
        if ($LASTEXITCODE -ne 0) {
            if (-not [string]::IsNullOrWhiteSpace($vsBuildToolsError)) {
                throw "pnpm install failed for anything-analyzer. Visual Studio Build Tools auto-install also failed earlier: $vsBuildToolsError"
            }
            throw 'pnpm install failed for anything-analyzer.'
        }

        & $pnpm rebuild electron esbuild better-sqlite3
        if ($LASTEXITCODE -ne 0) {
            if (-not [string]::IsNullOrWhiteSpace($vsBuildToolsError)) {
                throw "pnpm rebuild failed for anything-analyzer. Visual Studio Build Tools auto-install also failed earlier: $vsBuildToolsError"
            }
            throw 'pnpm rebuild failed for anything-analyzer.'
        }

        if (-not (Test-AnythingAnalyzerElectronHealthy -RepoDir $repoDir -PnpmPath $pnpm)) {
            throw 'Electron is still not healthy after reinstall/rebuild.'
        }
    }
    finally {
        Pop-Location
    }

    $stdoutLog = Join-Path $repoDir 'anything-analyzer-dev.log'
    $stderrLog = Join-Path $repoDir 'anything-analyzer-dev.err.log'
    Remove-Item -LiteralPath $stdoutLog, $stderrLog -Force -ErrorAction SilentlyContinue

    Start-Process -FilePath $pnpm -ArgumentList @('dev') -WorkingDirectory $repoDir -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog | Out-Null
    if (-not (Wait-ForPort -Port ([int]$Definition.servicePort) -TimeoutSeconds 120)) {
        throw "anything-analyzer did not open port 23816 in time. Logs: $stdoutLog ; $stderrLog"
    }
}

function Start-IdaProService {
    param([Parameter(Mandatory = $true)]$Definition)

    if (Test-ReverseTcpPort -Port ([int]$Definition.servicePort)) {
        return
    }

    $startScript = $Definition.startScript
    $shell = Get-PreferredPowerShellPath
    & $shell -NoProfile -ExecutionPolicy Bypass -File $startScript
    if ($LASTEXITCODE -ne 0 -and -not (Test-ReverseTcpPort -Port ([int]$Definition.servicePort))) {
        throw 'Failed to start idapro service.'
    }

    if (-not (Wait-ForPort -Port ([int]$Definition.servicePort) -TimeoutSeconds 45)) {
        throw 'idapro service did not open port 13337 in time.'
    }
}

function Ensure-AndroidPlatformTools {
    $adb = Resolve-ReverseToolSpec -Name 'adb'
    if ($adb.Available) {
        return $adb
    }

    Ensure-WingetPackage -Id 'Google.PlatformTools' -Label 'Android SDK Platform-Tools'
    return (Resolve-ReverseToolSpec -Name 'adb')
}

function Ensure-GitCloneInstall {
    param(
        [Parameter(Mandatory = $true)]$Definition,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if ((Test-Path -LiteralPath $TargetPath -PathType Container) -and (Test-Path -LiteralPath (Join-Path $TargetPath '.git'))) {
        return $true
    }

    if (Test-Path -LiteralPath $TargetPath) {
        $backupPath = "$TargetPath.bak-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
        Move-Item -LiteralPath $TargetPath -Destination $backupPath -Force
    }

    Ensure-DownloadDirectory -Path (Split-Path -Path $TargetPath -Parent)

    $git = Get-FirstCommandPath -Names @('git')
    if ([string]::IsNullOrWhiteSpace($git)) {
        throw "Cannot clone $($Definition.repo) because git is not available."
    }

    & $git clone --depth 1 $Definition.repo $TargetPath
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed for $($Definition.repo)"
    }

    return $true
}

function Ensure-Capability {
    param([Parameter(Mandatory = $true)][string]$Name)

    $definition = Get-ReverseBootstrapDefinition -Name $Name
    if ($null -eq $definition) {
        throw "No bootstrap definition for capability: $Name"
    }

    # If capability is marked as not auto-installable, output guidance and skip
    if ($definition.PSObject.Properties['canAutoInstall'] -and $definition.canAutoInstall -eq $false) {
        $hint = if ($definition.PSObject.Properties['manualInstallHint']) { $definition.manualInstallHint } else { "Please install $Name manually. Docs: $($definition.docsUrl)" }
        Write-Warning "MANUAL_INSTALL_REQUIRED: $Name — $hint"
        # Still try to register MCP URL if applicable
        if ($definition.PSObject.Properties['mcpNames'] -and $definition.PSObject.Properties['mcpUrl']) {
            Ensure-McpServer -ServerName $definition.mcpNames[0] -ServerDefinition @{ url = $definition.mcpUrl }
        }
        return $false
    }

    $existingState = Get-ReverseCapabilityState -Name $Name
    if ($existingState -and -not $definition.PSObject.Properties['mcpNames']) {
        $toolSpec = $null
        try {
            $toolSpec = Resolve-ReverseToolSpec -Name $Name
        }
        catch {
            $toolSpec = $null
        }

        if ($toolSpec -and $toolSpec.Available) {
            return $toolSpec
        }
    }

    switch ($definition.bootstrapKind) {
        'github-release-zip' {
            # Generic handler for all github-release-zip capabilities
            $verifyName = if ($definition.PSObject.Properties['verifyCommand'] -and -not [string]::IsNullOrWhiteSpace($definition.verifyCommand)) {
                $definition.verifyCommand
            } else { $Name }
            return Ensure-GitHubZipInstall -Definition $definition -TargetPath $definition.installDir -VerifyName $verifyName
        }
        'git-clone' {
            return Ensure-GitCloneInstall -Definition $definition -TargetPath $definition.installDir
        }
        'github-release-jar-wrapper' {
            return Ensure-ApktoolInstall -Definition $definition
        }
        'pip-package' {
            Ensure-PipPackageInstall -Definition $definition
            return $true
        }
        'winget-package' {
            $wingetId = $definition.wingetId
            Ensure-WingetPackage -Id $wingetId -Label $Name
            $toolSpec = Resolve-ReverseToolSpec -Name $Name
            if (-not $toolSpec.Available) {
                throw "$Name was installed, but bootstrap could not resolve the executable in this process."
            }
            return $toolSpec
        }
        'npm-mcp' {
            Ensure-NodeRuntime
            $envMap = @{}
            foreach ($property in $definition.mcpEnv.PSObject.Properties) {
                $envMap[$property.Name] = $property.Value
            }
            $serverDefinition = Get-McpCommandServerDefinition -Command $definition.mcpCommand -Arguments @($definition.mcpArgs) -Env $envMap
            Ensure-McpServer -ServerName $definition.mcpNames[0] -ServerDefinition $serverDefinition
            return $true
        }
        'npm-global' {
            Ensure-NodeRuntime
            $npm = Get-NodeCommandPath -Name 'npm'
            if ([string]::IsNullOrWhiteSpace($npm)) {
                throw 'npm is not available after Node.js installation.'
            }
            & $npm install -g $definition.npmPackage
            if ($LASTEXITCODE -ne 0) {
                throw "npm install -g $($definition.npmPackage) failed."
            }
            # Run post-install command if specified (e.g. playwright install)
            if ($definition.PSObject.Properties['postInstall'] -and -not [string]::IsNullOrWhiteSpace($definition.postInstall)) {
                $postParts = $definition.postInstall -split ' ', 2
                $postCmd = Get-FirstCommandPath -Names @($postParts[0])
                if (-not [string]::IsNullOrWhiteSpace($postCmd)) {
                    if ($postParts.Count -gt 1) {
                        & $postCmd $postParts[1].Split(' ')
                    }
                    else {
                        & $postCmd
                    }
                }
                else {
                    # Try via npx
                    $npx = Get-NodeCommandPath -Name 'npx'
                    if ($npx) {
                        & $npx $definition.postInstall.Split(' ')
                    }
                }
            }
            # Run setup script if specified
            if ($definition.PSObject.Properties['setupScript'] -and -not [string]::IsNullOrWhiteSpace($definition.setupScript)) {
                $setupPath = $definition.setupScript
                if (Test-Path -LiteralPath $setupPath) {
                    $shell = Get-PreferredPowerShellPath
                    & $shell -NoProfile -ExecutionPolicy Bypass -File $setupPath -SkipBrowserInstall
                }
            }
            return $true
        }
        'local-http-mcp' {
            if ($Name -eq 'anything-analyzer') {
                Ensure-McpServer -ServerName 'anything-analyzer' -ServerDefinition @{ url = $definition.mcpUrl }
                if ($StartServices) {
                    Start-AnythingAnalyzerService -Definition $definition
                }
                return $true
            }
            if ($Name -eq 'idapro') {
                Ensure-Capability -Name 'idalib-mcp'
                Ensure-McpServer -ServerName 'idapro' -ServerDefinition @{ url = $definition.mcpUrl }
                if ($StartServices) {
                    Start-IdaProService -Definition $definition
                }
                return $true
            }
        }
        default {
            throw "Unsupported bootstrap kind: $($definition.bootstrapKind)"
        }
    }

    throw "Capability bootstrap fell through without action: $Name"
}

function Expand-CapabilityDependencies {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    $ordered = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    function Add-Capability {
        param([string]$CapabilityName)

        if ($seen.ContainsKey($CapabilityName)) {
            return
        }
        $seen[$CapabilityName] = $true

        $definition = Get-ReverseBootstrapDefinition -Name $CapabilityName
        if ($null -ne $definition -and $definition.PSObject.Properties['dependsOn']) {
            foreach ($dependency in @($definition.dependsOn)) {
                Add-Capability -CapabilityName $dependency
            }
        }

        $ordered.Add($CapabilityName)
    }

    foreach ($name in $Names) {
        Add-Capability -CapabilityName $name
    }

    return $ordered
}

$expandedCapabilities = Expand-CapabilityDependencies -Names $Capability
$results = @()

foreach ($name in $expandedCapabilities) {
    $definition = Get-ReverseBootstrapDefinition -Name $name
    if ($null -eq $definition) {
        $results += [pscustomobject]@{ name = $name; status = 'missing-definition' }
        continue
    }

    try {
        switch ($name) {
            'adb' {
                Ensure-AndroidPlatformTools | Out-Null
            }
            default {
                $ensureResult = Ensure-Capability -Name $name
                if ($ensureResult -eq $false) {
                    $def = Get-ReverseBootstrapDefinition -Name $name
                    $hint = if ($def -and $def.PSObject.Properties['manualInstallHint']) { $def.manualInstallHint } else { "Install manually. Docs: $($def.docsUrl)" }
                    $results += [pscustomobject]@{
                        name = $name
                        status = 'manual-required'
                        hint = $hint
                        docs_url = [string]$def.docsUrl
                    }
                    continue
                }
            }
        }

        $state = Get-ReverseCapabilityState -Name $name
        $results += [pscustomobject]@{
            name = $name
            status = 'ready'
            ready = if ($state) { $state.Ready } else { $null }
            registered = if ($state) { $state.Registered } else { $null }
            service_online = if ($state) { $state.ServiceOnline } else { $null }
        }
    }
    catch {
        $results += [pscustomobject]@{
            name = $name
            status = 'failed'
            error = $_.Exception.Message
        }
    }
}

if (-not $SkipRefresh) {
    $shell = Get-PreferredPowerShellPath
    & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'refresh-tool-index.ps1') | Out-Null
}

$results | ConvertTo-Json -Depth 5
