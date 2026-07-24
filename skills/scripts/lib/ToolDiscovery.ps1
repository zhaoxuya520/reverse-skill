Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReverseUserProfilePath {
    [CmdletBinding()]
    param()

    $profilePath = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($profilePath)) {
        return $profilePath
    }
    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return $HOME
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    throw 'Unable to resolve the current user profile path.'
}

function Join-ReverseOptionalPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ChildPath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }
    return Join-Path $Path $ChildPath
}

function Get-ReverseToolCatalog {
    [CmdletBinding()]
    param()

    $userProfile = Get-ReverseUserProfilePath
    $localAppData = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
    $appData = [Environment]::GetEnvironmentVariable('APPDATA')

    return @(
        [pscustomobject]@{
            Name = 'jadx'
            Skill = 'apk-reverse'
            Purpose = 'Java 反编译'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'jadx' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\jadx\bin\jadx.bat') }
            )
        }
        [pscustomobject]@{
            Name = 'apktool'
            Skill = 'apk-reverse'
            Purpose = 'APK 解包与重建'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'apktool' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\apktool\apktool.bat') },
                [pscustomobject]@{ Type = 'java-jar'; Value = (Join-Path $userProfile 'Tools\apktool\apktool.jar') }
            )
        }
        [pscustomobject]@{
            Name = 'adb'
            Skill = 'apk-reverse'
            Purpose = '设备连接与 logcat'
            VersionArgs = @('version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'adb' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-ReverseOptionalPath -Path $localAppData -ChildPath 'Android\Sdk\platform-tools\adb.exe') }
            )
        }
        [pscustomobject]@{
            Name = 'java'
            Skill = 'apk-reverse'
            Purpose = '运行 jar 与 Java 工具链'
            VersionArgs = @('-version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'java' }
            )
        }
        [pscustomobject]@{
            Name = 'apksigner'
            Skill = 'apk-reverse'
            Purpose = 'APK 签名'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'apksigner' }
            )
        }
        [pscustomobject]@{
            Name = 'zipalign'
            Skill = 'apk-reverse'
            Purpose = 'APK 对齐'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'zipalign' }
            )
        }
        [pscustomobject]@{
            Name = 'frida'
            Skill = 'apk-reverse'
            Purpose = 'Frida 动态注入'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'frida' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-ReverseOptionalPath -Path $appData -ChildPath 'Python\Python3xx\Scripts\frida.exe') }
            )
        }
        [pscustomobject]@{
            Name = 'frida-ps'
            Skill = 'apk-reverse'
            Purpose = 'Frida 进程枚举'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'frida-ps' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-ReverseOptionalPath -Path $appData -ChildPath 'Python\Python3xx\Scripts\frida-ps.exe') }
            )
        }
        [pscustomobject]@{
            Name = 'r2'
            Skill = 'radare2'
            Purpose = 'radare2 主分析器'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'r2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\r2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\r2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\r2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'rabin2'
            Skill = 'radare2'
            Purpose = '二进制侦察'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'rabin2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\rabin2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\rabin2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\rabin2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'rasm2'
            Skill = 'radare2'
            Purpose = '汇编/反汇编'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'rasm2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\rasm2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\rasm2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\rasm2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'radiff2'
            Skill = 'radare2'
            Purpose = '二进制差分'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'radiff2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\radiff2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\radiff2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\radiff2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'rahash2'
            Skill = 'radare2'
            Purpose = '哈希与校验'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'rahash2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\rahash2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\rahash2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\rahash2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'rax2'
            Skill = 'radare2'
            Purpose = '进制与位运算转换'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'rax2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\bin\rax2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\radare2\rax2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\rax2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'python'
            Skill = 'reverse-engineering'
            Purpose = '辅助脚本执行'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'python' },
                [pscustomobject]@{ Type = 'command'; Value = 'python3' }
            )
        }
        [pscustomobject]@{
            Name = 'pip'
            Skill = 'reverse-engineering'
            Purpose = 'Python 包管理'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'pip' },
                [pscustomobject]@{ Type = 'command'; Value = 'pip3' }
            )
        }
        [pscustomobject]@{
            Name = 'node'
            Skill = 'js-reverse'
            Purpose = '运行 Node 侧 JS 复现与 MCP 客户端'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'node' }
            )
        }
        [pscustomobject]@{
            Name = 'npx'
            Skill = 'js-reverse'
            Purpose = '运行临时 npm 包与 MCP 入口'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'npx' }
            )
        }
        [pscustomobject]@{
            Name = 'jshookmcp'
            Skill = 'js-reverse'
            Purpose = '通过 npx 启动 @jshookmcp/jshook MCP（仍需先配置并启用 MCP server）'
            FixedVersion = '@jshookmcp/jshook@0.3.4'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'npx' }
            )
        }
        [pscustomobject]@{
            Name = 'agent-browser'
            Skill = 'browser-automation'
            Purpose = '浏览器自动化（Playwright）：打开页面、点击、填表、爬取、截图'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'agent-browser' }
            )
        }
        [pscustomobject]@{
            Name = 'analyzeHeadless'
            Skill = 'reverse-engineering'
            Purpose = 'Ghidra 无头分析（免费 IDA 替代）'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'analyzeHeadless' },
                [pscustomobject]@{ Type = 'path'; Value = '&lt;工具根目录&gt;\ghidra\support\analyzeHeadless.bat' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\ghidra\support\analyzeHeadless.bat') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $userProfile 'Tools\ghidra\ghidra_11.3_PUBLIC\support\analyzeHeadless.bat') }
            )
        }
        [pscustomobject]@{
            Name = 'playwright'
            Skill = 'browser-automation'
            Purpose = 'Playwright 浏览器引擎'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'playwright' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-ReverseOptionalPath -Path $appData -ChildPath 'npm\playwright.ps1') }
            )
        }
        [pscustomobject]@{
            Name = 'proxycat'
            Skill = 'pentest-tools'
            Purpose = '代理池管理与轮换'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'proxycat' }
            )
        }
        [pscustomobject]@{
            Name = 'seclists'
            Skill = 'pentest-tools'
            Purpose = 'Security wordlists'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'directory'; Value = (Join-Path $userProfile 'Tools\SecLists') },
                [pscustomobject]@{ Type = 'directory'; Value = 'C:\Tools\SecLists' },
                [pscustomobject]@{ Type = 'directory'; Value = '/usr/share/seclists' }
            )
        }
        [pscustomobject]@{
            Name = 'pentestswarm'
            Skill = 'pentest-tools'
            Purpose = '群体智能自主渗透与 MCP 执行'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'pentestswarm' }
            )
        }
        [pscustomobject]@{
            Name = 'nmap'
            Skill = 'pentest-tools'
            Purpose = '端口扫描与服务识别'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'nmap' },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Program Files (x86)\Nmap\nmap.exe' },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Program Files\Nmap\nmap.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'binwalk'
            Skill = 'firmware-pentest'
            Purpose = '固件提取与分析'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'binwalk' }
            )
        }
        [pscustomobject]@{
            Name = 'yara'
            Skill = 'malware-analysis'
            Purpose = '恶意软件规则匹配引擎'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'yara' },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Program Files\yara\yara.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'pwntools'
            Skill = 'reverse-engineering'
            Purpose = 'CTF pwn 利用开发框架'
            FixedVersion = 'v0.5.0'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'pwntools' },
                [pscustomobject]@{ Type = 'command'; Value = 'pwn' }
            )
        }
    )
}

