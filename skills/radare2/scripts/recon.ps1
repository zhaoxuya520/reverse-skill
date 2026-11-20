param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [int]$StringsLimit = 40,

    [int]$ImportsLimit = 80,

    [switch]$RunAnalysis
)

# 强制当前脚本使用 UTF-8 输出，尽量减少中文标题乱码。
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\..\scripts\lib\ToolDiscovery.ps1')

$bootstrapScript = Join-Path $PSScriptRoot '..\..\scripts\bootstrap-reverse.ps1'

function Get-RequiredToolSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $spec = Resolve-ReverseToolSpec -Name $Name
    if (-not $spec.Available) {
        # Attempt auto-bootstrap
        if (Test-Path -LiteralPath $bootstrapScript) {
            Write-Host "INFO: $Name not found, attempting auto-bootstrap..."
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript -Capability @($Name) -SkipRefresh | Out-Host
            $spec = Resolve-ReverseToolSpec -Name $Name
        }
        if (-not $spec.Available) {
            throw "缺少命令：$Name — 自动安装失败，请手动安装。参考: https://github.com/radareorg/radare2"
        }
    }
    return $spec
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
    [string]$Title
    )

    # 用固定分段标题，方便人看，也方便后续 grep。
    ""
    "=== $Title ==="
}

function Invoke-ReconTool {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Spec,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Nullable[int]]$OutputLimit = $null
    )

    if ($null -ne $OutputLimit) {
        # Keep the display limit without stopping the producer before its real
        # exit status is available. Do not buffer the complete tool output.
        & $Spec.Command @($Spec.PrefixArgs + $Arguments) | Select-Object -First $OutputLimit -Wait
    } else {
        & $Spec.Command @($Spec.PrefixArgs + $Arguments)
    }
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} {1} failed with exit code {2}." -f $Spec.Name, $Arguments[0], $LASTEXITCODE)
    }
}

$rabin2 = Get-RequiredToolSpec -Name 'rabin2'
$r2 = $null
if ($RunAnalysis) {
    $r2 = Get-RequiredToolSpec -Name 'r2'
}

# 将输入路径规范化成绝对路径，避免 r2/rabin2 在相对路径下歧义解析。
$resolvedPath = Resolve-Path -LiteralPath $TargetPath
$target = $resolvedPath.Path

"目标文件: $target"

Write-Section -Title '基本信息'
Invoke-ReconTool -Spec $rabin2 -Arguments @('-I', '--', $target)

Write-Section -Title '节区'
Invoke-ReconTool -Spec $rabin2 -Arguments @('-S', '--', $target)

Write-Section -Title '导入'
Invoke-ReconTool -Spec $rabin2 -Arguments @('-i', '--', $target) -OutputLimit $ImportsLimit

Write-Section -Title '导出'
Invoke-ReconTool -Spec $rabin2 -Arguments @('-E', '--', $target)

Write-Section -Title '字符串'
Invoke-ReconTool -Spec $rabin2 -Arguments @('-zz', '--', $target) -OutputLimit $StringsLimit

if ($RunAnalysis) {
    Write-Section -Title '函数与入口分析'
    Invoke-ReconTool -Spec $r2 -Arguments @('-A', '-q', '-c', 's entry0;afl;iz;ii;q', '--', $target)
}
