# Shared scope validation and exact target matching for Windows entrypoints.
# This file intentionally uses only PowerShell 5.1-compatible APIs.

function New-ScopeIssueList {
    New-Object System.Collections.Generic.List[string]
}

function Get-ScopeProperty {
    param(
        [Parameter(Mandatory = $true)] $Scope,
        [Parameter(Mandatory = $true)] [string] $Name
    )
    $property = $Scope.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Test-ScopePathValue {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [string] $RawPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    foreach ($value in @($Path, $RawPath)) {
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $lower = $value.ToLowerInvariant()
        if ($value.Contains('\') -or $lower.Contains('%2f') -or $lower.Contains('%5c') -or $lower.Contains('%2e')) { return $false }
        if ($value -match '(^|/)\.{1,2}(/|$)') { return $false }
    }
    return $true
}

function Test-ScopeDocument {
    param(
        [Parameter(Mandatory = $true)] $Scope,
        [switch] $RequireGranted
    )

    $issues = New-ScopeIssueList
    if ($null -eq $Scope) {
        [void]$issues.Add('scope document is null')
        return [pscustomobject]@{ Valid = $false; Issues = $issues.ToArray(); Scope = $Scope }
    }

    foreach ($required in @('schemaVersion', 'scopeId', 'status', 'approvalId', 'issuedAt', 'expiresAt', 'targets', 'allowedActions')) {
        $property = $Scope.PSObject.Properties[$required]
        if ($null -eq $property) {
            [void]$issues.Add("missing scope field: $required")
            continue
        }
        if ($required -notin @('targets', 'allowedActions') -and ([string]$property.Value).Trim().Length -eq 0) {
            [void]$issues.Add("missing scope field: $required")
        }
    }

    if ([string]$Scope.schemaVersion -ne '1') { [void]$issues.Add('schemaVersion must be 1') }
    if (@('draft', 'granted', 'denied', 'expired') -notcontains [string]$Scope.status) {
        [void]$issues.Add('status must be draft, granted, denied, or expired')
    }

    $issued = [datetimeoffset]::MinValue
    $expires = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse([string]$Scope.issuedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$issued)) {
        [void]$issues.Add('issuedAt must be an ISO-8601 timestamp')
    }
    if (-not [datetimeoffset]::TryParse([string]$Scope.expiresAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$expires)) {
        [void]$issues.Add('expiresAt must be an ISO-8601 timestamp')
    }
    if ($expires -ne [datetimeoffset]::MinValue -and $issued -ne [datetimeoffset]::MinValue -and $expires -le $issued) {
        [void]$issues.Add('expiresAt must be later than issuedAt')
    }

    $targets = @($Scope.targets)
    $actions = @($Scope.allowedActions)
    if ([string]::IsNullOrWhiteSpace([string]$Scope.approvalId)) {
        [void]$issues.Add('approvalId must not be empty')
    }
    if ($Scope.status -eq 'granted' -or $RequireGranted) {
        if ($Scope.status -ne 'granted') { [void]$issues.Add('scope status is not granted') }
        if ([string]$Scope.approvalId -eq 'FILL_ME') { [void]$issues.Add('approvalId must be supplied by the user') }
        if ($targets.Count -eq 0) { [void]$issues.Add('granted scope requires at least one target') }
        if ($actions.Count -eq 0) { [void]$issues.Add('granted scope requires at least one allowed action') }
        if ($expires -ne [datetimeoffset]::MinValue -and $expires -le [datetimeoffset]::Now) {
            [void]$issues.Add('scope is expired')
        }
    }

    foreach ($target in $targets) {
        if ($null -eq $target) { [void]$issues.Add('target must not be null'); continue }
        $type = [string](Get-ScopeProperty -Scope $target -Name 'type')
        if ($type -eq 'network') {
            $scheme = [string](Get-ScopeProperty -Scope $target -Name 'scheme')
            $targetHost = [string](Get-ScopeProperty -Scope $target -Name 'host')
            $port = Get-ScopeProperty -Scope $target -Name 'port'
            $prefixes = @($target.pathPrefixes)
            if (@('http', 'https') -notcontains $scheme) { [void]$issues.Add('network target scheme must be http or https') }
            if ([string]::IsNullOrWhiteSpace($targetHost) -or $targetHost -match '[*\s/]') { [void]$issues.Add('network target host must be exact and contain no wildcard') }
            if ($null -eq $port -or [int]$port -lt 1 -or [int]$port -gt 65535) { [void]$issues.Add('network target port is invalid') }
            if ($prefixes.Count -eq 0) { [void]$issues.Add('network target requires pathPrefixes') }
            foreach ($prefix in $prefixes) {
                $prefixValue = [string]$prefix
                if ([string]::IsNullOrWhiteSpace($prefixValue) -or -not $prefixValue.StartsWith('/') -or
                    $prefixValue -match '[*?#]' -or -not (Test-ScopePathValue -Path $prefixValue -RawPath $prefixValue)) {
                    [void]$issues.Add('network target path prefix is invalid')
                }
            }
        } elseif ($type -eq 'file') {
            $path = [string](Get-ScopeProperty -Scope $target -Name 'path')
            if ([string]::IsNullOrWhiteSpace($path) -or $path -match '[*?]') { [void]$issues.Add('file target path must be explicit and contain no wildcard') }
        } else {
            [void]$issues.Add('target type must be network or file')
        }
    }

    foreach ($action in $actions) {
        if ([string]::IsNullOrWhiteSpace([string]$action) -or [string]$action -notmatch '^[a-z][a-z0-9_.:-]+$') {
            [void]$issues.Add('allowedActions contains an invalid action')
        }
        if ([string]$action -match '[*?]') { [void]$issues.Add('allowedActions must not contain wildcards') }
    }

    $valid = $issues.Count -eq 0
    return [pscustomobject]@{ Valid = $valid; Issues = $issues.ToArray(); Scope = $Scope }
}

function Import-ScopeDocument {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [switch] $RequireGranted
    )

    $issues = New-ScopeIssueList
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        [void]$issues.Add("scope file not found: $Path")
        return [pscustomobject]@{ Valid = $false; Issues = $issues.ToArray(); Scope = $null; Path = $Path }
    }

    $scope = $null
    try {
        $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $scope = $json | ConvertFrom-Json
    } catch {
        [void]$issues.Add(('scope JSON is invalid: {0}' -f $_.Exception.Message))
        return [pscustomobject]@{ Valid = $false; Issues = $issues.ToArray(); Scope = $null; Path = $Path }
    }

    $result = Test-ScopeDocument -Scope $scope -RequireGranted:$RequireGranted
    return [pscustomobject]@{ Valid = $result.Valid; Issues = @($result.Issues); Scope = $result.Scope; Path = $Path }
}