function Get-ReverseSkillRoot {
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

function Resolve-ReversePathTemplate {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $resolved = $Value
    $replacements = @{
        '%USERPROFILE%' = (Get-ReverseUserProfilePath)
        '%LOCALAPPDATA%' = [string]([Environment]::GetEnvironmentVariable('LOCALAPPDATA'))
        '%APPDATA%' = [string]([Environment]::GetEnvironmentVariable('APPDATA'))
        '%TEMP%' = [string]([Environment]::GetEnvironmentVariable('TEMP'))
        '%SKILL_ROOT%' = Get-ReverseSkillRoot
    }

    foreach ($key in $replacements.Keys) {
        $resolved = $resolved.Replace($key, $replacements[$key])
    }

    return $resolved
}

function ConvertTo-ReverseHashtable {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [string] -or $InputObject.GetType().IsPrimitive -or $InputObject -is [decimal]) {
        return $InputObject
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $map = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $map[[string]$key] = ConvertTo-ReverseHashtable -InputObject $InputObject[$key]
        }
        return $map
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $map = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $map[$property.Name] = ConvertTo-ReverseHashtable -InputObject $property.Value
        }
        return $map
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-ReverseHashtable -InputObject $item)
        }
        return $items
    }

    return $InputObject
}

function Read-ReverseJsonAsHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    return ConvertTo-ReverseHashtable -InputObject $json
}

