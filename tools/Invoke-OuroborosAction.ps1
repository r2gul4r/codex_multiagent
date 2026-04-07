[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        'start_interview',
        'resume_interview',
        'inspect_latest_seed',
        'run_seed',
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
    [switch]$PrettyJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-BashSingleQuoted {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $separator = "'" + '"' + "'" + '"' + "'"
    $escaped = ($Value -split "'") -join $separator
    return "'" + $escaped + "'"
}

function New-ActionResult {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Summary,
        [hashtable]$Artifacts,
        [string[]]$NextActions,
        [string]$ErrorKind,
        [string]$Stdout,
        [string]$Stderr,
        [int]$ExitCode = 0
    )

    $result = [ordered]@{
        action       = $Action
        status       = $Status
        summary      = $Summary
        artifacts    = if ($Artifacts) { $Artifacts } else { @{} }
        next_actions = if ($NextActions) { @($NextActions) } else { @() }
        exit_code    = $ExitCode
    }

    if ($ErrorKind) {
        $result.error_kind = $ErrorKind
    }
    if (-not [string]::IsNullOrWhiteSpace($Stdout)) {
        $result.stdout = $Stdout
    }
    if (-not [string]::IsNullOrWhiteSpace($Stderr)) {
        $result.stderr = $Stderr
    }

    return $result
}

function Invoke-WslBash {
    param([Parameter(Mandatory = $true)][string]$Command)

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $commandLine = 'bash -lc ' + (ConvertTo-BashSingleQuoted -Value $Command)
        $process = Start-Process -FilePath 'wsl.exe' -ArgumentList $commandLine -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

        $stdout = Get-Content -LiteralPath $stdoutPath -Raw
        $stderr = Get-Content -LiteralPath $stderrPath -Raw
        if ($null -eq $stdout) {
            $stdout = ''
        }
        if ($null -eq $stderr) {
            $stderr = ''
        }

        return [ordered]@{
            ExitCode = $process.ExitCode
            Stdout   = $stdout
            Stderr   = $stderr
            Command  = $Command
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Required {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name is required for action '$Action'"
    }
}

function Convert-JsonTextToHashtable {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $value = $Text | ConvertFrom-Json
    return ConvertTo-Hashtable -Value $value
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
        return $table
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-Hashtable -Value $item)
        }
        return $items
    }

    if ($Value -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-Hashtable -Value $property.Value
        }
        return $table
    }

    return $Value
}

function Resolve-WslUserPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    $command = 'INPUT_PATH=' + (ConvertTo-BashSingleQuoted -Value $PathValue) + " python3 - <<'PY'
import os
print(os.path.expanduser(os.environ['INPUT_PATH']))
PY"
    $probe = Invoke-WslBash -Command $command
    if ($probe.ExitCode -ne 0) {
        throw "Failed to resolve WSL path: $PathValue"
    }

    return $probe.Stdout.Trim()
}

function Get-WslPathFromWindowsPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath)

    $probe = Invoke-WslBash -Command ('wslpath -a ' + (ConvertTo-BashSingleQuoted -Value $WindowsPath))
    if ($probe.ExitCode -ne 0) {
        throw "Failed to convert Windows path to WSL path: $WindowsPath"
    }

    return $probe.Stdout.Trim()
}

function Get-ResolvedSeedPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    if ($PathValue.StartsWith('/')) {
        return $PathValue
    }

    if ([System.IO.Path]::IsPathRooted($PathValue) -or $PathValue -match '^[A-Za-z]:[\\/]|^\\\\') {
        return Get-WslPathFromWindowsPath -WindowsPath $PathValue
    }

    if ($PathValue.StartsWith('~/') -or $PathValue -eq '~') {
        return Resolve-WslUserPath -PathValue $PathValue
    }

    return $PathValue
}

function Get-TargetWorkspacePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    if ($PathValue.StartsWith('/')) {
        return $PathValue
    }

    if ([System.IO.Path]::IsPathRooted($PathValue) -or $PathValue -match '^[A-Za-z]:[\\/]|^\\\\') {
        return Get-WslPathFromWindowsPath -WindowsPath $PathValue
    }

    if ($PathValue.StartsWith('~/') -or $PathValue -eq '~') {
        return Resolve-WslUserPath -PathValue $PathValue
    }

    return $PathValue
}

