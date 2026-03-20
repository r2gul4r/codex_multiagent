[CmdletBinding()]
param(
    [ValidateSet('Menu', 'InstallGlobal', 'ApplyWorkspace')]
    [string]$Mode = 'Menu',

    [string]$TargetWorkspace,

    [ValidateSet('standard', 'minimal')]
    [string]$Template = 'standard',

    [switch]$IncludeDocs,

    [switch]$Force,

    [switch]$NoPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 경로 기본 값
$InstallerRoot = $PSScriptRoot
$LocalKitRoot = Split-Path -Parent $PSScriptRoot
$GlobalHome = Join-Path $env:USERPROFILE '.codex'
$GlobalKitRoot = Join-Path $GlobalHome 'multiagent-kit'
$GlobalAgentsPath = Join-Path $GlobalHome 'AGENTS.md'
$GlobalCustomAgentsRoot = Join-Path $GlobalHome 'agents'
$GlobalRulesRoot = Join-Path $GlobalHome 'rules'
$LocalReadme = Join-Path $LocalKitRoot 'README.md'

function Write-Section {
    param([string]$Text)

    Write-Host ''
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )

    Ensure-Directory -Path $Destination

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        $target = Join-Path $Destination $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
    }
}

function Remove-StaleInstallerArtifacts {
    param([string]$InstallerPath)

    # 예전 exe 방식 잔해만 지정 제거
    $stalePaths = @(
        (Join-Path $InstallerPath 'CodexMultiAgentLauncher.exe'),
        (Join-Path $InstallerPath 'Launch-CodexMultiAgent.cmd'),
        (Join-Path $InstallerPath 'Build-Launcher.ps1'),
        (Join-Path $InstallerPath 'src')
    )

    foreach ($stalePath in $stalePaths) {
        if (Test-Path -LiteralPath $stalePath) {
            Remove-Item -LiteralPath $stalePath -Recurse -Force
        }
    }
}

function Get-SourceKitRoot {
    if (Test-Path -LiteralPath (Join-Path $GlobalKitRoot 'GLOBAL_AGENTS_TEMPLATE.md')) {
        return $GlobalKitRoot
    }

    return $LocalKitRoot
}

function Get-WorkspaceTemplateSource {
    param(
        [string]$SourceKitRoot,
        [string]$TemplateName
    )

    switch ($TemplateName) {
        'standard' { return (Join-Path $SourceKitRoot 'WORKSPACE_OVERRIDE_TEMPLATE.md') }
        'minimal' { return (Join-Path $SourceKitRoot 'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md') }
        default { throw "Unsupported template: $TemplateName" }
    }
}

function Install-CodexCustomAgents {
    param([string]$SourceKitRoot)

    $sourceAgentsRoot = Join-Path $SourceKitRoot 'codex_agents'
    if (-not (Test-Path -LiteralPath $sourceAgentsRoot -PathType Container)) {
        return
    }

    Ensure-Directory -Path $GlobalCustomAgentsRoot

    Get-ChildItem -LiteralPath $sourceAgentsRoot -File | ForEach-Object {
        $target = Join-Path $GlobalCustomAgentsRoot $_.Name

        if (Should-OverwriteFile -Path $target) {
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
        else {
            Write-Host "Skipped subagent config overwrite: $target" -ForegroundColor Yellow
        }
    }
}

function Install-CodexRules {
    param([string]$SourceKitRoot)

    $sourceRulesRoot = Join-Path $SourceKitRoot 'codex_rules'
    if (-not (Test-Path -LiteralPath $sourceRulesRoot -PathType Container)) {
        return
    }

    Ensure-Directory -Path $GlobalRulesRoot

    Get-ChildItem -LiteralPath $sourceRulesRoot -File | ForEach-Object {
        $target = Join-Path $GlobalRulesRoot $_.Name

        if (Should-OverwriteFile -Path $target) {
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
        else {
            Write-Host "Skipped rules overwrite: $target" -ForegroundColor Yellow
        }
    }
}

function Show-InfoBanner {
    $sourceRoot = Get-SourceKitRoot
    $sourceLabel = if ($sourceRoot -eq $GlobalKitRoot) { 'global kit' } else { 'local repository copy' }

    Write-Section -Text 'Codex Multi-Agent Kit'
    Write-Host "Source: $sourceLabel"
    Write-Host "Local path: $LocalKitRoot"
    Write-Host "Global home: $GlobalHome"
    Write-Host "Global defaults: $GlobalAgentsPath"
}

function Select-Folder {
    param([string]$Description)

    # 폴더 선택 GUI 우선 시도
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = $Description
        $dialog.ShowNewFolderButton = $true

        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
            return $dialog.SelectedPath
        }
    }
    catch {
        # 실패하면 콘솔 입력 사용
    }

    if ($NoPrompt) {
        throw 'A target folder is required when -NoPrompt is used'
    }

    $path = Read-Host "$Description`nEnter a full path"
    if (-not $path) {
        throw 'No folder selected'
    }

    return $path
}

