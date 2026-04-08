[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'start_interview',
        'resume_interview',
        'inspect_latest_seed',
        'run_seed',
        'inspect_run_outputs',
        'evaluate_result',
        'list_runtime_artifacts',
        'check_runtime_health'
    )]
    [string]$Action,

    [string]$Goal,
    [string]$InterviewId,
    [string]$SeedPath,
    [string]$TargetWorkspace,
    [string]$RuntimeRoot = '~/ouroboros',
    [string]$RuntimeDataRoot = '~/.ouroboros',
    [string]$StatePath,
    [switch]$SkipProjectionSync,
    [switch]$PrettyJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Script {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Arguments
    )

    $splat = @{}
    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]
        if ($null -eq $value) {
            continue
        }

        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $splat[$key] = $true
            }
            continue
        }

        if ($value -is [bool]) {
            $splat[$key] = $value
            continue
        }

        $splat[$key] = $value
    }

    return & $ScriptPath @splat 2>&1
}

function Convert-OutputToJsonText {
    param([Parameter(ValueFromPipeline = $true)]$Output)

    if ($null -eq $Output) {
        return ''
    }

    if ($Output -is [string]) {
        return $Output
    }

    if ($Output -is [System.Collections.IEnumerable] -and -not ($Output -is [string])) {
        return (($Output | ForEach-Object { [string]$_ }) -join "`n")
    }

    return [string]$Output
}

function Read-JsonObject {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Expected JSON output from helper, but received empty output.'
    }

    return Normalize-ContractValue -Value ($Text | ConvertFrom-Json)
}

function New-HelperFailureResult {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Summary,
        [string]$RawOutput
    )

    $failure = [ordered]@{
        status  = 'error'
        summary = $Summary
        error   = [ordered]@{
            kind    = $Kind
            summary = $Summary
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RawOutput)) {
        $failure.raw_output = $RawOutput
        $failure.error.raw_output = $RawOutput
    }

    return $failure
}

function ConvertTo-Hashtable {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $Value.Keys) {
            $table[$key] = ConvertTo-Hashtable -Value $Value[$key]
        }
        return ,$table
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-Hashtable -Value $item)
        }
        return ,$items
    }

    if ($Value -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-Hashtable -Value $property.Value
        }
        return ,$table
    }

    return $Value
}

function Normalize-ContractValue {
    param(
        $Value,
        [string]$Key
    )

    $listKeys = @('changed_files', 'next_actions', 'interviews', 'seeds')

    if ($listKeys -contains $Key) {
        if ($null -eq $Value) {
            return ,([string[]]@())
        }

        if (($Value -is [hashtable] -or $Value -is [pscustomobject]) -and @($Value.PSObject.Properties).Count -eq 0) {
            return ,([string[]]@())
        }

        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            return ,([string[]]@($Value))
        }

        return ,([string[]]@($Value))
    }

    if ($Value -is [hashtable]) {
        $table = @{}
        foreach ($nestedKey in $Value.Keys) {
            $table[$nestedKey] = Normalize-ContractValue -Value $Value[$nestedKey] -Key $nestedKey
        }
        return ,$table
    }

    if ($Value -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = Normalize-ContractValue -Value $property.Value -Key $property.Name
        }
        return ,$table
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(Normalize-ContractValue -Value $item -Key $null)
        }
        return ,$items
    }

    return $Value
}

function Get-ContractPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Name)) {
            return $Value[$Name]
        }
        return $null
    }

    if ($Value -is [pscustomobject]) {
        $property = $Value.PSObject.Properties[$Name]
        if ($null -ne $property) {
            return $property.Value
        }
        return $null
    }

    return $null
}

function Invoke-HelperAction {
    $helperScript = Join-Path $PSScriptRoot 'Invoke-OuroborosAction.ps1'
    $helperArgs = @{
        Action          = $Action
        Goal            = $Goal
        InterviewId     = $InterviewId
        SeedPath        = $SeedPath
        TargetWorkspace = $TargetWorkspace
        RuntimeRoot     = $RuntimeRoot
        RuntimeDataRoot = $RuntimeDataRoot
        PrettyJson      = $true
    }

    try {
        $output = Invoke-Script -ScriptPath $helperScript -Arguments $helperArgs
    }
    catch {
        return [ordered]@{
            payload      = $null
            is_valid     = $false
            helper_result = (New-HelperFailureResult -Kind 'helper_execution_error' -Summary $_.Exception.Message)
        }
    }

    $jsonText = Convert-OutputToJsonText -Output $output
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return [ordered]@{
            payload      = $null
            is_valid     = $false
            helper_result = (New-HelperFailureResult -Kind 'empty_output' -Summary 'Expected JSON output from helper, but received empty output.')
        }
    }

    try {
        $payload = Read-JsonObject -Text $jsonText
        return [ordered]@{
            payload      = $payload
            is_valid     = $true
            helper_result = $payload
        }
    }
    catch {
        return [ordered]@{
            payload      = $null
            is_valid     = $false
            helper_result = (New-HelperFailureResult -Kind 'malformed_json' -Summary $_.Exception.Message -RawOutput $jsonText)
        }
    }
}