function Get-DefaultNextActions {
    switch ($Action) {
        'start_interview'       { return @('inspect_latest_seed', 'resume_interview', 'run_seed') }
        'resume_interview'      { return @('inspect_latest_seed', 'run_seed', 'resume_interview') }
        'inspect_latest_seed'   { return @('run_seed', 'resume_interview') }
        'run_seed'              { return @('list_runtime_artifacts', 'check_runtime_health') }
        'list_runtime_artifacts' { return @('inspect_latest_seed', 'run_seed', 'check_runtime_health') }
        'check_runtime_health'  { return @('start_interview', 'resume_interview', 'run_seed') }
        default                 { return @() }
    }
}

function Get-LatestRuntimeArtifacts {
    param([Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot)

    $command = @"
python3 - <<'PY'
from pathlib import Path
import json

root = Path($(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot))
data_dir = root / "data"
seed_dir = root / "seeds"

def latest(directory, pattern):
    if not directory.exists():
        return None
    matches = sorted(directory.glob(pattern), key=lambda path: path.stat().st_mtime, reverse=True)
    return matches[0] if matches else None

interview = latest(data_dir, "interview_*.json")
seed = latest(seed_dir, "*.yaml")
print(json.dumps({
    "runtime_data_root": str(root),
    "latest_interview_path": str(interview) if interview else None,
    "latest_seed_path": str(seed) if seed else None,
}))
PY
"@

    $probe = Invoke-WslBash -Command $command
    if ($probe.ExitCode -ne 0) {
        return @{
            runtime_data_root = $ResolvedRuntimeDataRoot
        }
    }

    $payload = Convert-JsonTextToHashtable -Text $probe.Stdout
    if ($null -eq $payload) {
        return @{
            runtime_data_root = $ResolvedRuntimeDataRoot
        }
    }

    return $payload
}

function Get-ChangedFiles {
    param([Parameter(Mandatory = $true)][string]$ResolvedWorkspacePath)

    $command = @"
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedWorkspacePath)
if [ -d .git ]; then
  git status --short
fi
"@

    $probe = Invoke-WslBash -Command $command
    if ($probe.ExitCode -ne 0) {
        return @()
    }

    $files = @()
    foreach ($line in ($probe.Stdout -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed.Length -gt 3) {
            $files += $trimmed.Substring(3).Trim()
        }
        else {
            $files += $trimmed
        }
    }

    return $files
}

function Get-FailureKind {
    param(
        [Parameter(Mandatory = $true)][string]$ActionName,
        [int]$ExitCode,
        [string]$Stdout,
        [string]$Stderr
    )

    $combined = @($Stdout, $Stderr) -join "`n"
    if ($ExitCode -eq 124 -or $ExitCode -eq 130 -or $combined -match 'EOF when reading a line|KeyboardInterrupt|user interrupted|User interrupted|cancelled|timed out after') {
        return 'user_interrupted'
    }

    switch ($ActionName) {
        'start_interview' { return 'interview_generation_failure' }
        'resume_interview' { return 'runtime_exec_failure' }
        'run_seed' { return 'run_failure' }
        default { return 'runtime_exec_failure' }
    }
}

function Strip-AnsiText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $escape = [string]([char]27)
    $text = [regex]::Replace($Text, [regex]::Escape($escape) + '\[[0-9;?]*[ -/]*[@-~]', '')
    $text = [regex]::Replace($text, [regex]::Escape($escape) + '\].*?(\x07|$)', '')
    return $text
}

function Get-NormalizedLogText {
    param([string]$Text)

    $sanitized = Strip-AnsiText -Text $Text
    if ([string]::IsNullOrWhiteSpace($sanitized)) {
        return ''
    }

    return ($sanitized -replace "`r", "`n")
}

