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
    [string]$InterviewResponse,
    [string]$InterviewId,
    [string]$SeedPath,
    [string]$TargetWorkspace,
    [string]$RuntimeRoot = '~/ouroboros',
    [string]$RuntimeDataRoot = '~/.ouroboros',
    [string]$TranscriptPath,
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

function Get-BashInputPipeCommand {
    param([string]$InputText)

    if ([string]::IsNullOrWhiteSpace($InputText)) {
        return ''
    }

    return 'INTERVIEW_RESPONSE=' + (ConvertTo-BashSingleQuoted -Value $InputText) + ' python3 -c "import os, sys; text = os.environ[' + "'" + 'INTERVIEW_RESPONSE' + "'" + ']; sys.stdout.write(text); sys.stdout.write(' + "'" + '\n' + "'" + ' if not text.endswith(' + "'" + '\n' + "'" + ') else ' + "'" + '' + "'" + ')" |'
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

function Normalize-ListContractForJson {
    param($Value)

    $listKeys = @('changed_files', 'next_actions', 'interviews', 'seeds')

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            $child = $Value[$key]

            if ($listKeys -contains [string]$key) {
                if ($null -eq $child) {
                    $Value[$key] = @()
                    continue
                }

                if (($child -is [System.Collections.IDictionary] -and @($child.Keys).Count -eq 0) -or
                    ($child -is [pscustomobject] -and @($child.PSObject.Properties).Count -eq 0)) {
                    $Value[$key] = @()
                    continue
                }

                if ($child -is [System.Collections.IEnumerable] -and -not ($child -is [string])) {
                    $Value[$key] = @($child)
                    continue
                }
            }

            Normalize-ListContractForJson -Value $child | Out-Null
        }

        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            Normalize-ListContractForJson -Value $item | Out-Null
        }
    }

    return $Value
}

function Convert-JsonTextToHashtable {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $value = $Text | ConvertFrom-Json
    return Normalize-ContractValue -Value (ConvertTo-Hashtable -Value $value)
}

function Resolve-WslUserPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $PathValue
    }

    if ($PathValue.StartsWith('/')) {
        return $PathValue
    }

    if ([System.IO.Path]::IsPathRooted($PathValue) -or $PathValue -match '^[A-Za-z]:[\\/]|^\\\\') {
        $probe = Invoke-WslBash -Command ('wslpath -a ' + (ConvertTo-BashSingleQuoted -Value $PathValue))
        if ($probe.ExitCode -ne 0) {
            throw "Failed to convert Windows path to WSL path: $PathValue"
        }

        return $probe.Stdout.Trim()
    }

    if ($PathValue.StartsWith('~/') -or $PathValue -eq '~') {
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

    return $PathValue
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

function Get-ResolvedTranscriptPath {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot,
        [string]$ProvidedTranscriptPath,
        [Parameter(Mandatory = $true)][string]$ActionName
    )

    if (-not [string]::IsNullOrWhiteSpace($ProvidedTranscriptPath)) {
        return $ProvidedTranscriptPath
    }

    $safeAction = ($ActionName -replace '[^A-Za-z0-9_.-]', '_')
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    $baseRoot = $ResolvedRuntimeDataRoot.TrimEnd('/')
    return "$baseRoot/transcripts/ouroboros-transcript-$safeAction-$stamp.log"
}