function Read-MenuChoice {
    if ($NoPrompt) {
        throw 'Mode=Menu cannot be used with -NoPrompt'
    }

    Write-Host ''
    Write-Host 'Choose a mode'
    Write-Host '[1] Install global defaults for all Codex workspaces'
    Write-Host '[2] Apply a workspace override'
    Write-Host '[Q] Quit'

    while ($true) {
        $choice = (Read-Host 'Selection').Trim().ToUpperInvariant()

        switch ($choice) {
            '1' { return 'InstallGlobal' }
            '2' { return 'ApplyWorkspace' }
            'Q' { return 'Quit' }
            default { Write-Host 'Please choose 1, 2, or Q' -ForegroundColor Yellow }
        }
    }
}

function Read-TemplateChoice {
    if ($NoPrompt) {
        return $Template
    }

    Write-Host ''
    Write-Host 'Choose a workspace override template'
    Write-Host '[1] Standard'
    Write-Host '[2] Minimal'

    while ($true) {
        $choice = (Read-Host 'Selection').Trim()

        switch ($choice) {
            '1' { return 'standard' }
            '2' { return 'minimal' }
            default { Write-Host 'Please choose 1 or 2' -ForegroundColor Yellow }
        }
    }
}

function Read-IncludeDocsChoice {
    if ($NoPrompt) {
        return [bool]$IncludeDocs
    }

    Write-Host ''
    Write-Host 'Copy supporting docs to docs\codex-multiagent'
    Write-Host '[Y] Yes'
    Write-Host '[N] No'

    while ($true) {
        $choice = (Read-Host 'Selection').Trim().ToUpperInvariant()

        switch ($choice) {
            'Y' { return $true }
            'N' { return $false }
            default { Write-Host 'Please choose Y or N' -ForegroundColor Yellow }
        }
    }
}

function Should-OverwriteFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $true
    }

    if ($Force -or $NoPrompt) {
        return $true
    }

    while ($true) {
        $choice = (Read-Host "Overwrite existing file $Path ? [Y/N]").Trim().ToUpperInvariant()

        switch ($choice) {
            'Y' { return $true }
            'N' { return $false }
            default { Write-Host 'Please choose Y or N' -ForegroundColor Yellow }
        }
    }
}

