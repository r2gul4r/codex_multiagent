[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Request,

    [string]$Goal,
    [string]$InterviewResponse,
    [string]$InterviewId,
    [string]$SeedPath,
    [string]$TargetWorkspace,
    [string]$RuntimeRoot = '~/ouroboros',
    [string]$RuntimeDataRoot = '~/.ouroboros',
    [string]$StatePath,
    [string]$HelperScriptPath,
    [switch]$SkipProjectionSync,
    [switch]$ResolveOnly,
    [switch]$PrettyJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Normalize-RequestText {
    param([Parameter(Mandatory = $true)][string]$Text)

    return ($Text.Trim().ToLowerInvariant())
}

function Test-AnyPattern {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-EffectiveStatePath {
    if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
        return $StatePath
    }

    return Join-Path (Split-Path $PSScriptRoot -Parent) 'STATE.md'
}

function Read-StateRuntimeProjection {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{
            state_path = $Path
            interview_id = $null
            latest_seed_path = $null
            latest_interview_path = $null
        }
    }

    $text = Get-Content -LiteralPath $Path -Raw
    $projection = [ordered]@{
        state_path = $Path
        interview_id = $null
        latest_seed_path = $null
        latest_interview_path = $null
    }

    if ($text -match '(?m)^- interview_id:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$') {
        $projection.interview_id = $matches.value.Trim()
    }
    if ($text -match '(?m)^- latest_seed_path:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$') {
        $projection.latest_seed_path = $matches.value.Trim()
    }
    if ($text -match '(?m)^- latest_interview_path:[ \t]*(?<value>[^\r\n]+?)[ \t]*\r?$') {
        $projection.latest_interview_path = $matches.value.Trim()
    }

    return $projection
}

function Resolve-RequestAction {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$ExplicitGoal,
        [string]$ExplicitInterviewResponse,
        [string]$ExplicitInterviewId,
        [string]$ExplicitSeedPath
    )

    $normalized = Normalize-RequestText -Text $Text
    $projection = Read-StateRuntimeProjection -Path (Get-EffectiveStatePath)
    $effectiveInterviewId = if (-not [string]::IsNullOrWhiteSpace($ExplicitInterviewId)) { $ExplicitInterviewId } else { $projection.interview_id }
    $effectiveSeedPath = if (-not [string]::IsNullOrWhiteSpace($ExplicitSeedPath)) { $ExplicitSeedPath } else { $projection.latest_seed_path }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitSeedPath)) {
        return [ordered]@{
            action = 'run_seed'
            reason = 'SeedPath was provided explicitly.'
            goal = $ExplicitGoal
            interview_response = $ExplicitInterviewResponse
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitInterviewId)) {
        return [ordered]@{
            action = 'resume_interview'
            reason = 'InterviewId was provided explicitly.'
            goal = $ExplicitGoal
            interview_response = $ExplicitInterviewResponse
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitInterviewResponse) -and -not [string]::IsNullOrWhiteSpace($effectiveInterviewId)) {
        return [ordered]@{
            action = 'resume_interview'
            reason = 'InterviewResponse was provided and STATE.md or explicit input provides an interview_id.'
            goal = $ExplicitGoal
            interview_response = $ExplicitInterviewResponse
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    return [ordered]@{
        action = 'start_interview'
        reason = 'Natural-language-first default: user request text no longer maps to operational actions and is passed through as the initial Ouroboros interview context unless explicit structured inputs require a transport action.'
        goal = if ([string]::IsNullOrWhiteSpace($ExplicitGoal)) { $Text } else { $ExplicitGoal }
        interview_response = $ExplicitInterviewResponse
        interview_id = $effectiveInterviewId
        seed_path = $effectiveSeedPath
    }
}

try {
    $resolution = Resolve-RequestAction -Text $Request -ExplicitGoal $Goal -ExplicitInterviewResponse $InterviewResponse -ExplicitInterviewId $InterviewId -ExplicitSeedPath $SeedPath

    $result = [ordered]@{
        request = $Request
        resolved_action = $resolution.action
        resolution_reason = $resolution.reason
        normalized_inputs = [ordered]@{
            goal = $resolution.goal
            interview_response = $resolution.interview_response
            interview_id = $resolution.interview_id
            seed_path = $resolution.seed_path
            target_workspace = $TargetWorkspace
        }
    }

    if ($ResolveOnly.IsPresent) {
        $result.status = 'resolved'
        $result.summary = 'Natural-language request was resolved to an Ouroboros control action.'
        $result.control_loop = $null
    }
    else {
        $controlLoopScript = Join-Path $PSScriptRoot 'Invoke-OuroborosControlLoop.ps1'
        $controlArgs = @{
            Action = $resolution.action
            Goal = $resolution.goal
            InterviewResponse = $resolution.interview_response
            InterviewId = $resolution.interview_id
            SeedPath = $resolution.seed_path
            TargetWorkspace = $TargetWorkspace
            RuntimeRoot = $RuntimeRoot
            RuntimeDataRoot = $RuntimeDataRoot
            StatePath = $StatePath
            HelperScriptPath = $HelperScriptPath
            SkipProjectionSync = $SkipProjectionSync
            PrettyJson = $true
        }

        $controlOutput = & $controlLoopScript @controlArgs 2>&1
        $controlJson = (($controlOutput | ForEach-Object { [string]$_ }) -join "`n") | ConvertFrom-Json

        $result.status = [string]$controlJson.status
        $result.summary = [string]$controlJson.summary
        $result.control_loop = $controlJson
    }

    if ($PrettyJson) {
        $result | ConvertTo-Json -Depth 32
    }
    else {
        $result | ConvertTo-Json -Depth 32 -Compress
    }
}
catch {
    $failure = [ordered]@{
        request = $Request
        status = 'error'
        summary = $_.Exception.Message
    }

    if ($PrettyJson) {
        $failure | ConvertTo-Json -Depth 32
    }
    else {
        $failure | ConvertTo-Json -Depth 32 -Compress
    }

    exit 1
}