function Get-DefaultNextActions {
    switch ($Action) {
        'start_interview'       { return @('inspect_latest_seed', 'resume_interview', 'run_seed') }
        'resume_interview'      { return @('inspect_latest_seed', 'run_seed', 'resume_interview') }
        'inspect_latest_seed'   { return @('run_seed', 'resume_interview') }
        'run_seed'              { return @('inspect_run_outputs', 'evaluate_result', 'check_runtime_health') }
        'inspect_run_outputs'   { return @('evaluate_result', 'run_seed', 'check_runtime_health') }
        'evaluate_result'       { return @('run_seed', 'resume_interview', 'check_runtime_health') }
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
log_dir = root / "logs"
transcript_dir = root / "transcripts"

def latest(directory, pattern):
    if not directory.exists():
        return None
    matches = sorted(directory.glob(pattern), key=lambda path: path.stat().st_mtime, reverse=True)
    return matches[0] if matches else None

interview = latest(data_dir, "interview_*.json")
seed = latest(seed_dir, "*.yaml")
log = latest(log_dir, "ouroboros.log*")
print(json.dumps({
    "runtime_data_root": str(root),
    "latest_interview_path": str(interview) if interview else None,
    "latest_seed_path": str(seed) if seed else None,
    "latest_log_path": str(log) if log else None,
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

function Ensure-InterviewBootstrapState {
    param(
        [Parameter(Mandatory = $true)][string]$InterviewId,
        [Parameter(Mandatory = $true)][string]$InitialContext,
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot
    )

    if ([string]::IsNullOrWhiteSpace($InterviewId) -or [string]::IsNullOrWhiteSpace($InitialContext)) {
        return $null
    }

    $command = @"
INTERVIEW_ID=$(ConvertTo-BashSingleQuoted -Value $InterviewId) \
INITIAL_CONTEXT=$(ConvertTo-BashSingleQuoted -Value $InitialContext) \
RUNTIME_DATA_ROOT=$(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot) \
python3 - <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import os

interview_id = os.environ["INTERVIEW_ID"]
initial_context = os.environ["INITIAL_CONTEXT"]
root = Path(os.environ["RUNTIME_DATA_ROOT"])
path = root / "data" / f"interview_{interview_id}.json"
path.parent.mkdir(parents=True, exist_ok=True)

if path.exists():
    print(json.dumps({
        "created": False,
        "path": str(path),
    }))
    raise SystemExit(0)

timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
payload = {
    "interview_id": interview_id,
    "status": "in_progress",
    "rounds": [],
    "initial_context": initial_context,
    "created_at": timestamp,
    "updated_at": timestamp,
    "is_brownfield": False,
    "codebase_paths": [],
    "codebase_context": "",
    "explore_completed": False,
    "ambiguity_score": None,
    "ambiguity_breakdown": None,
}
path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "created": True,
    "path": str(path),
}))
PY
"@

    $probe = Invoke-WslBash -Command $command
    if ($probe.ExitCode -ne 0) {
        return $null
    }

    return Convert-JsonTextToHashtable -Text $probe.Stdout
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

        if ($trimmed -match '^(?:\?\?|..)\s+(?<path>.+)$') {
            $files += $matches.path.Trim()
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
        'inspect_run_outputs' { return 'filesystem_failure' }
        'evaluate_result' { return 'missing_evaluation_surface' }
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
        [string]$ResolvedRuntimeDataRoot,
        [string]$TranscriptPath
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
    if (-not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
        $artifacts.transcript_path = $TranscriptPath
        $artifacts.latest_transcript_path = $TranscriptPath
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

            if (-not $artifacts.ContainsKey('transcript_path') -and -not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
                $artifacts.transcript_path = $TranscriptPath
                $artifacts.latest_transcript_path = $TranscriptPath
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

function Get-BashTranscriptPrelude {
    param([string]$TranscriptPath)

    if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
        return ''
    }

    $quotedTranscriptPath = ConvertTo-BashSingleQuoted -Value $TranscriptPath
    return @"
TRANSCRIPT_PATH=$quotedTranscriptPath
TRANSCRIPT_DIR=`$(dirname "`$TRANSCRIPT_PATH")
mkdir -p "`$TRANSCRIPT_DIR"
: > "`$TRANSCRIPT_PATH"
exec > >(tee -a "`$TRANSCRIPT_PATH") 2> >(tee -a "`$TRANSCRIPT_PATH" >&2)
"@
}

function Get-RunObservationCommand {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('inspect_run_outputs', 'evaluate_result')][string]$Mode,
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot,
        [string]$ResolvedWorkspacePath,
        [string]$ResolvedSeedPath,
        [string]$TranscriptPath
    )

    $prelude = Get-BashPrelude
    $transcriptPrelude = Get-BashTranscriptPrelude -TranscriptPath $TranscriptPath
    $workspaceAssignment = ''
    if (-not [string]::IsNullOrWhiteSpace($ResolvedWorkspacePath)) {
        $workspaceAssignment = 'TARGET_WORKSPACE=' + (ConvertTo-BashSingleQuoted -Value $ResolvedWorkspacePath) + ' '
    }

    $seedAssignment = ''
    if (-not [string]::IsNullOrWhiteSpace($ResolvedSeedPath)) {
        $seedAssignment = 'TARGET_SEED=' + (ConvertTo-BashSingleQuoted -Value $ResolvedSeedPath) + ' '
    }

    return @"
$prelude
$transcriptPrelude
${workspaceAssignment}${seedAssignment}python3 - <<'PY'
from pathlib import Path
import json
import os
import re
import subprocess

mode = $(ConvertTo-BashSingleQuoted -Value $Mode)
root = Path($(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot))
workspace = os.environ.get("TARGET_WORKSPACE")
target_seed = os.environ.get("TARGET_SEED")

def latest(directory, pattern):
    if not directory.exists():
        return None
    matches = sorted(directory.glob(pattern), key=lambda path: path.stat().st_mtime, reverse=True)
    return matches[0] if matches else None

def read_tail(path, line_count=120):
    if not path or not path.exists():
        return ""
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except Exception:
        return ""
    return "\n".join(lines[-line_count:])

def read_text(path):
    if not path or not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""

def extract_value(text, pattern):
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    return match.group("value").strip() if match else None

def extract_seed_context(path):
    if not path or not path.exists():
        return {}
    text = read_text(path)
    context = {
        "seed_path": str(path),
        "seed_id": extract_value(text, r"(?m)^\s*seed_id:\s*(?P<value>[A-Za-z0-9_.-]+)\s*$"),
        "interview_id": extract_value(text, r"(?m)^\s*interview_id:\s*(?P<value>[A-Za-z0-9_.-]+)\s*$"),
        "created_at": extract_value(text, r"(?m)^\s*created_at:\s*'?(?P<value>[^'\n]+)'?\s*$"),
        "version": extract_value(text, r"(?m)^\s*version:\s*(?P<value>[A-Za-z0-9_.-]+)\s*$"),
    }
    return {key: value for key, value in context.items() if value is not None}

def extract_interview_context(path):
    if not path or not path.exists():
        return {}
    try:
        raw = json.loads(read_text(path))
    except Exception:
        raw = {}
    if not isinstance(raw, dict):
        raw = {}
    rounds = raw.get("rounds")
    if not isinstance(rounds, list):
        rounds = []
    context = {
        "interview_path": str(path),
        "interview_id": raw.get("interview_id") or path.stem.replace("interview_", "", 1),
        "status": raw.get("status"),
        "round_count": len(rounds),
        "created_at": raw.get("created_at"),
        "updated_at": raw.get("updated_at"),
    }
    return {key: value for key, value in context.items() if value is not None and value != ""}

def git_changed_files(path_value):
    if not path_value:
        return []
    path = Path(path_value)
    if not path.exists() or not (path / ".git").exists():
        return []
    try:
        completed = subprocess.run(
            ["git", "-C", str(path), "status", "--short"],
            capture_output=True,
            text=True,
            check=False,
        )
    except Exception:
        return []
    if completed.returncode != 0:
        return []
    files = []
    for line in completed.stdout.splitlines():
        trimmed = line.strip()
        if not trimmed:
            continue
        match = re.match(r'^(?:\?\?|..)\s+(?P<path>.+)$', trimmed)
        files.append(match.group('path').strip() if match else trimmed)
    return files

data_dir = root / "data"
seed_dir = root / "seeds"
log_dir = root / "logs"

latest_interview = latest(data_dir, "interview_*.json")
latest_seed = Path(target_seed) if target_seed else latest(seed_dir, "*.yaml")
latest_log = latest(log_dir, "ouroboros.log*")
latest_transcript = latest(transcript_dir, "ouroboros-transcript-*.log")
latest_observation = latest_transcript or latest_log
log_excerpt = read_tail(latest_observation)
changed_files = git_changed_files(workspace)
seed_context = extract_seed_context(latest_seed)
interview_context = extract_interview_context(latest_interview)

signals = {
    "has_error": bool(re.search(r"(?i)(\berror\b|traceback|exception|failed|failure|timed out|timeout|EOF when reading a line)", log_excerpt)),
    "has_success": bool(re.search(r"(?i)(\bcompleted\b|\bsuccess\b|\bpassed\b|\bok\b|generated seed|state saved)", log_excerpt)),
    "has_interrupt": bool(re.search(r"(?i)(keyboardinterrupt|user interrupted|cancelled)", log_excerpt)),
    "has_changes": bool(changed_files),
}

runtime_trace = {}
for key, pattern in {
    "session_id": r"(?m)\bsession_id\s*[:=]\s*(?P<value>[A-Za-z0-9_.-]+)",
    "execution_id": r"(?m)\bexecution_id\s*[:=]\s*(?P<value>[A-Za-z0-9_.-]+)",
    "interview_id": r"(?m)\binterview_(?P<value>[A-Za-z0-9_.-]+)\.json",
}.items():
    value = extract_value(read_text(latest_log), pattern)
    if value:
        runtime_trace[key] = value

if "interview_id" not in runtime_trace and interview_context.get("interview_id"):
    runtime_trace["interview_id"] = interview_context["interview_id"]
if "interview_id" not in runtime_trace and seed_context.get("interview_id"):
    runtime_trace["interview_id"] = seed_context["interview_id"]

runtime_context = {
    "seed": seed_context,
    "interview": interview_context,
    "trace": runtime_trace,
}

artifacts = {
    "runtime_data_root": str(root),
    "latest_interview_path": str(latest_interview) if latest_interview else None,
    "latest_seed_path": str(latest_seed) if latest_seed and latest_seed.exists() else None,
    "latest_log_path": str(latest_log) if latest_log else None,
    "latest_transcript_path": str(latest_transcript) if latest_transcript else None,
    "log_excerpt": log_excerpt,
    "changed_files": changed_files,
    "runtime_trace": runtime_trace,
    "runtime_context": runtime_context,
    "runtime_listing": {
        "interviews": sorted([path.name for path in data_dir.glob("interview_*.json")], reverse=True) if data_dir.exists() else [],
        "seeds": sorted([path.name for path in seed_dir.glob("*.yaml")], reverse=True) if seed_dir.exists() else [],
    },
    "latest_seed": seed_context,
    "latest_interview": interview_context,
}

if mode == "inspect_run_outputs":
    print(json.dumps({
        "status": "ok",
        "summary": "Run outputs inspected.",
        "artifacts": artifacts,
    }))
    raise SystemExit(0)

if not latest_interview and not latest_seed and not latest_log:
    print(json.dumps({
        "error_kind": "missing_evaluation_surface",
        "summary": "No runtime artifacts were available for evaluation.",
    }))
    raise SystemExit(7)

verdict = "unknown"
summary = "Evaluation verdict unavailable."
if signals["has_interrupt"]:
    verdict = "retry"
    summary = "Latest run looks interrupted or cancelled."
elif signals["has_error"] and not signals["has_success"]:
    verdict = "review" if signals["has_changes"] else "retry"
    summary = "Latest run shows failure signals without a clean success marker."
elif signals["has_success"] and not signals["has_error"]:
    verdict = "accept" if signals["has_changes"] or latest_seed else "review"
    summary = "Latest run shows success markers."
elif signals["has_changes"]:
    verdict = "review"
    summary = "Workspace changes were detected, but the runtime signal is ambiguous."

print(json.dumps({
    "status": "ok",
    "verdict": verdict,
    "summary": summary,
    "signals": signals,
    "artifacts": artifacts,
}))
PY
"@
}

function Get-ShellCommand {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeRoot,
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot,
        [string]$TranscriptPath
    )

    $prelude = Get-BashPrelude
    $transcriptPrelude = Get-BashTranscriptPrelude -TranscriptPath $TranscriptPath

    switch ($Action) {
        'start_interview' {
            Assert-Required -Value $Goal -Name 'Goal'
            return @"
$prelude
$transcriptPrelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
timeout -k 5s 90s uv run ouroboros init start --llm-backend codex --runtime codex $(ConvertTo-BashSingleQuoted -Value $Goal)
"@
        }
        'resume_interview' {
            Assert-Required -Value $InterviewId -Name 'InterviewId'
            $inputPipeCommand = Get-BashInputPipeCommand -InputText $InterviewResponse
            return @"
$prelude
$transcriptPrelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
$inputPipeCommand timeout -k 5s 90s uv run ouroboros init start --resume $(ConvertTo-BashSingleQuoted -Value $InterviewId) --llm-backend codex --runtime codex
"@
        }
        'inspect_latest_seed' {
            return @"
$prelude
$transcriptPrelude
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
$transcriptPrelude
cd $(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeRoot)
timeout -k 5s 90s uv run ouroboros run workflow $(ConvertTo-BashSingleQuoted -Value $resolvedSeedPath) --runtime codex
"@
        }
        'inspect_run_outputs' {
            $resolvedWorkspace = Get-TargetWorkspacePath -PathValue $TargetWorkspace
            return Get-RunObservationCommand -Mode 'inspect_run_outputs' -ResolvedRuntimeDataRoot $ResolvedRuntimeDataRoot -ResolvedWorkspacePath $resolvedWorkspace -TranscriptPath $TranscriptPath
        }
        'evaluate_result' {
            $resolvedWorkspace = Get-TargetWorkspacePath -PathValue $TargetWorkspace
            $resolvedSeedPath = $null
            if (-not [string]::IsNullOrWhiteSpace($SeedPath)) {
                $resolvedSeedPath = Get-ResolvedSeedPath -PathValue $SeedPath
            }
            return Get-RunObservationCommand -Mode 'evaluate_result' -ResolvedRuntimeDataRoot $ResolvedRuntimeDataRoot -ResolvedWorkspacePath $resolvedWorkspace -ResolvedSeedPath $resolvedSeedPath -TranscriptPath $TranscriptPath
        }
        'list_runtime_artifacts' {
            return @"
$prelude
$transcriptPrelude
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
$transcriptPrelude
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
    $resolvedTranscriptPath = Get-ResolvedTranscriptPath -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot -ProvidedTranscriptPath $TranscriptPath -ActionName $Action
    $snapshotBefore = Get-LatestRuntimeArtifacts -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
    $shellCommand = Get-ShellCommand -ResolvedRuntimeRoot $resolvedRuntimeRoot -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot -TranscriptPath $resolvedTranscriptPath
    $invocation = Invoke-WslBash -Command $shellCommand
    $snapshotAfter = Get-LatestRuntimeArtifacts -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot

    $stdout = if ($null -eq $invocation.Stdout) { '' } else { $invocation.Stdout.TrimEnd() }
    $stderr = if ($null -eq $invocation.Stderr) { '' } else { $invocation.Stderr.TrimEnd() }
    $exitCode = [int]$invocation.ExitCode
    $nextActions = Get-DefaultNextActions
    $traceMetadata = Get-CodexTraceMetadata -Stdout $stdout -Stderr $stderr
    $outputArtifacts = Get-ActionOutputArtifacts -ActionName $Action -Stdout $stdout -Stderr $stderr -SnapshotBefore $snapshotBefore -SnapshotAfter $snapshotAfter -TraceMetadata $traceMetadata -FallbackInterviewId $InterviewId -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot -TranscriptPath $resolvedTranscriptPath
    $result = $null

    if ($Action -eq 'start_interview' -and $exitCode -ne 0) {
        $errorKind = Get-FailureKind -ActionName $Action -ExitCode $exitCode -Stdout $stdout -Stderr $stderr
        $capturedInterviewId = if ($outputArtifacts.ContainsKey('interview_id')) { [string]$outputArtifacts.interview_id } else { '' }
        $capturedInterviewPath = if ($outputArtifacts.ContainsKey('interview_path')) { [string]$outputArtifacts.interview_path } else { '' }
        $capturedInterviewPathExists = $false
        if (-not [string]::IsNullOrWhiteSpace($capturedInterviewPath) -and $capturedInterviewPath.StartsWith('/')) {
            $pathProbe = Invoke-WslBash -Command ("test -f " + (ConvertTo-BashSingleQuoted -Value $capturedInterviewPath))
            $capturedInterviewPathExists = ($pathProbe.ExitCode -eq 0)
        }
        $bootstrapNeeded = (
            $errorKind -eq 'user_interrupted' -and
            -not [string]::IsNullOrWhiteSpace($capturedInterviewId) -and
            (
                [string]::IsNullOrWhiteSpace($capturedInterviewPath) -or
                -not $capturedInterviewPathExists
            )
        )

        if ($bootstrapNeeded) {
            $bootstrap = Ensure-InterviewBootstrapState -InterviewId $capturedInterviewId -InitialContext $Goal -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
            if ($bootstrap -and $bootstrap.ContainsKey('path') -and -not [string]::IsNullOrWhiteSpace([string]$bootstrap.path)) {
                $outputArtifacts.interview_path = [string]$bootstrap.path
                $outputArtifacts.bootstrap_state = $bootstrap
                $snapshotAfter = Get-LatestRuntimeArtifacts -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
                $outputArtifacts.runtime_snapshot_after = $snapshotAfter
            }
        }
    }

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
        'inspect_run_outputs' {
            $payload = Convert-JsonTextToHashtable -Text $stdout
            if ($exitCode -ne 0) {
                $errorKind = if ($payload -and $payload.ContainsKey('error_kind')) { [string]$payload.error_kind } else { 'filesystem_failure' }
                $summary = if ($payload -and $payload.ContainsKey('summary')) { [string]$payload.summary } else { 'Failed to inspect run outputs.' }
                $artifacts = [ordered]@{ run_outputs = $payload }
                foreach ($key in $outputArtifacts.Keys) {
                    if (-not $artifacts.Contains($key)) {
                        $artifacts[$key] = $outputArtifacts[$key]
                    }
                }
                $result = New-ActionResult -Status 'error' -Summary $summary `
                    -Artifacts $artifacts -NextActions $nextActions `
                    -ErrorKind $errorKind -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $artifacts = [ordered]@{
                runtime_root      = $resolvedRuntimeRoot
                runtime_data_root = $resolvedRuntimeDataRoot
                runtime_trace     = if ($payload -and $payload.ContainsKey('artifacts') -and $payload.artifacts -is [hashtable] -and $payload.artifacts.ContainsKey('runtime_trace')) { $payload.artifacts.runtime_trace } else { $traceMetadata }
                run_outputs       = $payload
            }

            if ($payload -and $payload.ContainsKey('artifacts') -and $payload.artifacts -is [hashtable]) {
                foreach ($key in @('runtime_data_root', 'latest_interview_path', 'latest_seed_path', 'latest_log_path', 'log_excerpt', 'changed_files', 'runtime_listing', 'runtime_context', 'latest_seed', 'latest_interview')) {
                    if ($payload.artifacts.ContainsKey($key)) {
                        $artifacts[$key] = if ($key -eq 'changed_files') { [string[]]@($payload.artifacts[$key]) } else { $payload.artifacts[$key] }
                    }
                }
            }

            foreach ($key in $outputArtifacts.Keys) {
                if (-not $artifacts.Contains($key) -and $key -ne 'runtime_trace') {
                    $artifacts[$key] = $outputArtifacts[$key]
                }
            }

            $result = New-ActionResult -Status 'ok' -Summary 'Run outputs inspected.' `
                -Artifacts $artifacts -NextActions @('evaluate_result', 'run_seed', 'check_runtime_health') `
                -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
            break
        }
        'evaluate_result' {
            $payload = Convert-JsonTextToHashtable -Text $stdout
            if ($exitCode -ne 0) {
                $errorKind = if ($payload -and $payload.ContainsKey('error_kind')) { [string]$payload.error_kind } else { 'missing_evaluation_surface' }
                $summary = if ($payload -and $payload.ContainsKey('summary')) { [string]$payload.summary } else { 'Failed to evaluate latest result.' }
                $artifacts = [ordered]@{ evaluation = $payload }
                foreach ($key in $outputArtifacts.Keys) {
                    if (-not $artifacts.Contains($key)) {
                        $artifacts[$key] = $outputArtifacts[$key]
                    }
                }
                $result = New-ActionResult -Status 'error' -Summary $summary `
                    -Artifacts $artifacts -NextActions $nextActions `
                    -ErrorKind $errorKind -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                break
            }

            $evaluation = $payload
            $verdict = if ($evaluation -and $evaluation.ContainsKey('verdict')) { [string]$evaluation.verdict } else { 'unknown' }
            $summary = if ($evaluation -and $evaluation.ContainsKey('summary')) { [string]$evaluation.summary } else { 'Evaluation completed.' }
            $artifacts = [ordered]@{
                runtime_root      = $resolvedRuntimeRoot
                runtime_data_root = $resolvedRuntimeDataRoot
                runtime_trace     = if ($evaluation -and $evaluation.ContainsKey('artifacts') -and $evaluation.artifacts -is [hashtable] -and $evaluation.artifacts.ContainsKey('runtime_trace')) { $evaluation.artifacts.runtime_trace } else { $traceMetadata }
                verdict           = $verdict
                signals           = if ($evaluation -and $evaluation.ContainsKey('signals')) { $evaluation.signals } else { @{} }
                evaluation        = $evaluation
            }

            if ($evaluation -and $evaluation.ContainsKey('artifacts') -and $evaluation.artifacts -is [hashtable]) {
                foreach ($key in @('runtime_data_root', 'latest_interview_path', 'latest_seed_path', 'latest_log_path', 'log_excerpt', 'changed_files', 'runtime_listing', 'runtime_context', 'latest_seed', 'latest_interview')) {
                    if ($evaluation.artifacts.ContainsKey($key)) {
                        $artifacts[$key] = if ($key -eq 'changed_files') { [string[]]@($evaluation.artifacts[$key]) } else { $evaluation.artifacts[$key] }
                    }
                }
            }

            foreach ($key in $outputArtifacts.Keys) {
                if (-not $artifacts.Contains($key) -and $key -ne 'runtime_trace') {
                    $artifacts[$key] = $outputArtifacts[$key]
                }
            }

            $result = New-ActionResult -Status 'ok' -Summary $summary `
                -Artifacts $artifacts `
                -NextActions @('run_seed', 'resume_interview', 'check_runtime_health') `
                -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
            $result.verdict = $verdict
            $result.signals = if ($evaluation -and $evaluation.ContainsKey('signals')) { $evaluation.signals } else { @{} }
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

                $capturedInterviewId = if ($outputArtifacts.ContainsKey('interview_id')) { [string]$outputArtifacts.interview_id } else { '' }
                $capturedSeedPath = if ($outputArtifacts.ContainsKey('seed_path')) { [string]$outputArtifacts.seed_path } else { '' }
                $interviewProgressCaptured = ($Action -in @('start_interview', 'resume_interview')) -and (
                    (-not [string]::IsNullOrWhiteSpace($capturedInterviewId)) -or
                    (-not [string]::IsNullOrWhiteSpace($capturedSeedPath))
                )

                if ($errorKind -eq 'user_interrupted' -and $interviewProgressCaptured) {
                    $summary = if (-not [string]::IsNullOrWhiteSpace($capturedSeedPath)) {
                        "Interview action '$Action' advanced and produced a seed, but the runtime is waiting for another response."
                    }
                    else {
                        "Interview action '$Action' advanced and is waiting for another response."
                    }

                    $artifacts = [ordered]@{
                        runtime_root      = $resolvedRuntimeRoot
                        runtime_data_root = $resolvedRuntimeDataRoot
                        runtime_trace     = $traceMetadata
                    }

                    foreach ($key in $outputArtifacts.Keys) {
                        if ($key -ne 'runtime_data_root') {
                            $artifacts[$key] = $outputArtifacts[$key]
                        }
                    }

                    if ($Action -eq 'resume_interview' -and -not [string]::IsNullOrWhiteSpace($InterviewResponse)) {
                        $artifacts.interview_response = $InterviewResponse
                    }

                    $result = New-ActionResult -Status 'partial' -Summary $summary `
                        -Artifacts $artifacts -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
                    break
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
                if (-not [string]::IsNullOrWhiteSpace($InterviewResponse)) {
                    $artifacts.interview_response = $InterviewResponse
                }
            }
            elseif ($Action -eq 'run_seed') {
                $artifacts.seed_path = Get-ResolvedSeedPath -PathValue $SeedPath
                if ($TargetWorkspace) {
                    $resolvedWorkspace = Get-TargetWorkspacePath -PathValue $TargetWorkspace
                    $artifacts.target_workspace = $resolvedWorkspace
                    $artifacts.changed_files = [string[]]@(Get-ChangedFiles -ResolvedWorkspacePath $resolvedWorkspace)
                }
            }

            $result = New-ActionResult -Status 'ok' -Summary "Action '$Action' completed." `
                -Artifacts $artifacts -NextActions $nextActions -Stdout $stdout -Stderr $stderr -ExitCode $exitCode
        }
    }

    $result = Normalize-ListContractForJson -Value $result
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
    $failure = Normalize-ListContractForJson -Value $failure
    if ($PrettyJson) {
        $failure | ConvertTo-Json -Depth 8
    }
    else {
        $failure | ConvertTo-Json -Depth 8 -Compress
    }
    exit 1
}