function ConvertTo-ScopeTarget {
    param(
        [Parameter(Mandatory = $true)] [string] $Value
    )

    $text = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'scope target must not be empty' }

    $uri = $null
    if (-not [Uri]::TryCreate($text, [UriKind]::Absolute, [ref]$uri)) {
        return [pscustomobject]@{
            type = 'file'
            path = [IO.Path]::GetFullPath($text)
        }
    }
    if (@('http', 'https') -contains $uri.Scheme.ToLowerInvariant()) {
        $path = $uri.AbsolutePath
        if ([string]::IsNullOrWhiteSpace($path)) { $path = '/' }
        $rawPath = $uri.GetComponents([UriComponents]::Path, [UriFormat]::UriEscaped)
        if (-not (Test-ScopePathValue -Path $path -RawPath $rawPath)) { throw 'scope target path is unsafe' }
        return [pscustomobject]@{
            type = 'network'
            scheme = $uri.Scheme.ToLowerInvariant()
            host = $uri.DnsSafeHost.ToLowerInvariant()
            port = [int]$uri.Port
            pathPrefixes = @($path)
        }
    }
    if ($uri.Scheme -eq 'file') {
        return [pscustomobject]@{
            type = 'file'
            path = [IO.Path]::GetFullPath($uri.LocalPath)
        }
    }
    throw ("unsupported scope target scheme: {0}" -f $uri.Scheme)
}

function Test-ScopeTargetMatch {
    param(
        [Parameter(Mandatory = $true)] $Scope,
        [Parameter(Mandatory = $true)] [string] $Target,
        [string] $Action = ''
    )

    $documentResult = if ($Scope.PSObject.Properties['Valid']) { $Scope } else { Test-ScopeDocument -Scope $Scope -RequireGranted }
    if (-not $documentResult.Valid) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($Action) -and @($documentResult.Scope.allowedActions) -notcontains $Action) { return $false }

    $candidate = $null
    try { $candidate = ConvertTo-ScopeTarget -Value $Target } catch { return $false }
    foreach ($allowed in @($documentResult.Scope.targets)) {
        if ([string]$allowed.type -ne [string]$candidate.type) { continue }
        if ($candidate.type -eq 'file') {
            try {
                $allowedPath = [IO.Path]::GetFullPath([string]$allowed.path)
                $candidatePath = [IO.Path]::GetFullPath([string]$candidate.path)
                if ([string]::Equals($allowedPath, $candidatePath, [StringComparison]::OrdinalIgnoreCase)) { return $true }
            } catch { continue }
            continue
        }
        if (-not [string]::Equals([string]$allowed.scheme, [string]$candidate.scheme, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not [string]::Equals([string]$allowed.host, [string]$candidate.host, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([int]$allowed.port -ne [int]$candidate.port) { continue }
        $candidatePath = [string]$candidate.pathPrefixes[0]
        foreach ($prefix in @($allowed.pathPrefixes)) {
            $normalizedPrefix = [string]$prefix
            if (-not $normalizedPrefix.StartsWith('/')) { continue }
            if ($normalizedPrefix.Length -gt 1) { $normalizedPrefix = $normalizedPrefix.TrimEnd('/') }
            # Path prefixes are case-sensitive so /Admin is not covered by a /admin scope entry.
            if ([string]::Equals($candidatePath, $normalizedPrefix, [StringComparison]::Ordinal) -or
                $candidatePath.StartsWith($normalizedPrefix + '/', [StringComparison]::Ordinal) -or
                $normalizedPrefix -eq '/') {
                return $true
            }
        }
    }
    return $false
}

function Test-ScopeActionAllowed {
    param(
        [Parameter(Mandatory = $true)] $Scope,
        [Parameter(Mandatory = $true)] [string] $Action
    )

    $result = Test-ScopeDocument -Scope $Scope -RequireGranted
    if (-not $result.Valid) { return $false }
    return @($result.Scope.allowedActions) -contains $Action
}

function Test-ScopeRedirectChain {
    param(
        [Parameter(Mandatory = $true)] $Scope,
        [Parameter(Mandatory = $true)] [string[]] $Targets,
        [string] $Action = ''
    )

    if ($Targets.Count -eq 0) { return $false }
    foreach ($target in $Targets) {
        if (-not (Test-ScopeTargetMatch -Scope $Scope -Target $target -Action $Action)) { return $false }
    }
    return $true
}