function Get-CodexTraceMetadata {
    param(
        [string]$Stdout,
        [string]$Stderr
    )

    $text = Get-NormalizedLogText -Text (@($Stdout, $Stderr) -join "`n")
    $trace = @{}

    if ($text -match '(?s)Interview Session:\s*(?<id>[A-Za-z0-9_.-]+)') {
        $trace.interview_session_id = $matches.id
    }
    elseif ($text -match '(?s)Resuming interview:\s*(?<id>[A-Za-z0-9_.-]+)') {
        $trace.interview_session_id = $matches.id
    }
    if ($text -match '(?s)State saved to:\s*(?<path>.+?)(?:\s|$)') {
        $trace.state_saved_to = $matches.path.Trim()
    }
    if ($text -match '(?m)\bsession_id\s*[:=]\s*(?<id>[A-Za-z0-9_.-]+)') {
        $trace.session_id = $matches.id
    }
    if ($text -match '(?m)\bexecution_id\s*[:=]\s*(?<id>[A-Za-z0-9_.-]+)') {
        $trace.execution_id = $matches.id
    }

    return $trace
}

function Get-ActionOutputArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$ActionName,
        [string]$Stdout,
        [string]$Stderr,
        [hashtable]$SnapshotBefore,
        [hashtable]$SnapshotAfter,
        [hashtable]$TraceMetadata,
        [string]$FallbackInterviewId,
        [string]$ResolvedRuntimeDataRoot
    )

    $text = Get-NormalizedLogText -Text (@($Stdout, $Stderr) -join "`n")
    $artifacts = @{}
    $runtimeDataRoot = if ($SnapshotAfter -and $SnapshotAfter.runtime_data_root) { [string]$SnapshotAfter.runtime_data_root } elseif ($ResolvedRuntimeDataRoot) { $ResolvedRuntimeDataRoot } else { $null }

    if ($SnapshotBefore) {
        $artifacts.runtime_snapshot_before = $SnapshotBefore
    }
    if ($SnapshotAfter) {
        $artifacts.runtime_snapshot_after = $SnapshotAfter
    }
    if ($TraceMetadata) {
        $artifacts.runtime_trace = $TraceMetadata
    }

    $paths = [regex]::Matches($text, '(?<!\w)(?:/[^\\\s''"`]+)+\.(?:yaml|yml|json)')
    $uniquePaths = @()
    foreach ($match in $paths) {
        $candidate = $match.Value
        if ($uniquePaths -notcontains $candidate) {
            $uniquePaths += $candidate
        }
    }

    switch ($ActionName) {
        'start_interview' {
            if ($TraceMetadata -and $TraceMetadata.ContainsKey('interview_session_id') -and $TraceMetadata.interview_session_id) {
                $artifacts.interview_id = $TraceMetadata.interview_session_id
            }
            elseif ($text -match '(?m)interview_(?<id>[A-Za-z0-9_.-]+)\.json') {
                $artifacts.interview_id = $matches.id
            }

            if ($artifacts.ContainsKey('interview_id') -and $artifacts.interview_id -and $runtimeDataRoot) {
                $artifacts.interview_path = "{0}/data/interview_{1}.json" -f $runtimeDataRoot, $artifacts.interview_id
            }

            if ($TraceMetadata -and $TraceMetadata.ContainsKey('state_saved_to') -and $TraceMetadata.state_saved_to) {
                if ($TraceMetadata.state_saved_to -match '/data/interview_[A-Za-z0-9_.-]+\.json$') {
                    $artifacts.interview_path = $TraceMetadata.state_saved_to
                    if (-not $artifacts.ContainsKey('interview_id') -or -not $artifacts.interview_id) {
                        $basename = [System.IO.Path]::GetFileNameWithoutExtension($TraceMetadata.state_saved_to)
                        if ($basename -match '^interview_(?<id>[A-Za-z0-9_.-]+)$') {
                            $artifacts.interview_id = $matches.id
                        }
                    }
                }
                elseif ($TraceMetadata.state_saved_to -match '/seeds/.*\.(yaml|yml)$') {
                    $artifacts.seed_path = $TraceMetadata.state_saved_to
                }
            }

            if (-not $artifacts.ContainsKey('seed_path') -or -not $artifacts.seed_path) {
                if ($uniquePaths.Count -gt 0) {
                    $seedCandidates = @($uniquePaths | Where-Object { $_ -match '/seeds/.*\.(yaml|yml)$' })
                    if ($seedCandidates.Count -gt 0) {
                        $artifacts.seed_path = $seedCandidates[-1]
                    }
                }
            }
        }
        'resume_interview' {
            if ($TraceMetadata -and $TraceMetadata.ContainsKey('interview_session_id') -and $TraceMetadata.interview_session_id) {
                $artifacts.interview_id = $TraceMetadata.interview_session_id
            }
            elseif ($text -match '(?m)interview_(?<id>[A-Za-z0-9_.-]+)\.json') {
                $artifacts.interview_id = $matches.id
            }
            elseif ($FallbackInterviewId) {
                $artifacts.interview_id = $FallbackInterviewId
            }

            if ($artifacts.ContainsKey('interview_id') -and $artifacts.interview_id -and $runtimeDataRoot) {
                $artifacts.interview_path = "{0}/data/interview_{1}.json" -f $runtimeDataRoot, $artifacts.interview_id
            }

            if ($TraceMetadata -and $TraceMetadata.ContainsKey('state_saved_to') -and $TraceMetadata.state_saved_to) {
                if ($TraceMetadata.state_saved_to -match '/data/interview_[A-Za-z0-9_.-]+\.json$') {
                    $artifacts.interview_path = $TraceMetadata.state_saved_to
                }
                elseif ($TraceMetadata.state_saved_to -match '/seeds/.*\.(yaml|yml)$') {
                    $artifacts.seed_path = $TraceMetadata.state_saved_to
                }
            }

            if (-not $artifacts.ContainsKey('seed_path') -or -not $artifacts.seed_path) {
                if ($uniquePaths.Count -gt 0) {
                    $seedCandidates = @($uniquePaths | Where-Object { $_ -match '/seeds/.*\.(yaml|yml)$' })
                    if ($seedCandidates.Count -gt 0) {
                        $artifacts.seed_path = $seedCandidates[-1]
                    }
                }
            }
        }
        'run_seed' {
            if ($TraceMetadata -and $TraceMetadata.ContainsKey('session_id') -and $TraceMetadata.session_id) {
                $artifacts.session_id = $TraceMetadata.session_id
            }
            elseif ($text -match '(?m)^\s*Session ID:\s*(?<id>[A-Za-z0-9_.-]+)\s*$') {
                $artifacts.session_id = $matches.id
            }
            if ($TraceMetadata -and $TraceMetadata.ContainsKey('execution_id') -and $TraceMetadata.execution_id) {
                $artifacts.execution_id = $TraceMetadata.execution_id
            }
            elseif ($text -match '(?m)^\s*Execution ID:\s*(?<id>[A-Za-z0-9_.-]+)\s*$') {
                $artifacts.execution_id = $matches.id
            }
            if ($uniquePaths.Count -gt 0) {
                $seedCandidates = @($uniquePaths | Where-Object { $_ -match '/seeds/.*\.(yaml|yml)$' })
                if ($seedCandidates.Count -gt 0) {
                    $artifacts.seed_path = $seedCandidates[-1]
                }
            }
        }
    }

    return $artifacts
}

