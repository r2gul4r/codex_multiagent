[CmdletBinding()]
param(
    [ValidateSet('Menu', 'InstallGlobal', 'ApplyWorkspace', 'InstallAndApply')]
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

# 경로와 기본 값 초기화
$InstallerRoot = $PSScriptRoot
$LocalKitRoot = Split-Path -Parent $PSScriptRoot
$GlobalKitRoot = Join-Path $env:USERPROFILE '.codex\multiagent-kit'
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

    # 예전 exe 방식 흔적만 지정해서 제거
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
    if (Test-Path -LiteralPath (Join-Path $GlobalKitRoot 'AGENTS_TEMPLATE.md')) {
        return $GlobalKitRoot
    }

    return $LocalKitRoot
}

function Get-TemplateSource {
    param(
        [string]$SourceKitRoot,
        [string]$TemplateName
    )

    switch ($TemplateName) {
        'standard' { return (Join-Path $SourceKitRoot 'AGENTS_TEMPLATE.md') }
        'minimal' { return (Join-Path $SourceKitRoot 'examples\AGENTS.minimal.example.md') }
        default { throw "Unsupported template: $TemplateName" }
    }
}

function Show-InfoBanner {
    $sourceRoot = Get-SourceKitRoot
    $sourceLabel = if ($sourceRoot -eq $GlobalKitRoot) { 'global kit' } else { 'local repository copy' }

    Write-Section -Text 'Codex Multi-Agent Kit'
    Write-Host "Source: $sourceLabel"
    Write-Host "Local path: $LocalKitRoot"
    Write-Host "Global path: $GlobalKitRoot"
}

function Select-Folder {
    param([string]$Description)

    # GUI 선택기가 되면 그걸 우선 사용
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
        # 폴백은 아래 콘솔 입력
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
    Write-Host '[1] Install or update the global kit'
    Write-Host '[2] Apply the kit to a workspace'
    Write-Host '[3] Install globally and then apply to a workspace'
    Write-Host '[Q] Quit'

    while ($true) {
        $choice = (Read-Host 'Selection').Trim().ToUpperInvariant()

        switch ($choice) {
            '1' { return 'InstallGlobal' }
            '2' { return 'ApplyWorkspace' }
            '3' { return 'InstallAndApply' }
            'Q' { return 'Quit' }
            default { Write-Host 'Please choose 1, 2, 3, or Q' -ForegroundColor Yellow }
        }
    }
}

function Read-TemplateChoice {
    if ($NoPrompt) {
        return $Template
    }

    Write-Host ''
    Write-Host 'Choose a template'
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
    Write-Section -Text 'Installing global kit'

    Ensure-Directory -Path $GlobalKitRoot
    Remove-StaleInstallerArtifacts -InstallerPath (Join-Path $GlobalKitRoot 'installer')

    $items = @(
        'README.md',
        'AGENTS_TEMPLATE.md',
        'MULTI_AGENT_GUIDE.md',
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

    Write-Host "Installed or updated the global kit at $GlobalKitRoot" -ForegroundColor Green
    Write-Host 'Paste this into PowerShell next time if you want the interactive menu'
    Write-Host "& '$GlobalKitRoot\installer\CodexMultiAgent.ps1'"
}

function Apply-ToWorkspace {
    param(
        [string]$WorkspacePath,
        [string]$TemplateName,
        [bool]$CopyDocs
    )

    $resolvedWorkspace = Resolve-Path -LiteralPath $WorkspacePath
    $sourceKitRoot = Get-SourceKitRoot
    $templateSource = Get-TemplateSource -SourceKitRoot $sourceKitRoot -TemplateName $TemplateName
    $agentsTarget = Join-Path $resolvedWorkspace 'AGENTS.md'

    Write-Section -Text 'Applying to workspace'
    Write-Host "Workspace: $resolvedWorkspace"
    Write-Host "Template: $TemplateName"
    Write-Host "Supporting docs: $CopyDocs"

    if (-not (Should-OverwriteFile -Path $agentsTarget)) {
        Write-Host 'Skipped AGENTS.md overwrite' -ForegroundColor Yellow
        return
    }

    Copy-Item -LiteralPath $templateSource -Destination $agentsTarget -Force

    if ($CopyDocs) {
        $docsRoot = Join-Path $resolvedWorkspace 'docs\codex-multiagent'
        Ensure-Directory -Path $docsRoot

        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'README.md') -Destination (Join-Path $docsRoot 'README.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'MULTI_AGENT_GUIDE.md') -Destination (Join-Path $docsRoot 'MULTI_AGENT_GUIDE.md') -Force
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'profiles') -Destination (Join-Path $docsRoot 'profiles')
        Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'examples') -Destination (Join-Path $docsRoot 'examples')
    }

    Write-Host "Applied the kit to $resolvedWorkspace" -ForegroundColor Green
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
            $workspace = if ($TargetWorkspace) { $TargetWorkspace } else { Select-Folder -Description 'Select the workspace folder to apply the multi-agent kit' }
            Apply-ToWorkspace -WorkspacePath $workspace -TemplateName $effectiveTemplate -CopyDocs $copyDocs
        }
        'InstallAndApply' {
            Install-GlobalKit
            $effectiveTemplate = Read-TemplateChoice
            $copyDocs = Read-IncludeDocsChoice
            $workspace = if ($TargetWorkspace) { $TargetWorkspace } else { Select-Folder -Description 'Select the workspace folder to apply the multi-agent kit' }
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
