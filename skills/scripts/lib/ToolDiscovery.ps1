Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReverseToolCatalog {
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject]@{
            Name = 'jadx'
            Skill = 'apk-reverse'
            Purpose = 'Java 反编译'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'jadx' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\jadx\bin\jadx.bat') }
            )
        }
        [pscustomobject]@{
            Name = 'apktool'
            Skill = 'apk-reverse'
            Purpose = 'APK 解包与重建'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'apktool' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\apktool\apktool.bat') },
                [pscustomobject]@{ Type = 'java-jar'; Value = (Join-Path $env:USERPROFILE 'Tools\apktool\apktool.jar') }
            )
        }
        [pscustomobject]@{
            Name = 'adb'
            Skill = 'apk-reverse'
            Purpose = '设备连接与 logcat'
            VersionArgs = @('version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'adb' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe') }
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
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'apksigner' }
            )
        }
        [pscustomobject]@{
            Name = 'zipalign'
            Skill = 'apk-reverse'
            Purpose = 'APK 对齐'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'zipalign' }
            )
        }
        [pscustomobject]@{
            Name = 'frida'
            Skill = 'apk-reverse'
            Purpose = 'Frida 动态注入'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'frida' }
            )
        }
        [pscustomobject]@{
            Name = 'frida-ps'
            Skill = 'apk-reverse'
            Purpose = 'Frida 进程枚举'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'frida-ps' }
            )
        }
        [pscustomobject]@{
            Name = 'r2'
            Skill = 'radare2'
            Purpose = 'radare2 主分析器'
            VersionArgs = @('-v')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'r2' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\r2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\r2.exe') },
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\rabin2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\rabin2.exe') },
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\rasm2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\rasm2.exe') },
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\radiff2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\radiff2.exe') },
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\rahash2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\rahash2.exe') },
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\bin\rax2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\radare2\rax2.exe') },
                [pscustomobject]@{ Type = 'path'; Value = 'C:\Tools\radare2\bin\rax2.exe' }
            )
        }
        [pscustomobject]@{
            Name = 'python'
            Skill = 'reverse-engineering'
            Purpose = '辅助脚本执行'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'python' },
                [pscustomobject]@{ Type = 'command'; Value = 'python3' }
            )
        }
        [pscustomobject]@{
            Name = 'pip'
            Skill = 'reverse-engineering'
            Purpose = 'Python 包管理'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'pip' },
                [pscustomobject]@{ Type = 'command'; Value = 'pip3' }
            )
        }
        [pscustomobject]@{
            Name = 'node'
            Skill = 'js-reverse'
            Purpose = '运行 Node 侧 JS 复现与 MCP 客户端'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'node' }
            )
        }
        [pscustomobject]@{
            Name = 'npx'
            Skill = 'js-reverse'
            Purpose = '运行临时 npm 包与 MCP 入口'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'npx' }
            )
        }
        [pscustomobject]@{
            Name = 'jshookmcp'
            Skill = 'js-reverse'
            Purpose = '通过 npx 启动 @jshookmcp/jshook MCP（仍需先配置并启用 MCP server）'
            FixedVersion = '@jshookmcp/jshook@latest'
            VersionArgs = @()
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'npx' }
            )
        }
        [pscustomobject]@{
            Name = 'agent-browser'
            Skill = 'browser-automation'
            Purpose = '浏览器自动化（Playwright）：打开页面、点击、填表、爬取、截图'
            VersionArgs = @('--version')
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
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\ghidra\support\analyzeHeadless.bat') },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:USERPROFILE 'Tools\ghidra\ghidra_11.3_PUBLIC\support\analyzeHeadless.bat') }
            )
        }
        [pscustomobject]@{
            Name = 'playwright'
            Skill = 'browser-automation'
            Purpose = 'Playwright 浏览器引擎'
            VersionArgs = @('--version')
            Fallbacks = @(
                [pscustomobject]@{ Type = 'command'; Value = 'playwright' },
                [pscustomobject]@{ Type = 'path'; Value = (Join-Path $env:APPDATA 'npm\playwright.ps1') }
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
        '%USERPROFILE%' = $env:USERPROFILE
        '%LOCALAPPDATA%' = $env:LOCALAPPDATA
        '%APPDATA%' = $env:APPDATA
        '%TEMP%' = $env:TEMP
        '%SKILL_ROOT%' = Get-ReverseSkillRoot
    }

    foreach ($key in $replacements.Keys) {
        $resolved = $resolved.Replace($key, $replacements[$key])
    }

    return $resolved
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

    return Join-Path $env:USERPROFILE '.claude\mcp.json'
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
        $registeredNames = Get-ClaudeMcpServerNames
        foreach ($candidate in @($definition.mcpNames)) {
            if ($registeredNames -contains $candidate) {
                $registered = $true
                break
            }
        }
    }

    $serviceOnline = $false
    if ($definition.PSObject.Properties['servicePort'] -and $definition.servicePort) {
        $serviceOnline = Test-ReverseTcpPort -Port ([int]$definition.servicePort)
    }

    return [pscustomobject]@{
        Name = $definition.name
        BootstrapKind = $definition.bootstrapKind
        CanAutoInstall = [bool]$definition.canAutoInstall
        DocsUrl = [string]$definition.docsUrl
        Registered = $registered
        ServiceOnline = $serviceOnline
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
        switch ($candidate.Type) {
            'command' {
                $cmd = Get-Command -Name $candidate.Value -ErrorAction SilentlyContinue
                if ($null -ne $cmd) {
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
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
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
                        Source = 'FallbackPath'
                        ResolvedPath = $candidate.Value
                        Command = $candidate.Value
                        PrefixArgs = @()
                        VersionArgs = $definition.VersionArgs
                        FixedVersion = $fixedVersion
                    }
                }
            }
            'java-jar' {
                if (Test-Path -LiteralPath $candidate.Value) {
                    $java = Resolve-ReverseToolSpec -Name 'java'
                    return [pscustomobject]@{
                        Name = $definition.Name
                        Skill = $definition.Skill
                        Purpose = $definition.Purpose
                        Available = $true
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
    if ($Spec.PSObject.Properties['FixedVersion'] -and -not [string]::IsNullOrWhiteSpace([string]$Spec.FixedVersion)) {
        return [string]$Spec.FixedVersion
    }

    try {
        $output = & $Spec.Command @($Spec.VersionArgs) 2>&1 | Select-Object -First 1
        if ($null -eq $output) {
            return ''
        }
        return ([string]$output).Trim()
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
        [pscustomobject]@{
            Name = $spec.Name
            Skill = $spec.Skill
            Purpose = $spec.Purpose
            Available = $spec.Available
            ResolvedPath = $spec.ResolvedPath
            Source = $spec.Source
            Version = Get-ReverseToolVersion -Spec $spec
            BootstrapKind = if ($capabilityState) { $capabilityState.BootstrapKind } else { '' }
            CanAutoInstall = if ($capabilityState) { $capabilityState.CanAutoInstall } else { $false }
            DocsUrl = if ($capabilityState) { $capabilityState.DocsUrl } else { '' }
            McpRegistered = if ($capabilityState) { $capabilityState.Registered } else { $false }
            ServiceOnline = if ($capabilityState) { $capabilityState.ServiceOnline } else { $false }
        }
    }
}

