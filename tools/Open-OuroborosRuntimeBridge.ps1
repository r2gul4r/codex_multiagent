[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu',
    [string]$RuntimeDataRoot = '~/.ouroboros',
    [string]$TranscriptPath,
    [int]$TailLines = 120,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-BashSingleQuoted {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $separator = "'" + '"' + "'" + '"' + "'"
    $escaped = ($Value -split "'") -join $separator
    return "'" + $escaped + "'"
}

function ConvertTo-PowerShellSingleQuoted {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    return "'" + ($Value -replace "'", "''") + "'"
}

function Resolve-WslUserPath {
    param(
        [Parameter(Mandatory = $true)][string]$DistroName,
        [Parameter(Mandatory = $true)][string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $PathValue
    }

    if ($PathValue.StartsWith('/')) {
        return $PathValue
    }

    if ([System.IO.Path]::IsPathRooted($PathValue) -or $PathValue -match '^[A-Za-z]:[\\/]|^\\\\') {
        $command = @(
            'bash',
            '-lc',
            ('wslpath -a ' + (ConvertTo-BashSingleQuoted -Value $PathValue))
        )

        $output = & wsl.exe -d $DistroName @command 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to convert Windows path to WSL path '$PathValue' in distro '$DistroName': $($output -join "`n")"
        }

        return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
    }

    if ($PathValue.StartsWith('~/') -or $PathValue -eq '~') {
        $command = @(
            'bash',
            '-lc',
            ('INPUT_PATH=' + (ConvertTo-BashSingleQuoted -Value $PathValue) + " python3 - <<'PY'
import os
print(os.path.expanduser(os.environ['INPUT_PATH']))
PY")
        )

        $output = & wsl.exe -d $DistroName @command 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to resolve WSL path '$PathValue' in distro '$DistroName': $($output -join "`n")"
        }

        return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
    }

    return $PathValue
}

function Get-LatestTailPath {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedRuntimeDataRoot
    )

    $command = @"
python3 - <<'PY'
from pathlib import Path
import json

root = Path($(ConvertTo-BashSingleQuoted -Value $ResolvedRuntimeDataRoot))

def latest(directory, pattern):
    if not directory.exists():
        return None
    matches = sorted(directory.glob(pattern), key=lambda path: path.stat().st_mtime, reverse=True)
    return matches[0] if matches else None

transcript = latest(root / "transcripts", "ouroboros-transcript-*.log")
log = latest(root / "logs", "ouroboros.log*")
tail = transcript or log
print(json.dumps({
    "transcript_path": str(transcript) if transcript else None,
    "log_path": str(log) if log else None,
    "tail_path": str(tail) if tail else None,
}))
PY
"@

    $output = & wsl.exe -d $Distro bash -lc $command 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    try {
        return ($output -join "`n") | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

$resolvedRuntimeDataRoot = Resolve-WslUserPath -DistroName $Distro -PathValue $RuntimeDataRoot
    if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
        $tailInfo = Get-LatestTailPath -ResolvedRuntimeDataRoot $resolvedRuntimeDataRoot
        if ($tailInfo -and -not [string]::IsNullOrWhiteSpace([string]$tailInfo.tail_path)) {
            $TranscriptPath = [string]$tailInfo.tail_path
        }
    }

$resolvedTailPath = if (-not [string]::IsNullOrWhiteSpace($TranscriptPath)) {
    if ($TranscriptPath.StartsWith('/')) {
        $TranscriptPath
    }
    else {
        Resolve-WslUserPath -DistroName $Distro -PathValue $TranscriptPath
    }
}
else {
    ($resolvedRuntimeDataRoot.TrimEnd('/')) + '/logs/ouroboros.log'
}

$resolvedTailDir = Split-Path -Path $resolvedTailPath -Parent
$bashPayload = @(
    'mkdir -p ' + (ConvertTo-BashSingleQuoted -Value $resolvedTailDir)
    'touch ' + (ConvertTo-BashSingleQuoted -Value $resolvedTailPath)
    'tail -n ' + [string]$TailLines + ' -F ' + (ConvertTo-BashSingleQuoted -Value $resolvedTailPath)
) -join '; '

$bridgeCommand = @"
`$host.UI.RawUI.WindowTitle = 'Ouroboros Runtime Bridge'
Write-Host 'Ouroboros runtime bridge attached.' -ForegroundColor Cyan
Write-Host ('Distro: {0}' -f $(ConvertTo-PowerShellSingleQuoted -Value $Distro))
Write-Host ('Runtime data root: {0}' -f $(ConvertTo-PowerShellSingleQuoted -Value $resolvedRuntimeDataRoot))
Write-Host ('Tail path: {0}' -f $(ConvertTo-PowerShellSingleQuoted -Value $resolvedTailPath))
Write-Host ''
wsl.exe -d $(ConvertTo-PowerShellSingleQuoted -Value $Distro) bash -lc $(ConvertTo-PowerShellSingleQuoted -Value $bashPayload)
"@

$argumentList = @(
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-Command', $bridgeCommand
)

$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $argumentList -PassThru

$result = [ordered]@{
    status = 'ok'
    summary = 'Opened a visible Ouroboros runtime bridge window.'
    distro = $Distro
    runtime_data_root = $resolvedRuntimeDataRoot
    transcript_path = if ([string]::IsNullOrWhiteSpace($TranscriptPath)) { $null } else { $resolvedTailPath }
    log_path = if ($resolvedTailPath -like '*/logs/ouroboros.log') { $resolvedTailPath } else { $null }
    tail_path = $resolvedTailPath
    tail_lines = $TailLines
    pid = $process.Id
}

if ($PassThru.IsPresent) {
    $result | ConvertTo-Json -Depth 8
}