function Get-ReverseBootstrapManifestPath {
    [CmdletBinding()]
    param()

    return Join-Path (Get-ReverseSkillRoot) 'scripts\bootstrap-manifest.json'
}

function Get-ReverseBootstrapCatalog {
    [CmdletBinding()]
    param()

    if ((Get-Variable -Name 'ReverseBootstrapCatalog' -Scope Script -ErrorAction SilentlyContinue) -and $script:ReverseBootstrapCatalog) {
        return $script:ReverseBootstrapCatalog
    }

    $path = Get-ReverseBootstrapManifestPath
    if (-not (Test-Path -LiteralPath $path)) {
        $script:ReverseBootstrapCatalog = @()
        return $script:ReverseBootstrapCatalog
    }

    $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $catalog = @()
    foreach ($capability in @($json.capabilities)) {
        $clone = [pscustomobject]@{}
        foreach ($property in $capability.PSObject.Properties) {
            $value = $property.Value
            if ($value -is [string]) {
                $value = Resolve-ReversePathTemplate -Value $value
            }
            elseif ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                $items = @()
                foreach ($item in $value) {
                    if ($item -is [string]) {
                        $items += Resolve-ReversePathTemplate -Value $item
                    }
                    else {
                        $items += $item
                    }
                }
                $value = $items
            }
            elseif ($null -ne $value -and $value -is [System.Management.Automation.PSCustomObject]) {
                $propCount = @($value.PSObject.Properties).Count
                if ($propCount -gt 0) {
                    $map = [ordered]@{}
                    foreach ($subProperty in $value.PSObject.Properties) {
                        $subValue = $subProperty.Value
                        if ($subValue -is [string]) {
                            $subValue = Resolve-ReversePathTemplate -Value $subValue
                        }
                        $map[$subProperty.Name] = $subValue
                    }
                    $value = [pscustomobject]$map
                }
            }
            Add-Member -InputObject $clone -NotePropertyName $property.Name -NotePropertyValue $value
        }
        $catalog += $clone
    }

    $script:ReverseBootstrapCatalog = $catalog
    return $script:ReverseBootstrapCatalog
}

function Get-ReverseBootstrapDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-ReverseBootstrapCatalog | Where-Object { $_.name -eq $Name } | Select-Object -First 1
}

function Get-ClaudeMcpConfigPath {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_MCP_CONFIG)) {
        return $env:CLAUDE_MCP_CONFIG
    }
    $profilePath = Get-ReverseUserProfilePath
    return Join-Path (Join-Path $profilePath '.claude') 'mcp.json'
}

function Get-CodexConfigPath {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_CONFIG_PATH)) {
        return $env:CODEX_CONFIG_PATH
    }
    $profilePath = Get-ReverseUserProfilePath
    return Join-Path (Join-Path $profilePath '.codex') 'config.toml'
}

function Get-ClaudeMcpServerNames {
    [CmdletBinding()]
    param()

    $configPath = Get-ClaudeMcpConfigPath
    if (-not (Test-Path -LiteralPath $configPath)) {
        return @()
    }

    try {
        $json = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $json.mcpServers) {
            return @()
        }
        return @($json.mcpServers.PSObject.Properties.Name)
    }
    catch {
        return @()
    }
}

function Get-CodexMcpServerNames {
    [CmdletBinding()]
    param()

    $configPath = Get-CodexConfigPath
    if (-not (Test-Path -LiteralPath $configPath)) {
        return @()
    }

    $pattern = '^\[mcp_servers\.([^\].]+)\]\s*$'
    $names = @()
    foreach ($match in Select-String -LiteralPath $configPath -Pattern $pattern) {
        if ($match.Matches.Count -gt 0) {
            $names += $match.Matches[0].Groups[1].Value
        }
    }

    return @($names | Sort-Object -Unique)
}

function Get-ReverseMcpServerNames {
    [CmdletBinding()]
    param()

    $names = @()
    $names += @(Get-ClaudeMcpServerNames)
    $names += @(Get-CodexMcpServerNames)
    return @($names | Sort-Object -Unique)
}

