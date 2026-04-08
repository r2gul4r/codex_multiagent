[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Request,

    [string]$Goal,
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
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExplicitInterviewId)) {
        return [ordered]@{
            action = 'resume_interview'
            reason = 'InterviewId was provided explicitly.'
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'runtime',
            'health',
            'login status',
            'runtime status',
            '런타임',
            '상태 봐',
            '상태 확인',
            '로그인 상태'
        )) {
        return [ordered]@{
            action = 'check_runtime_health'
            reason = 'The request asks for runtime or login status.'
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'latest seed',
            'inspect seed',
            'show seed',
            'seed 보여',
            'seed 확인',
            '시드 보여',
            '시드 확인'
        )) {
        return [ordered]@{
            action = 'inspect_latest_seed'
            reason = 'The request asks to inspect the latest seed.'
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'evaluate',
            'assessment',
            '평가',
            '검토',
            '판단'
        )) {
        return [ordered]@{
            action = 'evaluate_result'
            reason = 'The request asks for evaluation or assessment of the latest result.'
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'inspect output',
            'inspect run',
            'show output',
            'show logs',
            '결과 봐',
            '출력 봐',
            '로그 봐',
            '결과 확인'
        )) {
        return [ordered]@{
            action = 'inspect_run_outputs'
            reason = 'The request asks to inspect the latest run outputs.'
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'resume interview',
            'resume',
            'continue interview',
            '인터뷰 이어',
            '인터뷰 계속',
            '이어서 인터뷰'
        )) {
        $reason = if (-not [string]::IsNullOrWhiteSpace($ExplicitInterviewId)) {
            'InterviewId was provided explicitly.'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($effectiveInterviewId)) {
            'The request asks to continue an existing interview and STATE.md provides the latest interview_id.'
        }
        else {
            'The request asks to continue an existing interview.'
        }

        return [ordered]@{
            action = 'resume_interview'
            reason = $reason
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'run seed',
            'execute seed',
            'seed 실행',
            '시드 실행',
            'seed 돌려',
            '시드 돌려'
        )) {
        $reason = if (-not [string]::IsNullOrWhiteSpace($ExplicitSeedPath)) {
            'SeedPath was provided explicitly.'
        }
        elseif (-not [string]::IsNullOrWhiteSpace($effectiveSeedPath)) {
            'The request asks to execute a seed and STATE.md provides the latest_seed_path.'
        }
        else {
            'The request explicitly asks to execute a seed.'
        }

        return [ordered]@{
            action = 'run_seed'
            reason = $reason
            goal = $ExplicitGoal
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    if (Test-AnyPattern -Text $normalized -Patterns @(
            'start interview',
            'new interview',
            'clarify',
            'interview',
            '인터뷰 시작',
            '인터뷰 해',
            '인터뷰 진행',
            '정리해줘',
            '명세 잡아'
        )) {
        return [ordered]@{
            action = 'start_interview'
            reason = 'The request asks to start or use an interview-style clarification flow.'
            goal = if ([string]::IsNullOrWhiteSpace($ExplicitGoal)) { $Text } else { $ExplicitGoal }
            interview_id = $effectiveInterviewId
            seed_path = $effectiveSeedPath
        }
    }

    return [ordered]@{
        action = 'start_interview'
        reason = 'Fallback default: treat the natural-language request as a rough goal and start an interview.'
        goal = if ([string]::IsNullOrWhiteSpace($ExplicitGoal)) { $Text } else { $ExplicitGoal }
        interview_id = $effectiveInterviewId
        seed_path = $effectiveSeedPath
    }
}

try {
    $resolution = Resolve-RequestAction -Text $Request -ExplicitGoal $Goal -ExplicitInterviewId $InterviewId -ExplicitSeedPath $SeedPath

    $result = [ordered]@{
        request = $Request
        resolved_action = $resolution.action
        resolution_reason = $resolution.reason
        normalized_inputs = [ordered]@{
            goal = $resolution.goal
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