function Get-BashPrelude {
    return @"
export HOME=`${HOME:-/home/`$(whoami)}
if [ -f "`$HOME/.local/bin/env" ]; then
  . "`$HOME/.local/bin/env" >/dev/null 2>&1
fi
export NVM_DIR="`$HOME/.nvm"
if [ -s "`$NVM_DIR/nvm.sh" ]; then
  . "`$NVM_DIR/nvm.sh" >/dev/null 2>&1
  nvm use --silent default >/dev/null 2>&1 || true
fi
"@
}

function Get-ShellCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeRoot,
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot
    )

    $prelude = Get-BashPrelude

    switch ($Action) {
        'start_interview' {
            Assert-Required -Value $Goal -Name 'Goal'
            return @"
$prelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
timeout -k 5s 90s uv run ouroboros init start --llm-backend codex --runtime codex $(ConvertTo-BashSingleQuoted -Value $Goal)
"@
        }
        'resume_interview' {
            Assert-Required -Value $InterviewId -Name 'InterviewId'
            return @"
$prelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
timeout -k 5s 90s uv run ouroboros init start --resume $(ConvertTo-BashSingleQuoted -Value $InterviewId) --llm-backend codex --runtime codex
"@
        }
        'inspect_latest_seed' {
            return @"
$prelude
python3 - <<'PY'
from pathlib import Path
import json
import sys

seed_dir = Path($(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot)) / "seeds"
if not seed_dir.exists():
    print(json.dumps({"error_kind": "missing_seed"}))
    raise SystemExit(7)

seeds = sorted(seed_dir.glob("*.yaml"), key=lambda path: path.stat().st_mtime, reverse=True)
if not seeds:
    print(json.dumps({"error_kind": "missing_seed"}))
    raise SystemExit(7)

latest = seeds[0]
print(json.dumps({
    "seed_path": str(latest),
    "seed_contents": latest.read_text(encoding="utf-8")
}))
PY
"@
        }
        'run_seed' {
            Assert-Required -Value $SeedPath -Name 'SeedPath'
            $resolvedSeedPath = Get-ResolvedSeedPath -PathValue $SeedPath
            return @"
$prelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
timeout -k 5s 90s uv run ouroboros run workflow $(ConvertTo-BashSingleQuoted -Value $resolvedSeedPath) --runtime codex
"@
        }
        'list_runtime_artifacts' {
            return @"
$prelude
python3 - <<'PY'
from pathlib import Path
import json

root = Path($(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot))
data_dir = root / "data"
seed_dir = root / "seeds"

payload = {
    "data_root": str(root),
    "interviews": sorted([path.name for path in data_dir.glob("interview_*.json")], reverse=True) if data_dir.exists() else [],
    "seeds": sorted([path.name for path in seed_dir.glob("*.yaml")], reverse=True) if seed_dir.exists() else [],
}

print(json.dumps(payload))
PY
"@
        }
        'check_runtime_health' {
            return @"
$prelude
status_output=`$(codex login status 2>&1)
status_code=`$?
python3 - <<'PY' "`$status_code" "`$status_output"
import json
import sys

print(json.dumps({
    "login_status": "logged_in" if sys.argv[1] == "0" else "not_logged_in",
    "summary": sys.argv[2],
}))
PY
exit "`$status_code"
"@
        }
        default {
            throw "Unsupported action '$Action'"
        }
    }
}

