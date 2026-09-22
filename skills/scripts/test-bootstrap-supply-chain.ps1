$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('reverse-bootstrap-ps-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

function Ensure-DownloadDirectory { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null }
function Get-FirstCommandPath { param([string[]]$Names) return (Get-Command $Names[0]).Source }
function Ensure-NodeRuntime {}
function Get-NodeCommandPath { param([string]$Name) $command = Get-Command $Name -ErrorAction SilentlyContinue; if ($command) { return $command.Source } }
function Get-BootstrapDependency { return [pscustomobject]@{ package = 'pnpm@10.24.0'; version = '10.24.0' } }
function Approve-AnythingAnalyzerBuildScripts { param([string]$RepoDir) Set-Content (Join-Path $RepoDir 'pnpm-workspace.yaml') 'generated' }
function Test-AnythingAnalyzerElectronHealthy { return $true }

. (Join-Path $PSScriptRoot 'lib/BootstrapSupplyChain.ps1')

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Invoke-Git { param([string[]]$Arguments) & git @Arguments; if ($LASTEXITCODE -ne 0) { throw "git failed: $Arguments" } }
function Write-UnixExecutable {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $normalized = ($Content -replace "`r`n", "`n") -replace "`r", "`n"
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    [IO.File]::WriteAllText($Path, $normalized, [Text.UTF8Encoding]::new($false))
    & chmod +x $Path
}

try {
    $source = Join-Path $scratch 'source'
    New-Item -ItemType Directory -Path $source | Out-Null
    Invoke-Git -Arguments @('-C', $source, 'init', '--quiet')
    Invoke-Git -Arguments @('-C', $source, 'config', 'user.email', 'test@example.invalid')
    Invoke-Git -Arguments @('-C', $source, 'config', 'user.name', 'test')
    Set-Content (Join-Path $source 'package.json') '{}'
    Invoke-Git -Arguments @('-C', $source, 'add', 'package.json')
    Invoke-Git -Arguments @('-C', $source, 'commit', '--quiet', '-m', 'fixture')
    $pin = (& git -C $source rev-parse HEAD).Trim()
    $definition = [pscustomobject]@{ repo = $source; pinnedCommit = $pin }

    $target = Join-Path $scratch 'installed'
    Ensure-GitCloneInstall -Definition $definition -TargetPath $target | Out-Null
    Assert-True ((& git -C $target rev-parse HEAD).Trim() -eq $pin) 'pinned checkout was not promoted'
    Set-Content (Join-Path $target 'package.json') '{"dirty":true}'
    try { Ensure-GitCloneInstall -Definition $definition -TargetPath $target | Out-Null; throw 'dirty checkout accepted' } catch { Assert-True ($_.Exception.Message -match 'local changes') 'dirty rejection reason changed' }

    $failedTarget = Join-Path $scratch 'failed'
    $badDefinition = [pscustomobject]@{ repo = (Join-Path $scratch 'missing'); pinnedCommit = $pin }
    $failedFetchRejected = $false
    try { Ensure-GitCloneInstall -Definition $badDefinition -TargetPath $failedTarget | Out-Null } catch { $failedFetchRejected = $true }
    Assert-True $failedFetchRejected 'failed fetch accepted'
    Assert-True (-not (Test-Path $failedTarget)) 'failed fetch poisoned final path'
    Assert-True (@(Get-ChildItem $scratch -Filter '.reverse-bootstrap-*').Count -eq 0) 'failed fetch left staging path'

    $raceTarget = Join-Path $scratch 'race'
    $raceStage = Join-Path $scratch '.reverse-bootstrap-race'
    New-Item -ItemType Directory -Path $raceTarget, $raceStage | Out-Null
    Set-Content (Join-Path $raceTarget 'owner.txt') owner
    $raceRejected = $false
    try { Move-BootstrapDirectory -Source $raceStage -Destination $raceTarget } catch { $raceRejected = $true }
    Assert-True $raceRejected 'promotion race accepted'
    Assert-True ((Get-Content (Join-Path $raceTarget 'owner.txt')) -eq 'owner') 'promotion race modified concurrent target'
    Remove-Item -LiteralPath $raceStage -Recurse -Force

    $bin = Join-Path $scratch 'bin'
    New-Item -ItemType Directory -Path $bin | Out-Null
    $env:PATH = "$bin$([IO.Path]::PathSeparator)$env:PATH"
    $env:BOOTSTRAP_PS_LOG = Join-Path $scratch 'commands.log'
    $isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $stub = Join-Path $bin ($(if ($isWindowsHost) { 'npm.cmd' } else { 'npm' }))
    if ($isWindowsHost) {
        Set-Content $stub @'
@echo off
echo npm^|%*>>"%BOOTSTRAP_PS_LOG%"
'@
    }
    else {
        Write-UnixExecutable -Path $stub -Content @'
#!/bin/sh
printf "npm|%s\n" "$*" >> "$BOOTSTRAP_PS_LOG"
'@
    }
    $pnpm = Join-Path $bin ($(if ($isWindowsHost) { 'pnpm.cmd' } else { 'pnpm' }))
    if ($isWindowsHost) { Set-Content $pnpm "@echo off`r`necho 0" }
    else { Write-UnixExecutable -Path $pnpm -Content "#!/bin/sh`necho 0" }
    Ensure-Pnpm
    Assert-True ((Get-Content $env:BOOTSTRAP_PS_LOG) -match 'npm\|install -g pnpm@10.24.0') 'pnpm install was not pinned'

    Invoke-Git -Arguments @('-C', $target, 'checkout', '--quiet', '--', 'package.json')
    if ($isWindowsHost) {
        Set-Content $pnpm @'
@echo off
if "%1"=="--version" (echo 10.24.0) else (echo pnpm^|%*>>"%BOOTSTRAP_PS_LOG%")
'@
    }
    else {
        Write-UnixExecutable -Path $pnpm -Content @'
#!/bin/sh
[ "$1" = --version ] && { echo 10.24.0; exit; }
printf "pnpm|%s\n" "$*" >> "$BOOTSTRAP_PS_LOG"
'@
    }
    $commandLogBefore = Get-Content -LiteralPath $env:BOOTSTRAP_PS_LOG -Raw
    Ensure-Pnpm
    $commandLogAfter = Get-Content -LiteralPath $env:BOOTSTRAP_PS_LOG -Raw
    Assert-True ($commandLogAfter -eq $commandLogBefore) 'matching pnpm version triggered reinstall'
    function Approve-AnythingAnalyzerBuildScripts { param([string]$RepoDir) Set-Content (Join-Path $RepoDir 'pnpm-workspace.yaml') 'generated'; Set-Content (Join-Path $RepoDir 'package.json') '{"mutated":true}' }
    $dirtyRejected = $false
    try { Invoke-AnythingAnalyzerPinnedInstall -RepoDir $target -PnpmPath $pnpm -GitPath (Get-Command git).Source -PinnedCommit $pin } catch { $dirtyRejected = $_.Exception.Message -match 'local changes' }
    Assert-True $dirtyRejected 'post-install dirty checkout accepted or rejection reason changed'
    Assert-True (-not (Test-Path (Join-Path $target 'pnpm-workspace.yaml'))) 'generated workspace file was not removed'

    Invoke-Git -Arguments @('-C', $target, 'config', 'user.email', 'test@example.invalid')
    Invoke-Git -Arguments @('-C', $target, 'config', 'user.name', 'test')
    Invoke-Git -Arguments @('-C', $target, 'commit', '--allow-empty', '--quiet', '-m', 'wrong checkout')
    $wrongCommitRejected = $false
    try { Ensure-GitCloneInstall -Definition $definition -TargetPath $target | Out-Null } catch { $wrongCommitRejected = $_.Exception.Message -match 'expected' }
    Assert-True $wrongCommitRejected 'clean wrong-commit checkout accepted'

    $publicProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $publicTools = Join-Path $publicProfile 'Tools'
    $publicTarget = Join-Path $publicTools 'SecLists'
    if (Test-Path -LiteralPath $publicTarget) {
        Write-Host 'SKIP: public bootstrap exit regression (existing SecLists checkout)'
    }
    else {
        $createdPublicTools = -not (Test-Path -LiteralPath $publicTools)
        try {
            New-Item -ItemType Directory -Path $publicTarget -Force | Out-Null
            Invoke-Git -Arguments @('-C', $publicTarget, 'init', '--quiet')
            Invoke-Git -Arguments @('-C', $publicTarget, 'config', 'user.email', 'test@example.invalid')
            Invoke-Git -Arguments @('-C', $publicTarget, 'config', 'user.name', 'test')
            Set-Content (Join-Path $publicTarget 'fixture.txt') 'wrong checkout'
            Invoke-Git -Arguments @('-C', $publicTarget, 'add', 'fixture.txt')
            Invoke-Git -Arguments @('-C', $publicTarget, 'commit', '--quiet', '-m', 'fixture')

            $powerShellHost = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { Join-Path $PSHOME 'pwsh' }
            $childOutput = @(& $powerShellHost -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'bootstrap-reverse.ps1') -Capability seclists -SkipRefresh)
            $childExitCode = $LASTEXITCODE
            $global:LASTEXITCODE = 0
            $childResult = ($childOutput -join [Environment]::NewLine) | ConvertFrom-Json
            Assert-True ($childExitCode -ne 0) 'failed public bootstrap exited successfully'
            Assert-True ($childResult.status -eq 'failed') 'failed public bootstrap did not report failed status'
            Assert-True ($childResult.error -match 'Checkout verification failed') 'failed public bootstrap did not report checkout verification'
        }
        finally {
            Remove-Item -LiteralPath $publicTarget -Recurse -Force -ErrorAction SilentlyContinue
            if ($createdPublicTools -and (Test-Path -LiteralPath $publicTools) -and (@(Get-ChildItem -LiteralPath $publicTools -Force).Count -eq 0)) {
                Remove-Item -LiteralPath $publicTools -Force -ErrorAction SilentlyContinue
            }
        }
    }

    . (Join-Path $PSScriptRoot 'bootstrap-reverse.ps1') -Capability '__test_missing__' -SkipRefresh | Out-Null

    $genericManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bootstrap-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $kaliManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../kali/scripts/bootstrap-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($manifest in @($genericManifest, $kaliManifest)) {
        $pwntoolsDefinition = $manifest.capabilities | Where-Object { $_.name -eq 'pwntools' } | Select-Object -First 1
        Assert-True ($null -ne $pwntoolsDefinition) 'pwntools manifest definition missing'
        Assert-True ($pwntoolsDefinition.verifyPythonModule -eq 'pwn') 'pwntools must verify the importable pwn module'
        Assert-True (-not $pwntoolsDefinition.PSObject.Properties['verifyCommand']) 'pwntools must not advertise a nonexistent pwntools CLI'
    }

    $kaliBootstrapText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../kali/scripts/bootstrap-reverse.sh') -Raw -Encoding UTF8
    Assert-True ($kaliBootstrapText -match 'if \[\[ "\$name" != "pwntools" \]\] && command -v') 'Kali bootstrap still treats pwntools as a CLI command'
    Assert-True ($kaliBootstrapText -match "(?s)function python_module_available|python_module_available\(\)") 'Kali bootstrap is missing its Python module verifier'
    Assert-True ($kaliBootstrapText -match '(?s)pwntools\)\s+local verify_module package.*manifest_field pwntools verifyPythonModule.*manifest_field pwntools pipPackage.*python_module_available "\$verify_module".*install_pip_package "\$package".*if ! python_module_available "\$verify_module"') 'Kali bootstrap does not consume and enforce the pwntools manifest contract'

    $env:PWNTOOLS_TEST_LOG = Join-Path $scratch 'pwntools-python.log'
    $env:PWNTOOLS_TEST_READY = Join-Path $scratch 'pwntools-module-ready'
    $env:PWNTOOLS_TEST_NO_MODULE = '0'
    $pythonVerifier = Join-Path $bin ($(if ($isWindowsHost) { 'python.cmd' } else { 'python' }))
    if ($isWindowsHost) {
        Set-Content $pythonVerifier @'
@echo off
echo %*>>"%PWNTOOLS_TEST_LOG%"
if "%1"=="-c" (
  if exist "%PWNTOOLS_TEST_READY%" (exit /b 0) else (exit /b 1)
)
if "%1"=="-m" if "%2"=="pip" (
  if not "%PWNTOOLS_TEST_NO_MODULE%"=="1" type nul > "%PWNTOOLS_TEST_READY%"
  exit /b 0
)
exit /b 1
'@
    }
    else {
        Write-UnixExecutable -Path $pythonVerifier -Content @'
#!/bin/sh
printf '%s\n' "$*" >> "$PWNTOOLS_TEST_LOG"
if [ "${1:-}" = -c ]; then
  [ -f "$PWNTOOLS_TEST_READY" ]
  exit
fi
if [ "${1:-}" = -m ] && [ "${2:-}" = pip ]; then
  [ "${PWNTOOLS_TEST_NO_MODULE:-0}" = 1 ] || : > "$PWNTOOLS_TEST_READY"
  exit 0
fi
exit 1
'@
    }

    $pwntoolsInstall = [pscustomobject]@{
        name = 'pwntools'
        pipPackage = 'pwntools==4.15.0'
        verifyPythonModule = 'pwn'
    }
    Remove-Item -LiteralPath $env:PWNTOOLS_TEST_READY -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $env:PWNTOOLS_TEST_LOG -Value ''
    $pwntoolsResult = Ensure-PipPackageInstall -Definition $pwntoolsInstall
    Assert-True $pwntoolsResult.Verified 'pwntools install did not verify the pwn module'
    Assert-True $pwntoolsResult.Installed 'first pwntools verification should install the package'
    $pwntoolsLog = Get-Content -LiteralPath $env:PWNTOOLS_TEST_LOG -Raw
    Assert-True ($pwntoolsLog -match '-m pip install --upgrade pwntools==4\.15\.0') 'pwntools did not use the pinned manifest package'
    Set-Content -LiteralPath $env:PWNTOOLS_TEST_LOG -Value ''
    $pwntoolsExisting = Ensure-PipPackageInstall -Definition $pwntoolsInstall
    Assert-True $pwntoolsExisting.Verified 'existing pwn module was not accepted'
    Assert-True (-not $pwntoolsExisting.Installed) 'existing pwn module triggered a reinstall'
    Assert-True (-not ((Get-Content -LiteralPath $env:PWNTOOLS_TEST_LOG -Raw) -match '-m pip install')) 'ready pwn module reran pip install'

    Remove-Item -LiteralPath $env:PWNTOOLS_TEST_READY -Force -ErrorAction SilentlyContinue
    $env:PWNTOOLS_TEST_NO_MODULE = '1'
    $verificationFailure = $false
    try {
        Ensure-PipPackageInstall -Definition $pwntoolsInstall | Out-Null
    }
    catch {
        $verificationFailure = $_.Exception.Message -match "module 'pwn' is not importable"
    }
    Assert-True $verificationFailure 'pip success without an importable pwn module was accepted'
    $env:PWNTOOLS_TEST_NO_MODULE = '0'

    Remove-Item -LiteralPath $pythonVerifier -Force -ErrorAction SilentlyContinue
    Remove-Item Env:PWNTOOLS_TEST_LOG, Env:PWNTOOLS_TEST_READY, Env:PWNTOOLS_TEST_NO_MODULE -ErrorAction SilentlyContinue

    $script:gitCloneDefinition = [pscustomobject]@{
        name = 'test-git-clone'
        bootstrapKind = 'git-clone'
        canAutoInstall = $true
        installDir = (Join-Path $scratch 'test-git-clone')
    }
    $script:gitCloneVerifierCalled = $false
    function Get-ReverseBootstrapDefinition { param([string]$Name) return $script:gitCloneDefinition }
    function Get-ReverseCapabilityState { param([string]$Name) return [pscustomobject]@{ Ready = $true } }
    function Resolve-ReverseToolSpec { param([string]$Name) return [pscustomobject]@{ Available = $true } }
    function Ensure-GitCloneInstall {
        param($Definition, [string]$TargetPath)
        $script:gitCloneVerifierCalled = $true
        return [pscustomobject]@{ Verified = $true }
    }
    $gitCloneResult = Ensure-Capability -Name 'test-git-clone'
    Assert-True $script:gitCloneVerifierCalled 'available git-clone capability skipped checkout verification'
    Assert-True $gitCloneResult.Verified 'git-clone capability did not return checkout verification result'

    $script:serviceCheckoutVerifierCalled = $false
    function Ensure-GitCloneInstall {
        param($Definition, [string]$TargetPath)
        $script:serviceCheckoutVerifierCalled = $true
    }
    function Test-ReverseTcpPort { param([int]$Port) return $true }
    Start-AnythingAnalyzerService -Definition ([pscustomobject]@{
        installDir = (Join-Path $scratch 'anything-analyzer')
        repoUrl = $source
        pinnedCommit = $pin
        servicePort = 23816
    }) -AuthToken 'test-token'
    Assert-True $script:serviceCheckoutVerifierCalled 'running Anything Analyzer service skipped checkout verification'

    Write-Host 'PowerShell bootstrap supply-chain regression passed'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

# Expected native-command failures above can leave LASTEXITCODE non-zero on pwsh/Linux.
# Reaching this point means every assertion completed successfully.
exit 0