function Test-ReverseTcpPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,
        [string]$TargetHost = '127.0.0.1'
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($TargetHost, $Port, $null, $null)
        $connected = $async.AsyncWaitHandle.WaitOne(1000, $false)
        if (-not $connected) {
            $client.Close()
            return $false
        }
        $client.EndConnect($async)
        $client.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Test-ReverseMcpHttp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,

        [string]$TargetHost = '127.0.0.1',

        [int]$TimeoutMs = 3000
    )

    try {
        $body = '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
        $uri = "http://${TargetHost}:$Port/mcp"
        $req = [System.Net.HttpWebRequest]::Create($uri)
        $req.Method = 'POST'
        $req.ContentType = 'application/json'
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $req.ContentLength = $bytes.Length
        $reqStream = $req.GetRequestStream()
        $reqStream.Write($bytes, 0, $bytes.Length)
        $reqStream.Close()
        $resp = $req.GetResponse()
        $statusCode = [int]$resp.StatusCode
        $resp.Close()
        return $statusCode -eq 200
    }
    catch {
        return $false
    }
}

function Add-ReverseProcessPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }

    $separator = [System.IO.Path]::PathSeparator
    $entries = @($env:PATH -split [regex]::Escape([string]$separator)) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($entries -contains $Path) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($env:PATH)) {
        $env:PATH = $Path
    }
    else {
        $env:PATH = "$Path$separator$env:PATH"
    }
}

function Resolve-ReverseCommandCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $commands = @(Get-Command -Name $Name -All -ErrorAction SilentlyContinue)
    if ($commands.Count -eq 0) {
        return $null
    }

    if ($Name -in @('npm', 'npx', 'pnpm', 'yarn', 'corepack')) {
        $cmdShim = $commands | Where-Object { $_.CommandType -eq 'Application' -and $_.Source -match '\.cmd$' } | Select-Object -First 1
        if ($cmdShim) {
            return $cmdShim
        }

        $application = $commands | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
        if ($application) {
            return $application
        }
    }

    return ($commands | Select-Object -First 1)
}

function Get-ReverseCapabilityState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $definition = Get-ReverseBootstrapDefinition -Name $Name
    if ($null -eq $definition) {
        return $null
    }

    $registered = $false
    if ($definition.PSObject.Properties['mcpNames']) {
        $registeredNames = Get-ReverseMcpServerNames
        foreach ($candidate in @($definition.mcpNames)) {
            if ($registeredNames -contains $candidate) {
                $registered = $true
                break
            }
        }
    }

    $serviceOnline = $false
    $mcpHttpVerified = $false
    if ($definition.PSObject.Properties['servicePort'] -and $definition.servicePort) {
        $serviceOnline = Test-ReverseTcpPort -Port ([int]$definition.servicePort)
        # If TCP passes, attempt HTTP MCP protocol-level handshake for higher confidence
        if ($serviceOnline) {
            $mcpHttpVerified = Test-ReverseMcpHttp -Port ([int]$definition.servicePort)
        }
    }

    $toolReady = $false
    try {
        $toolSpec = Resolve-ReverseToolSpec -Name $Name
        $toolReady = [bool]$toolSpec.Available
    }
    catch {
        $toolReady = $false
    }

    $verificationMode = if ($definition.PSObject.Properties['verificationMode']) { [string]$definition.verificationMode } else { '' }
    $ready = $toolReady
    if ($definition.PSObject.Properties['mcpNames']) {
        switch ($verificationMode) {
            'service-and-registration' {
                $ready = $registered -and $serviceOnline
            }
            'service-or-registration' {
                $ready = $registered -or $serviceOnline
            }
            default {
                if ($definition.bootstrapKind -eq 'npm-mcp') {
                    $ready = $registered -and $toolReady
                }
                else {
                    $ready = $registered -or $toolReady
                }
            }
        }
    }

    return [pscustomobject]@{
        Name = $definition.name
        BootstrapKind = $definition.bootstrapKind
        CanAutoInstall = [bool]$definition.canAutoInstall
        DocsUrl = [string]$definition.docsUrl
        Ready = $ready
        Registered = $registered
        ServiceOnline = $serviceOnline
        McpHttpVerified = $mcpHttpVerified
    }
}

function Get-ReverseToolDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $definition = Get-ReverseToolCatalog | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $definition) {
        throw "Unknown reverse tool: $Name"
    }

    $bootstrap = Get-ReverseBootstrapDefinition -Name $Name
    if ($null -ne $bootstrap) {
        foreach ($property in $bootstrap.PSObject.Properties) {
            if (-not $definition.PSObject.Properties[$property.Name]) {
                Add-Member -InputObject $definition -NotePropertyName $property.Name -NotePropertyValue $property.Value
            }
        }
    }

    return $definition
}