try {
    $resolvedRuntimeRoot = Resolve-WslUserPath -PathValue $RuntimeRoot
    $resolvedRuntimeDataRoot = Resolve-WslUserPath -PathValue $RuntimeDataRoot
    $snapshotBefore = Get-LatestRuntimeArtifacts -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
    $shellCommand = Get-ShellCommand -ResolvedRuntimeRoot $resolvedRuntimeRoot -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
    $invocation = Invoke-WslBash -Command $shellCommand
    $snapshotAfter = Get-LatestRuntimeArtifacts -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot

    $stdout = if ($null -eq $invocation.Stdout) { '' } else { $invocation.Stdout.TrimEnd() }
    $stderr = if ($null -eq $invocation.Stderr) { '' } else { $invocation.Stderr.TrimEnd() }
    $exitCode = [int]$invocation.ExitCode
    $nextActions = Get-DefaultNextActions
    $traceMetadata = Get-CodexTraceMetadata -Stdout $stdout -Stderr $stderr
    $outputArtifacts = Get-ActionOutputArtifacts -ActionName $Action -Stdout $stdout -Stderr $stderr -SnapshotBefore $snapshotBefore -SnapshotAfter $snapshotAfter -TraceMetadata $traceMetadata -FallbackInterviewId $InterviewId -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
    $result = $null

    switch ($Action) {
        'inspect_latest_seed' {
            $payload = Convert-JsonTextToHashtable -Text $stdout
            if ($exitCode -ne 0) {
                $errorKind = if ($payload -and $payload.ContainsKey('error_kind')) { [string]$payload.error_kind } else { 'filesystem_failure' }
                $result = New-ActionResult -Status 'error' -Summary 'Failed to inspect latest seed.' `
                    -Artifacts $outputArtifacts -NextActions $nextActions `
                    -ErrorKind $errorKind -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $result = New-ActionResult -Status 'ok' -Summary 'Latest seed loaded.' `
                -Artifacts (@{ latest_seed = $payload } + $outputArtifacts) `
                -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
            break
        }
        'list_runtime_artifacts' {
            if ($exitCode -ne 0) {
                $result = New-ActionResult -Status 'error' -Summary 'Failed to list runtime artifacts.' `
                    -Artifacts ($outputArtifacts + @{ runtime_trace = $traceMetadata }) `
                    -NextActions $nextActions -ErrorKind 'filesystem_failure' -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $payload = Convert-JsonTextToHashtable -Text $stdout
            $payload.interviews = @($payload.interviews)
            $payload.seeds = @($payload.seeds)
            $result = New-ActionResult -Status 'ok' -Summary 'Runtime artifacts listed.' `
                -Artifacts (@{ runtime_listing = $payload } + $outputArtifacts) `
                -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
            break
        }
        'check_runtime_health' {
            $payload = Convert-JsonTextToHashtable -Text $stdout
            if ($exitCode -ne 0) {
                $summary = if ($payload -and $payload.ContainsKey('summary')) { [string]$payload.summary } else { 'Runtime health check failed.' }
                $loginStatus = if ($payload -and $payload.ContainsKey('login_status')) { [string]$payload.login_status } else { 'unknown' }
                $errorKind = if ($loginStatus -eq 'not_logged_in') { 'not_logged_in' } else { 'codex_exec_failure' }
                $result = New-ActionResult -Status 'error' -Summary $summary `
                    -Artifacts (@{ login_status = $loginStatus } + $outputArtifacts) -NextActions @('check_runtime_health') `
                    -ErrorKind $errorKind -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $result = New-ActionResult -Status 'ok' -Summary 'Runtime health check passed.' `
                -Artifacts (@{ login_status = $payload.login_status; summary = $payload.summary } + $outputArtifacts) `
                -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
            break
        }
        default {
            if ($exitCode -ne 0) {
                $errorKind = Get-FailureKind -ActionName $Action -ExitCode $exitCode -Stdout $stdout -Stderr $stderr
                if ($Action -eq 'resume_interview' -and $InterviewId) {
                    if (-not $outputArtifacts.ContainsKey('interview_id') -or [string]::IsNullOrWhiteSpace([string]$outputArtifacts.interview_id)) {
                        $outputArtifacts.interview_id = $InterviewId
                    }
                    if (-not $outputArtifacts.ContainsKey('interview_path') -or [string]::IsNullOrWhiteSpace([string]$outputArtifacts.interview_path)) {
                        $outputArtifacts.interview_path = "{0}/data/interview_{1}.json" -f $resolvedRuntimeDataRoot, $InterviewId
                    }
                }
                $result = New-ActionResult -Status 'error' -Summary "Action '$Action' failed." `
                    -Artifacts $outputArtifacts `
                    -NextActions $nextActions -ErrorKind $errorKind -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $artifacts = [ordered]@{
                runtime_root      = $resolvedRuntimeRoot
                runtime_data_root = $resolvedRuntimeDataRoot
                runtime_trace = $traceMetadata
            }

            foreach ($key in $outputArtifacts.Keys) {
                if ($key -ne 'runtime_data_root') {
                    $artifacts[$key] = $outputArtifacts[$key]
                }
            }

            if ($Action -eq 'resume_interview') {
                $artifacts.interview_id = $InterviewId
            }
            elseif ($Action -eq 'run_seed') {
                $artifacts.seed_path = Get-ResolvedSeedPath -PathValue $SeedPath
                if ($TargetWorkspace) {
                    $resolvedWorkspace = Get-TargetWorkspacePath -PathValue $TargetWorkspace
                    $artifacts.target_workspace = $resolvedWorkspace
                    $artifacts.changed_files = @(Get-ChangedFiles -ResolvedWorkspacePath $resolvedWorkspace)
                }
            }

            $result = New-ActionResult -Status 'ok' -Summary "Action '$Action' completed." `
                -Artifacts $artifacts -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
        }
    }

    if ($PrettyJson) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        $result | ConvertTo-Json -Depth 8 -Compress
    }
}
catch {
    $failure = New-ActionResult -Status 'error' -Summary $_.Exception.Message `
        -ErrorKind 'shell_failure' -ExitCode 1
    if ($PrettyJson) {
        $failure | ConvertTo-Json -Depth 8
    }
    else {
        $failure | ConvertTo-Json -Depth 8 -Compress
    }
    exit 1
}