function Install-GlobalKit {
    Write-Section -Text 'Installing global defaults'

    Ensure-Directory -Path $GlobalHome
    Ensure-Directory -Path $GlobalKitRoot
    Remove-StaleInstallerArtifacts -InstallerPath (Join-Path $GlobalKitRoot 'installer')

    $items = @(
        'README.md',
        'CHANGELOG.md',
        'AGENTS_TEMPLATE.md',
        'GLOBAL_AGENTS_TEMPLATE.md',
        'STATE_TEMPLATE.md',
        'WORKSPACE_OVERRIDE_TEMPLATE.md',
        'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md',
        'MULTI_AGENT_GUIDE.md',
        'codex_agents',
        'codex_rules',
        'examples',
        'profiles',
        'installer'
    )

    foreach ($item in $items) {
        $source = Join-Path $LocalKitRoot $item
        $destination = Join-Path $GlobalKitRoot $item

        if (Test-Path -LiteralPath $source -PathType Container) {
            Copy-DirectoryContents -Source $source -Destination $destination
        }
        else {
            Ensure-Directory -Path (Split-Path -Parent $destination)
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
    }

    $globalTemplate = Join-Path $LocalKitRoot 'GLOBAL_AGENTS_TEMPLATE.md'
    if (-not (Should-OverwriteFile -Path $GlobalAgentsPath)) {
        Write-Host 'Skipped global AGENTS.md overwrite' -ForegroundColor Yellow
        return
    }

    Copy-Item -LiteralPath $globalTemplate -Destination $GlobalAgentsPath -Force
    Install-CodexCustomAgents -SourceKitRoot $LocalKitRoot
    Install-CodexRules -SourceKitRoot $LocalKitRoot

    Write-Host "Installed global defaults at $GlobalAgentsPath" -ForegroundColor Green
    Write-Host "Installed Codex subagent configs at $GlobalCustomAgentsRoot" -ForegroundColor Green
    Write-Host "Installed Codex command rules at $GlobalRulesRoot" -ForegroundColor Green
    Write-Host "Reference kit copied to $GlobalKitRoot"
}

function Apply-ToWorkspace {
    param(
        [string]$WorkspacePath,
        [string]$TemplateName,
        [bool]$CopyDocs
    )

    Ensure-Directory -Path $WorkspacePath

    $resolvedWorkspace = (Resolve-Path -LiteralPath $WorkspacePath).Path
    $sourceKitRoot = Get-SourceKitRoot
    $templateSource = Get-WorkspaceTemplateSource -SourceKitRoot $sourceKitRoot -TemplateName $TemplateName
    $agentsTarget = Join-Path $resolvedWorkspace 'AGENTS.md'
    $stateTemplate = Join-Path $sourceKitRoot 'STATE_TEMPLATE.md'
    $stateTarget = Join-Path $resolvedWorkspace 'STATE.md'

    Write-Section -Text 'Applying workspace override'
    Write-Host "Workspace: $resolvedWorkspace"
    Write-Host "Template: $TemplateName"
    Write-Host "Supporting docs: $CopyDocs"

    if (-not (Should-OverwriteFile -Path $agentsTarget)) {
        Write-Host 'Skipped AGENTS.md overwrite' -ForegroundColor Yellow
        return
    }

    Copy-Item -LiteralPath $templateSource -Destination $agentsTarget -Force

    if (-not (Test-Path -LiteralPath $stateTarget)) {
        Copy-Item -LiteralPath $stateTemplate -Destination $stateTarget -Force
    }

    if ($CopyDocs) {
        $docsRoot = Join-Path $resolvedWorkspace 'docs\codex-multiagent'
        Ensure-Directory -Path $docsRoot

        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'README.md') -Destination (Join-Path $docsRoot 'README.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'CHANGELOG.md') -Destination (Join-Path $docsRoot 'CHANGELOG.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'MULTI_AGENT_GUIDE.md') -Destination (Join-Path $docsRoot 'MULTI_AGENT_GUIDE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'GLOBAL_AGENTS_TEMPLATE.md') -Destination (Join-Path $docsRoot 'GLOBAL_AGENTS_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'STATE_TEMPLATE.md') -Destination (Join-Path $docsRoot 'STATE_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'WORKSPACE_OVERRIDE_TEMPLATE.md') -Destination (Join-Path $docsRoot 'WORKSPACE_OVERRIDE_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md') -Destination (Join-Path $docsRoot 'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md') -Force
        if (Test-Path -LiteralPath (Join-Path $sourceKitRoot 'codex_agents')) {
            Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'codex_agents') -Destination (Join-Path $docsRoot 'codex_agents')
        }
        if (Test-Path -LiteralPath (Join-Path $sourceKitRoot 'codex_rules')) {
            Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'codex_rules') -Destination (Join-Path $docsRoot 'codex_rules')
        }
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'profiles') -Destination (Join-Path $docsRoot 'profiles')
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'examples') -Destination (Join-Path $docsRoot 'examples')
    }

    Write-Host "Applied workspace override to $resolvedWorkspace" -ForegroundColor Green
}

try {
    Show-InfoBanner

    $effectiveMode = $Mode
    if ($effectiveMode -eq 'Menu') {
        $effectiveMode = Read-MenuChoice
    }

    if ($effectiveMode -eq 'Quit') {
        Write-Host 'No action selected'
        exit 0
    }

    switch ($effectiveMode) {
        'InstallGlobal' {
            Install-GlobalKit
        }
        'ApplyWorkspace' {
            $effectiveTemplate = Read-TemplateChoice
            $copyDocs = Read-IncludeDocsChoice
            $workspace = if ($TargetWorkspace) { $TargetWorkspace } else { Select-Folder -Description 'Select the workspace folder for the override' }
            Apply-ToWorkspace -WorkspacePath $workspace -TemplateName $effectiveTemplate -CopyDocs $copyDocs
        }
        default {
            throw "Unsupported mode: $effectiveMode"
        }
    }
}
catch {
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if (-not $NoPrompt) {
        Write-Host "Reference: $LocalReadme"
        Read-Host 'Press Enter to exit' | Out-Null
    }
    exit 1
}