function Resolve-ReverseToolSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $definition = Get-ReverseToolDefinition -Name $Name
    $fixedVersion = if ($definition.PSObject.Properties['FixedVersion']) { [string]$definition.FixedVersion } else { '' }

    foreach ($candidate in $definition.Fallbacks) {
        if (-not $candidate.PSObject.Properties['Value'] -or [string]::IsNullOrWhiteSpace([string]$candidate.Value)) {
            continue
        }

        switch ($candidate.Type) {
            'command' {
                $cmd = Resolve-ReverseCommandCandidate -Name $candidate.Value
                if ($null -ne $cmd) {
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
                        IsExecutable = $true
                        IsDirectory = $false
                        Source = 'Get-Command'
                        ResolvedPath = $cmd.Source
                        Command = $cmd.Source
                        PrefixArgs = @()
                        VersionArgs = $definition.VersionArgs
                        FixedVersion = $fixedVersion
                    }
                }
            }
            'path' {
                if (Test-Path -LiteralPath $candidate.Value) {
                    Add-ReverseProcessPath -Path (Split-Path -Path $candidate.Value -Parent)
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
                        IsExecutable = $true
                        IsDirectory = $false
                        Source = 'FallbackPath'
                        ResolvedPath = $candidate.Value
                        Command = $candidate.Value
                        PrefixArgs = @()
                        VersionArgs = $definition.VersionArgs
                        FixedVersion = $fixedVersion
                    }
                }
            }
            'directory' {
                if (Test-Path -LiteralPath $candidate.Value -PathType Container) {
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
                        IsExecutable = $false
                        IsDirectory = $true
                        Source = 'FallbackDirectory'
                        ResolvedPath = $candidate.Value
                        Command = ''
                        PrefixArgs = @()
                        VersionArgs = @()
                        FixedVersion = $fixedVersion
                    }
                }
            }
            'java-jar' {
                if (Test-Path -LiteralPath $candidate.Value) {
                    $java = Resolve-ReverseToolSpec -Name 'java'
                    if (-not $java.Available -or [string]::IsNullOrWhiteSpace([string]$java.Command)) {
                        continue
                    }
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
                        IsExecutable = $true
                        IsDirectory = $false
                        Source = 'FallbackJavaJar'
                        ResolvedPath = $candidate.Value
                        Command = $java.Command
                        PrefixArgs = @('-jar', $candidate.Value)
                        VersionArgs = @('-jar', $candidate.Value, '--version')
                        FixedVersion = $fixedVersion
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        Name = $definition.Name
        Skill = $definition.Skill
        Purpose = $definition.Purpose
        Available = $false
        IsExecutable = $false
        IsDirectory = $false
        Source = 'Missing'
        ResolvedPath = ''
        Command = ''
        PrefixArgs = @()
        VersionArgs = $definition.VersionArgs
        FixedVersion = $fixedVersion
    }
}

function Get-ReverseToolVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Spec
    )

    if (-not $Spec.Available) {
        return ''
    }
    if ([string]::IsNullOrWhiteSpace([string]$Spec.Command) -or @($Spec.VersionArgs).Count -eq 0) {
        return ''
    }
    if ($Spec.PSObject.Properties['FixedVersion'] -and -not [string]::IsNullOrWhiteSpace([string]$Spec.FixedVersion)) {
        return [string]$Spec.FixedVersion
    }

    try {
        $rawLines = & $Spec.Command @($Spec.VersionArgs) 2>&1 | Select-Object -First 10
        foreach ($line in $rawLines) {
            $text = ([string]$line).Trim()
            if ($text -and $text -notmatch '^Module manifest file error' -and $text -notmatch '^\s*->\s*Invalid line') {
                return $text
            }
        }
        return ''
    }
    catch {
        return ''
    }
}

function Invoke-ReverseTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string[]]$Arguments = @()
    )

    $spec = Resolve-ReverseToolSpec -Name $Name
    if (-not $spec.Available) {
        throw "Missing required CLI tool: $Name"
    }
    if ($spec.PSObject.Properties['IsExecutable'] -and -not [bool]$spec.IsExecutable) {
        throw "Tool '$Name' is available at '$($spec.ResolvedPath)' but is not an executable command."
    }
    if ([string]::IsNullOrWhiteSpace([string]$spec.Command)) {
        throw "Tool '$Name' is available but does not expose an executable command."
    }

    & $spec.Command @($spec.PrefixArgs + $Arguments)
    return $LASTEXITCODE
}