function Invoke-ProjectionSync {
    param(
        [Parameter(Mandatory = $true)]$HelperResult
    )

    if ($SkipProjectionSync.IsPresent) {
        return [ordered]@{
            status  = 'skipped'
            summary = 'Projection sync was skipped by request.'
        }
    }

    $syncScript = Join-Path $PSScriptRoot 'Sync-OuroborosProjection.ps1'
    $helperJson = $HelperResult | ConvertTo-Json -Depth 32 -Compress
    $syncArgs = @{
        Json       = $helperJson
        StatePath  = $StatePath
        PrettyJson = $true
    }

    $output = Invoke-Script -ScriptPath $syncScript -Arguments $syncArgs
    $jsonText = Convert-OutputToJsonText -Output $output
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return [ordered]@{
            status  = 'error'
            summary = 'Projection sync returned no output.'
        }
    }

    try {
        return (Read-JsonObject -Text $jsonText)
    }
    catch {
        return [ordered]@{
            status  = 'error'
            summary = $_.Exception.Message
            raw     = $jsonText
        }
    }
}

function Get-TopLevelStatus {
    param(
        [Parameter(Mandatory = $true)]$HelperResult,
        [Parameter(Mandatory = $true)]$ProjectionResult
    )

    $helperStatusValue = Get-ContractPropertyValue -Value $HelperResult -Name 'status'
    $projectionStatusValue = Get-ContractPropertyValue -Value $ProjectionResult -Name 'status'
    $helperStatus = if ($null -ne $helperStatusValue) { [string]$helperStatusValue } else { 'unknown' }
    $projectionStatus = if ($null -ne $projectionStatusValue) { [string]$projectionStatusValue } else { 'unknown' }

    if ($helperStatus -eq 'ok' -and ($SkipProjectionSync.IsPresent -or $projectionStatus -eq 'ok' -or $projectionStatus -eq 'skipped')) {
        return 'ok'
    }

    if ($helperStatus -eq 'error') {
        return 'error'
    }

    if ($projectionStatus -eq 'error') {
        if ($helperStatus -eq 'ok') {
            return 'partial'
        }

        return 'error'
    }

    return 'partial'
}

function Get-Summary {
    param(
        [Parameter(Mandatory = $true)]$HelperResult,
        [Parameter(Mandatory = $true)]$ProjectionResult
    )

    $helperSummaryValue = Get-ContractPropertyValue -Value $HelperResult -Name 'summary'
    $projectionSummaryValue = Get-ContractPropertyValue -Value $ProjectionResult -Name 'summary'
    $helperSummary = if ($null -ne $helperSummaryValue) { [string]$helperSummaryValue } else { 'helper completed' }
    $projectionSummary = if ($null -ne $projectionSummaryValue) { [string]$projectionSummaryValue } else { $null }
    $projectionStatusValue = Get-ContractPropertyValue -Value $ProjectionResult -Name 'status'
    $projectionStatus = if ($null -ne $projectionStatusValue) { [string]$projectionStatusValue } else { 'unknown' }

    if ($projectionStatus -eq 'error') {
        if ([string]::IsNullOrWhiteSpace($projectionSummary)) {
            return "$helperSummary Projection sync failed."
        }

        return "$helperSummary Projection sync failed: $projectionSummary"
    }

    if ($SkipProjectionSync.IsPresent) {
        return "$helperSummary Projection sync skipped."
    }

    if ($script:Action -in @('inspect_run_outputs', 'evaluate_result')) {
        return $helperSummary
    }

    if ([string]::IsNullOrWhiteSpace($projectionSummary)) {
        return $helperSummary
    }

    return "$helperSummary Projection: $projectionSummary"
}

try {
    $helperInvocation = Invoke-HelperAction
    $helperResult = ConvertTo-Hashtable -Value $helperInvocation.helper_result

    if ($helperInvocation.is_valid) {
        $projectionResult = Invoke-ProjectionSync -HelperResult $helperInvocation.payload
    }
    else {
        $projectionResult = [ordered]@{
            status  = 'skipped'
            summary = 'Projection sync was not attempted because the helper payload was invalid.'
        }
    }

    $topLevelStatus = Get-TopLevelStatus -HelperResult $helperResult -ProjectionResult $projectionResult
    $summary = Get-Summary -HelperResult $helperResult -ProjectionResult $projectionResult

    $combined = [ordered]@{
        action          = $Action
        status          = $topLevelStatus
        summary         = $summary
        helper_result   = $helperResult
        projection_sync = ConvertTo-Hashtable -Value $projectionResult
    }

    if ($PrettyJson) {
        $combined | ConvertTo-Json -Depth 32
    }
    else {
        $combined | ConvertTo-Json -Depth 32 -Compress
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $failure = [ordered]@{
        action          = $Action
        status          = 'error'
        summary         = $errorMessage
        helper_result   = [ordered]@{
            status  = 'error'
            summary = $errorMessage
            error   = [ordered]@{
                kind    = 'unexpected_error'
                summary = $errorMessage
            }
        }
        projection_sync = [ordered]@{
            status  = 'skipped'
            summary = 'Projection sync was not attempted because the helper flow failed before a valid JSON payload was available.'
        }
    }

    if ($PrettyJson) {
        $failure | ConvertTo-Json -Depth 32
    }
    else {
        $failure | ConvertTo-Json -Depth 32 -Compress
    }

    exit 1
}
