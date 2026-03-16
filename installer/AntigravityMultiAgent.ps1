[CmdletBinding()]
param(
    [ValidateSet('Menu', 'InstallGlobal', 'ApplyWorkspace')]
    [string]$Mode = 'Menu',

    [string]$TargetWorkspace,

    [ValidateSet('standard', 'minimal')]
    [string]$Template = 'standard',

    [switch]$CleanLegacy,

    [switch]$IncludeDocs,

    [switch]$Force,

    [switch]$NoPrompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 경로 기본 값
$InstallerRoot = $PSScriptRoot
$LocalKitRoot = Split-Path -Parent $PSScriptRoot
$RuntimeHome = Join-Path $env:USERPROFILE '.gemini\antigravity'
$GlobalKitRoot = Join-Path $RuntimeHome 'multiagent-kit'
$GlobalAgentsPath = Join-Path $RuntimeHome 'AGENTS.md'
$GlobalWorkflowsRoot = Join-Path $RuntimeHome 'global_workflows'
$GlobalSkillsRoot = Join-Path $RuntimeHome 'skills'
$LegacyHome = Join-Path $env:USERPROFILE '.antigravity'
$LocalReadme = Join-Path $LocalKitRoot 'installer\ANTIGRAVITY_INSTALL.md'

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

    if ((Test-Path -LiteralPath $Source) -and (Test-Path -LiteralPath $Destination)) {
        $sourcePath = (Get-Item -LiteralPath $Source).FullName.TrimEnd('\')
        $destinationPath = (Get-Item -LiteralPath $Destination).FullName.TrimEnd('\')
        if ($sourcePath -eq $destinationPath) {
            return
        }
    }

    Ensure-Directory -Path $Destination

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        $target = Join-Path $Destination $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
    }
}

function Remove-StaleInstallerArtifacts {
    param([string]$InstallerPath)

    # 예전 실행기 흔적만 정리
    $stalePaths = @(
        (Join-Path $InstallerPath 'AntigravityMultiAgentLauncher.exe'),
        (Join-Path $InstallerPath 'Launch-AntigravityMultiAgent.cmd'),
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

function Copy-RuntimeAssetFile {
    param(
        [string]$SourceRoot,
        [string]$RelativePath,
        [string]$DestinationRoot
    )

    $source = Join-Path $SourceRoot $RelativePath
    $destination = Join-Path $DestinationRoot (Split-Path $RelativePath -Leaf)

    Ensure-Directory -Path $DestinationRoot
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

function Install-RuntimeAssets {
    param([string]$SourceKitRoot)

    Ensure-Directory -Path $GlobalWorkflowsRoot
    Ensure-Directory -Path $GlobalSkillsRoot

    Copy-RuntimeAssetFile -SourceRoot $SourceKitRoot -RelativePath 'antigravity_runtime\global_workflows\multiagent-defaults.md' -DestinationRoot $GlobalWorkflowsRoot
    Copy-RuntimeAssetFile -SourceRoot $SourceKitRoot -RelativePath 'antigravity_runtime\skills\multiagent-roles.md' -DestinationRoot $GlobalSkillsRoot
}

function Get-LegacyRuntimeFiles {
    param(
        [string]$DirectoryPath,
        [string[]]$ManagedFileNames
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $DirectoryPath -File | Where-Object {
        $ManagedFileNames -notcontains $_.Name
    })
}

function Move-LegacyRuntimeFiles {
    param(
        [string]$SourceDirectory,
        [string]$BackupDirectory,
        [string[]]$ManagedFileNames
    )

    $legacyFiles = @(Get-LegacyRuntimeFiles -DirectoryPath $SourceDirectory -ManagedFileNames $ManagedFileNames)
    if ($legacyFiles.Count -eq 0) {
        return 0
    }

    Ensure-Directory -Path $BackupDirectory

    foreach ($legacyFile in $legacyFiles) {
        Move-Item -LiteralPath $legacyFile.FullName -Destination (Join-Path $BackupDirectory $legacyFile.Name) -Force
    }

    return $legacyFiles.Count
}

function Quarantine-LegacyRuntimeAssets {
    $workflowManagedFiles = @('multiagent-defaults.md')
    $skillManagedFiles = @('multiagent-roles.md')
    $legacyFiles = @(@(
        (Get-LegacyRuntimeFiles -DirectoryPath $GlobalWorkflowsRoot -ManagedFileNames $workflowManagedFiles)
        (Get-LegacyRuntimeFiles -DirectoryPath $GlobalSkillsRoot -ManagedFileNames $skillManagedFiles)
    ) | Where-Object { $_ })

    if ($legacyFiles.Count -eq 0) {
        Write-Host 'No legacy runtime files found to quarantine'
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = Join-Path $RuntimeHome (Join-Path '_legacy_disabled' $timestamp)
    $workflowBackup = Join-Path $backupRoot 'global_workflows'
    $skillBackup = Join-Path $backupRoot 'skills'

    $workflowMoved = Move-LegacyRuntimeFiles -SourceDirectory $GlobalWorkflowsRoot -BackupDirectory $workflowBackup -ManagedFileNames $workflowManagedFiles
    $skillMoved = Move-LegacyRuntimeFiles -SourceDirectory $GlobalSkillsRoot -BackupDirectory $skillBackup -ManagedFileNames $skillManagedFiles

    Write-Host "Legacy runtime files quarantined to $backupRoot"
    Write-Host "Moved workflows: $workflowMoved"
    Write-Host "Moved skills: $skillMoved"
}

function Show-InfoBanner {
    $sourceRoot = Get-SourceKitRoot
    $sourceLabel = if ($sourceRoot -eq $GlobalKitRoot) { 'global kit' } else { 'local repository copy' }

    Write-Section -Text 'Antigravity Multi-Agent Kit'
    Write-Host "Source: $sourceLabel"
    Write-Host "Local path: $LocalKitRoot"
    Write-Host "Runtime home: $RuntimeHome"
    Write-Host "Global defaults: $GlobalAgentsPath"
    Write-Host "Legacy path: $LegacyHome"
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
    Write-Host '[1] Install global defaults for Antigravity'
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
    Write-Host 'Copy supporting docs to docs\antigravity-multiagent'
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

function Read-CleanLegacyChoice {
    if ($NoPrompt) {
        return [bool]$CleanLegacy
    }

    Write-Host ''
    Write-Host 'Quarantine legacy runtime files from global_workflows and skills'
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

    $sourceKitRoot = $LocalKitRoot

    Ensure-Directory -Path $RuntimeHome
    Ensure-Directory -Path $GlobalKitRoot
    Remove-StaleInstallerArtifacts -InstallerPath (Join-Path $GlobalKitRoot 'installer')

    $items = @(
        'README.md',
        'AGENTS_TEMPLATE.md',
        'GLOBAL_AGENTS_TEMPLATE.md',
        'STATE_TEMPLATE.md',
        'WORKSPACE_OVERRIDE_TEMPLATE.md',
        'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md',
        'MULTI_AGENT_GUIDE.md',
        'examples',
        'profiles',
        'installer',
        'antigravity_runtime'
    )

    foreach ($item in $items) {
        $source = Join-Path $sourceKitRoot $item
        $destination = Join-Path $GlobalKitRoot $item

        if (Test-Path -LiteralPath $source -PathType Container) {
            Copy-DirectoryContents -Source $source -Destination $destination
        }
        else {
            $shouldSkipFileCopy = $false
            if ((Test-Path -LiteralPath $source) -and (Test-Path -LiteralPath $destination)) {
                $sourcePath = (Get-Item -LiteralPath $source).FullName
                $destinationPath = (Get-Item -LiteralPath $destination).FullName
                if ($sourcePath -eq $destinationPath) {
                    $shouldSkipFileCopy = $true
                }
            }

            if (-not $shouldSkipFileCopy) {
                Ensure-Directory -Path (Split-Path -Parent $destination)
                Copy-Item -LiteralPath $source -Destination $destination -Force
            }
        }
    }

    $globalTemplate = Join-Path $sourceKitRoot 'GLOBAL_AGENTS_TEMPLATE.md'
    if (-not (Should-OverwriteFile -Path $GlobalAgentsPath)) {
        Write-Host 'Skipped global AGENTS.md overwrite' -ForegroundColor Yellow
    }
    else {
        Copy-Item -LiteralPath $globalTemplate -Destination $GlobalAgentsPath -Force
    }

    if ($CleanLegacy) {
        Quarantine-LegacyRuntimeAssets
    }

    Install-RuntimeAssets -SourceKitRoot $sourceKitRoot

    Write-Host "Installed global defaults at $GlobalAgentsPath" -ForegroundColor Green
    Write-Host "Runtime workflow: $(Join-Path $GlobalWorkflowsRoot 'multiagent-defaults.md')"
    Write-Host "Runtime skill: $(Join-Path $GlobalSkillsRoot 'multiagent-roles.md')"
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
        $docsRoot = Join-Path $resolvedWorkspace 'docs\antigravity-multiagent'
        Ensure-Directory -Path $docsRoot

        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'README.md') -Destination (Join-Path $docsRoot 'README.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'MULTI_AGENT_GUIDE.md') -Destination (Join-Path $docsRoot 'MULTI_AGENT_GUIDE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'GLOBAL_AGENTS_TEMPLATE.md') -Destination (Join-Path $docsRoot 'GLOBAL_AGENTS_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'STATE_TEMPLATE.md') -Destination (Join-Path $docsRoot 'STATE_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'WORKSPACE_OVERRIDE_TEMPLATE.md') -Destination (Join-Path $docsRoot 'WORKSPACE_OVERRIDE_TEMPLATE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md') -Destination (Join-Path $docsRoot 'WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md') -Force
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'profiles') -Destination (Join-Path $docsRoot 'profiles')
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'examples') -Destination (Join-Path $docsRoot 'examples')
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'antigravity_runtime') -Destination (Join-Path $docsRoot 'antigravity_runtime')
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
            $cleanLegacy = Read-CleanLegacyChoice
            if ($cleanLegacy) {
                $CleanLegacy = $true
            }
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
