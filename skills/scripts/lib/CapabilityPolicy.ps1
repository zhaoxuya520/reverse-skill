# Minimal capability policy for PowerShell entrypoints.
# Markdown and field-journal text are never inputs to this policy.

function Get-CapabilityPolicy {
    param([Parameter(Mandatory = $true)] [string] $Capability)

    $requested = $Capability.Trim()
    $action = if ($requested -eq 'network.request') { 'request.send' } else { $requested }
    $common = @{
        action = $action
        readOnly = $false
        network = $false
        credentials = $false
        destructive = $false
        requiresScope = $false
        requiresConfirmation = $false
        filesystemRead = $false
        filesystemWrite = $false
        deviceControl = $false
        sensitiveOutput = $false
    }
    switch ($action) {
        'passive.read' {
            $common.readOnly = $true
            $common.sensitiveOutput = $true
        }
        'request.send' {
            $common.network = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'replay.send' {
            $common.network = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'scan.active' {
            $common.network = $true; $common.destructive = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'intruder.run' {
            $common.network = $true; $common.destructive = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'config.write' {
            $common.destructive = $true; $common.filesystemWrite = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'cookie.write' {
            $common.credentials = $true; $common.destructive = $true; $common.network = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'websocket.send' {
            $common.network = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        'project.write' {
            $common.filesystemWrite = $true; $common.destructive = $true; $common.requiresScope = $true; $common.requiresConfirmation = $true
        }
        default { return $null }
    }
    return [pscustomobject]$common
}

function Test-CapabilityPolicy {
    param(
        [Parameter(Mandatory = $true)] [string] $Capability,
        [switch] $Authenticated,
        [switch] $ScopeValid,
        [switch] $Confirmed
    )

    $policy = Get-CapabilityPolicy -Capability $Capability
    if ($null -eq $policy) {
        return [pscustomobject]@{ Status = 'blocked'; Reason = 'unknown capability'; Capability = $Capability; Action = ''; Policy = $null }
    }
    if (-not $Authenticated) {
        return [pscustomobject]@{ Status = 'blocked'; Reason = 'authentication required'; Capability = $Capability; Action = $policy.action; Policy = $policy }
    }
    if ($policy.requiresScope -and -not $ScopeValid) {
        return [pscustomobject]@{ Status = 'blocked'; Reason = 'valid scope required'; Capability = $Capability; Action = $policy.action; Policy = $policy }
    }
    if ($policy.requiresConfirmation -and -not $Confirmed) {
        return [pscustomobject]@{ Status = 'confirmation_required'; Reason = 'user confirmation required'; Capability = $Capability; Action = $policy.action; Policy = $policy }
    }
    return [pscustomobject]@{ Status = 'allowed'; Reason = 'policy allowed'; Capability = $Capability; Action = $policy.action; Policy = $policy }
}