function Get-ReverseToolReport {
    [CmdletBinding()]
    param(
        [string[]]$Names
    )

    $selectedNames = if ($null -ne $Names -and @($Names).Count -gt 0) { $Names } else { (Get-ReverseToolCatalog).Name }

    foreach ($name in $selectedNames) {
        $spec = Resolve-ReverseToolSpec -Name $name
        $capabilityState = Get-ReverseCapabilityState -Name $name
        $versionText = Get-ReverseToolVersion -Spec $spec
        $availableHonest = [bool]$spec.Available
        $sourceHonest = $spec.Source
        # Honesty: path/command presence is not enough when version/runtime probe fails
        # (classic: macOS /usr/bin/java stub without a JDK).
        if ($availableHonest -and -not [string]::IsNullOrWhiteSpace([string]$versionText)) {
            if ($versionText -match '(?i)unable to locate|no java runtime|not found|command not found|no such file|could not find|cannot find|not installed') {
                $availableHonest = $false
                $sourceHonest = 'BrokenRuntime'
            }
        }
        # Honesty: jshookmcp requires MCP client registration, not merely npx on PATH.
        if ($name -eq 'jshookmcp') {
            $registered = $false
            try {
                $cap = Get-ReverseCapabilityState -Name 'jshookmcp'
                if ($null -ne $cap -and $cap.PSObject.Properties['Registered'] -and [bool]$cap.Registered) {
                    $registered = $true
                }
            } catch { $registered = $false }
            if (-not $registered) {
                # also probe mcp.json keys directly
                $mcpPaths = @()
                if ($env:CLAUDE_MCP_CONFIG) { $mcpPaths += $env:CLAUDE_MCP_CONFIG }
                $mcpPaths += (Join-Path $HOME '.claude/mcp.json')
                $mcpPaths += (Join-Path $HOME '.config/claude/mcp.json')
                foreach ($mp in $mcpPaths) {
                    if (-not (Test-Path -LiteralPath $mp)) { continue }
                    try {
                        $raw = Get-Content -LiteralPath $mp -Raw -Encoding UTF8
                        if ($raw -match '(?i)jshook') { $registered = $true; break }
                    } catch {}
                }
            }
            if ($registered) {
                $availableHonest = $true
                $sourceHonest = 'McpRegistered'
                if ([string]::IsNullOrWhiteSpace([string]$versionText)) {
                    $versionText = 'MCP server registered (jshook)'
                }
            } else {
                $availableHonest = $false
                $sourceHonest = 'NpxOnlyOrMissing'
                $npx = Get-Command npx -ErrorAction SilentlyContinue
                if ($npx) {
                    $versionText = 'npx present; MCP server NOT registered/enabled'
                    if (-not $spec.ResolvedPath) { $spec | Add-Member -NotePropertyName ResolvedPath -NotePropertyValue $npx.Source -Force }
                } else {
                    $versionText = 'npx missing; MCP server not registered'
                }
            }
        }
        [pscustomobject]@{
            Name = $spec.Name
            Skill = $spec.Skill
            Purpose = $spec.Purpose
            Available = $availableHonest
            IsExecutable = if ($spec.PSObject.Properties['IsExecutable']) { $spec.IsExecutable } else { -not [string]::IsNullOrWhiteSpace([string]$spec.Command) }
            IsDirectory = if ($spec.PSObject.Properties['IsDirectory']) { $spec.IsDirectory } else { $false }
            ResolvedPath = $spec.ResolvedPath
            Source = $sourceHonest
            Version = $versionText
            BootstrapKind = if ($capabilityState) { $capabilityState.BootstrapKind } else { '' }
            CanAutoInstall = if ($capabilityState) { $capabilityState.CanAutoInstall } else { $false }
            DocsUrl = if ($capabilityState) { $capabilityState.DocsUrl } else { '' }
            Ready = if ($capabilityState) { $capabilityState.Ready } else { $availableHonest }
            McpRegistered = if ($capabilityState) { $capabilityState.Registered } else { $false }
            ServiceOnline = if ($capabilityState) { $capabilityState.ServiceOnline } else { $false }
            McpHttpVerified = if ($capabilityState) { $capabilityState.McpHttpVerified } else { $false }
        }
    }
}
