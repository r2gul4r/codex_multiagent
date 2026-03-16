function Invoke-MultiAgentBootstrap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Codex', 'Antigravity')]
        [string]$Variant,

        [Parameter(Mandatory = $true)]
        [ValidateSet('InstallGlobal', 'ApplyWorkspace')]
        [string]$Mode,

        [string]$TargetWorkspace,

        [ValidateSet('standard', 'minimal')]
        [string]$Template = 'standard',

        [switch]$IncludeDocs
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if ($Mode -eq 'ApplyWorkspace' -and [string]::IsNullOrWhiteSpace($TargetWorkspace)) {
        throw 'TargetWorkspace is required when Mode is ApplyWorkspace'
    }

    if ($Mode -eq 'ApplyWorkspace' -and -not (Test-Path -LiteralPath $TargetWorkspace)) {
        New-Item -ItemType Directory -Path $TargetWorkspace -Force | Out-Null
    }

    $installerScript = switch ($Variant) {
        'Codex' { 'CodexMultiAgent.ps1' }
        'Antigravity' { 'AntigravityMultiAgent.ps1' }
        default { throw "Unsupported variant: $Variant" }
    }

    $tempPrefix = switch ($Variant) {
        'Codex' { 'codex-multiagent-' }
        'Antigravity' { 'antigravity-multiagent-' }
        default { throw "Unsupported variant: $Variant" }
    }

    # 깃허브에서 최신 킷 압축본을 받아 임시 폴더에서 실행
    $zipUrl = 'https://github.com/r2gul4r/codex_multiagent/archive/refs/heads/main.zip'
    $tempRoot = Join-Path $env:TEMP ($tempPrefix + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'kit.zip'
    $extractPath = Join-Path $tempRoot 'extract'

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $kitRoot = Join-Path $extractPath 'codex_multiagent-main'
        $installerPath = Join-Path $kitRoot ("installer\" + $installerScript)

        if (-not (Test-Path -LiteralPath $installerPath)) {
            throw "Failed to locate $installerScript in downloaded archive"
        }

        $invokeArgs = @(
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $installerPath,
            '-Mode', $Mode,
            '-Template', $Template,
            '-NoPrompt',
            '-Force'
        )

        if ($IncludeDocs) {
            $invokeArgs += '-IncludeDocs'
        }

        if ($Mode -eq 'ApplyWorkspace') {
            $invokeArgs += @('-TargetWorkspace', $TargetWorkspace)
        }

        & powershell @invokeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Installer failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            try {
                [System.IO.Directory]::Delete($tempRoot, $true)
            }
            catch {
                # 임시 폴더 정리 실패는 설치 성공보다 우선순위가 낮음
            }
        }
    }
}

function Install-CodexMultiAgent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('InstallGlobal', 'ApplyWorkspace')]
        [string]$Mode,

        [string]$TargetWorkspace,

        [ValidateSet('standard', 'minimal')]
        [string]$Template = 'standard',

        [switch]$IncludeDocs
    )

    Invoke-MultiAgentBootstrap -Variant 'Codex' -Mode $Mode -TargetWorkspace $TargetWorkspace -Template $Template -IncludeDocs:$IncludeDocs
}

function Install-AntigravityMultiAgent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('InstallGlobal', 'ApplyWorkspace')]
        [string]$Mode,

        [string]$TargetWorkspace,

        [ValidateSet('standard', 'minimal')]
        [string]$Template = 'standard',

        [switch]$IncludeDocs
    )

    Invoke-MultiAgentBootstrap -Variant 'Antigravity' -Mode $Mode -TargetWorkspace $TargetWorkspace -Template $Template -IncludeDocs:$IncludeDocs
}
