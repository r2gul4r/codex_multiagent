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
$GlobalConfigPath = Join-Path $GlobalHome 'config.toml'
$GlobalCustomAgentsRoot = Join-Path $GlobalHome 'agents'
$GlobalRulesRoot = Join-Path $GlobalHome 'rules'
$GlobalSkillsRoot = Join-Path $GlobalHome 'skills'
$GlobalManagedSkillsManifest = Join-Path $GlobalHome 'installer-managed-skills.manifest'
$LocalReadme = Join-Path $LocalKitRoot 'README.md'
$ManagedAgentFiles = @('default.toml', 'worker.toml', 'explorer.toml', 'reviewer.toml')

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

function Get-BackupStamp {
    return (Get-Date -Format 'yyyyMMdd-HHmmss')
}

function Backup-PathIfExists {
    param(
        [string]$Path,
        [string]$BackupRoot,
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    Ensure-Directory -Path $BackupRoot
    $target = Join-Path $BackupRoot $Name
    Ensure-Directory -Path (Split-Path -Parent $target)
    Copy-Item -LiteralPath $Path -Destination $target -Recurse -Force
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
    if (Test-Path -LiteralPath (Join-Path $GlobalKitRoot 'AGENTS.md')) {
        return $GlobalKitRoot
    }

    return $LocalKitRoot
}

function Get-WorkspaceContextPath {
    param([string]$WorkspacePath)

    return (Join-Path $WorkspacePath 'WORKSPACE_CONTEXT.toml')
}

function ConvertFrom-WorkspaceContextTomlValue {
    param([string]$RawValue)

    $trimmed = $RawValue.Trim()

    if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
        $items = [System.Collections.Generic.List[string]]::new()
        foreach ($match in [regex]::Matches($trimmed, '"((?:[^"\\]|\\.)*)"')) {
            $item = $match.Groups[1].Value -replace '\\n', "`n" -replace '\\"', '"' -replace '\\\\', '\'
            $items.Add($item)
        }
        return $items.ToArray()
    }

    if ($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
        $inner = $trimmed.Substring(1, $trimmed.Length - 2)
        return ($inner -replace '\\n', "`n" -replace '\\"', '"' -replace '\\\\', '\')
    }

    return $trimmed
}

function Read-WorkspaceContext {
    param([string]$Path)

    $context = @{}
    $currentSection = ''
    $allLines = Get-Content -LiteralPath $Path

    for ($index = 0; $index -lt $allLines.Count; $index++) {
        $line = $allLines[$index].Trim()
        if (-not $line -or $line.StartsWith('#')) {
            continue
        }

        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1].Trim()
            if (-not $context.ContainsKey($currentSection)) {
                $context[$currentSection] = @{}
            }
            continue
        }

        if (-not $currentSection) {
            continue
        }

        if ($line -match '^([A-Za-z0-9_-]+)\s*=\s*(.+)$') {
            $key = $Matches[1]
            $rawValue = $Matches[2].Trim()
            if ($rawValue.StartsWith('[') -and -not $rawValue.EndsWith(']')) {
                $builder = [System.Collections.Generic.List[string]]::new()
                $builder.Add($rawValue)
                while ($index + 1 -lt $allLines.Count) {
                    $index += 1
                    $nextLine = $allLines[$index].Trim()
                    if (-not $nextLine -or $nextLine.StartsWith('#')) {
                        continue
                    }
                    $builder.Add($nextLine)
                    if ($nextLine.EndsWith(']')) {
                        break
                    }
                }
                $rawValue = ($builder -join ' ')
            }
            $value = ConvertFrom-WorkspaceContextTomlValue -RawValue $rawValue
            $context[$currentSection][$key] = $value
        }
    }

    return $context
}

function Get-ContextString {
    param(
        [hashtable]$Context,
        [string]$Section,
        [string]$Key,
        [string]$DefaultValue = ''
    )

    if ($Context -and $Context.ContainsKey($Section) -and $Context[$Section].ContainsKey($Key)) {
        return [string]$Context[$Section][$Key]
    }

    return $DefaultValue
}

function Get-ContextArray {
    param(
        [hashtable]$Context,
        [string]$Section,
        [string]$Key
    )

    if ($Context -and $Context.ContainsKey($Section) -and $Context[$Section].ContainsKey($Key)) {
        $value = $Context[$Section][$Key]
        if ($value -is [System.Array]) {
            return [string[]]$value
        }
        if ($value) {
            return @([string]$value)
        }
    }

    return @()
}

function Merge-ContextItems {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Items
    )

    $merged = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        if ($null -eq $item) {
            continue
        }
        if ($item -is [System.Array]) {
            foreach ($entry in $item) {
                if ($entry) {
                    $text = [string]$entry
                    if ($seen.Add($text)) {
                        $merged.Add($text)
                    }
                }
            }
        }
        elseif ($item) {
            $text = [string]$item
            if ($seen.Add($text)) {
                $merged.Add($text)
            }
        }
    }
    return $merged.ToArray()
}

function Compress-PathLikeItems {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Items
    )

    $pathTokens = [System.Collections.Generic.List[string]]::new()
    foreach ($item in (Merge-ContextItems $Items)) {
        if ($item -match '\s' -and $item -match '/' -and -not $item.Contains(': ')) {
            foreach ($token in ($item -split '\s+')) {
                if ($token) {
                    $pathTokens.Add($token)
                }
            }
        }
        else {
            $pathTokens.Add($item)
        }
    }

    $normalized = @(Merge-ContextItems $pathTokens.ToArray())
    $wildcardOwners = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $normalized) {
        if ($item.EndsWith('/**')) {
            $wildcardOwners.Add($item.Substring(0, $item.Length - 3)) | Out-Null
        }
    }

    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $normalized) {
        if (-not $item.Contains(' ') -and $wildcardOwners.Contains($item)) {
            continue
        }
        $result.Add($item)
    }
    return $result.ToArray()
}

function Get-DerivedWorkspaceSummary {
    param(
        [hashtable]$Context,
        [string]$WorkspaceName
    )

    $summary = Get-ContextString -Context $Context -Section 'workspace' -Key 'summary'
    if (-not $summary) {
        $summary = Get-ContextString -Context $Context -Section 'brand' -Key 'summary'
    }
    if (-not $summary) {
        $summary = "Repository-specific context used to generate a workspace override AGENTS.md and initial STATE.md for $WorkspaceName."
    }
    return $summary
}

function Get-DerivedErrorLogPath {
    param([hashtable]$Context)

    $errorLogPath = Get-ContextString -Context $Context -Section 'workspace' -Key 'error_log_path'
    if (-not $errorLogPath) {
        $errorLogPath = 'ERROR_LOG.md'
    }
    return $errorLogPath
}

function Resolve-WorkspaceRelativePath {
    param(
        [string]$WorkspaceRoot,
        [string]$RelativePath,
        [string]$PathLabel
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "$PathLabel cannot be empty"
    }

    if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.StartsWith('~')) {
        throw "$PathLabel must be workspace-relative: $RelativePath"
    }

    $root = [System.IO.Path]::GetFullPath($WorkspaceRoot)
    $normalizedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $RelativePath))

    $rootPrefix = $normalizedRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($candidate -eq $normalizedRoot) {
        throw "$PathLabel must point to a file: $RelativePath"
    }

    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$PathLabel escapes workspace root: $RelativePath"
    }

    return $candidate
}

function Get-DerivedRepositoryFacts {
    param([hashtable]$Context)

    $facts = [System.Collections.Generic.List[string]]::new()
    foreach ($item in (Get-ContextArray -Context $Context -Section 'repository' -Key 'facts')) { $facts.Add($item) }

    $displayName = Get-ContextString -Context $Context -Section 'workspace' -Key 'display_name'
    if ($displayName) { $facts.Add("Display name: $displayName") }

    $pageKind = Get-ContextString -Context $Context -Section 'workspace' -Key 'page_kind'
    if ($pageKind) { $facts.Add("Page kind: $pageKind") }

    $primaryEntry = Get-ContextString -Context $Context -Section 'workspace' -Key 'primary_entry'
    if ($primaryEntry) { $facts.Add("Primary entry: $primaryEntry") }

    $pageUrl = Get-ContextString -Context $Context -Section 'workspace' -Key 'page_url'
    if ($pageUrl) { $facts.Add("Primary page URL: $pageUrl") }

    $locale = Get-ContextString -Context $Context -Section 'workspace' -Key 'locale'
    if ($locale) { $facts.Add("Locale: $locale") }

    $errorLogPath = Get-DerivedErrorLogPath -Context $Context
    if ($errorLogPath) { $facts.Add(('Error log path: `{0}`' -f $errorLogPath)) }

    $sourceOfTruth = Get-ContextString -Context $Context -Section 'architecture' -Key 'source_of_truth'
    if ($sourceOfTruth) { $facts.Add("Source of truth: $sourceOfTruth") }

    $shellRuntime = Get-ContextString -Context $Context -Section 'architecture' -Key 'shell_runtime'
    if ($shellRuntime) { $facts.Add("Shell runtime: $shellRuntime") }

    $sharedReact = Get-ContextString -Context $Context -Section 'architecture' -Key 'shared_react_components'
    if ($sharedReact) { $facts.Add("Shared React components: $sharedReact") }

    $authoringModel = Get-ContextString -Context $Context -Section 'workflow' -Key 'authoring_model'
    if ($authoringModel) { $facts.Add("Authoring model: $authoringModel") }

    $workingStyle = Get-ContextString -Context $Context -Section 'workflow' -Key 'current_working_style'
    if ($workingStyle) { $facts.Add("Working style: $workingStyle") }

    $deployTarget = Get-ContextString -Context $Context -Section 'deployment_goal' -Key 'primary_runtime'
    if ($deployTarget) { $facts.Add("Deployment goal: $deployTarget") }

    $currentDeployBase = Get-ContextString -Context $Context -Section 'deployment_current' -Key 'active_deploy_base'
    if ($currentDeployBase) { $facts.Add("Current deployment base: $currentDeployBase") }

    return $facts.ToArray()
}

function Get-DerivedRequiredRead {
    param([hashtable]$Context)

    $items = @(Get-ContextArray -Context $Context -Section 'required_context' -Key 'read')
    if ($items.Count -gt 0) {
        return $items
    }

    return @()
}

function Get-DerivedVerificationCommands {
    param([hashtable]$Context)

    return (Merge-ContextItems `
        (Get-ContextArray -Context $Context -Section 'verification' -Key 'commands') `
        (Get-ContextArray -Context $Context -Section 'verification' -Key 'recommended_commands'))
}

function Get-DerivedSharedContracts {
    param([hashtable]$Context)

    $contracts = [System.Collections.Generic.List[string]]::new()
    foreach ($item in (Get-ContextArray -Context $Context -Section 'contracts' -Key 'shared')) { $contracts.Add($item) }

    $sourceOfTruth = Get-ContextString -Context $Context -Section 'architecture' -Key 'source_of_truth'
    if ($sourceOfTruth) { $contracts.Add("Frontend source of truth remains $sourceOfTruth") }

    $routeConstants = Get-ContextString -Context $Context -Section 'architecture' -Key 'route_constants'
    if ($routeConstants) { $contracts.Add("Route constants stay aligned with $routeConstants") }

    $authoringModel = Get-ContextString -Context $Context -Section 'workflow' -Key 'authoring_model'
    if ($authoringModel) { $contracts.Add($authoringModel) }

    $mirrorPolicy = Get-ContextString -Context $Context -Section 'deployment_target' -Key 'mirror_policy'
    if ($mirrorPolicy) { $contracts.Add($mirrorPolicy) }

    $envSource = Get-ContextString -Context $Context -Section 'env_strategy' -Key 'current_env_source_of_truth'
    if ($envSource) { $contracts.Add("Current env source of truth: $envSource") }

    return $contracts.ToArray()
}

function Get-DerivedSharedAssetPaths {
    param([hashtable]$Context)

    $explicitSharedAssets = @(Get-ContextArray -Context $Context -Section 'paths' -Key 'shared_assets')
    if ($explicitSharedAssets.Count -gt 0) {
        return (Compress-PathLikeItems $explicitSharedAssets)
    }

    $explicitEditIn = @(Get-ContextArray -Context $Context -Section 'editing_rules' -Key 'edit_in')
    if ($explicitEditIn.Count -gt 0) {
        return (Compress-PathLikeItems $explicitEditIn)
    }

    return (Compress-PathLikeItems `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'shell_runtime') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'shared_react_components') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'landing_script') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'landing_stylesheet') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'header_component') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'footer_component') `
        (Get-ContextString -Context $Context -Section 'architecture' -Key 'route_constants'))
}

function Get-DerivedDoNotTouchPaths {
    param([hashtable]$Context)

    $explicitDoNotEdit = @(Get-ContextArray -Context $Context -Section 'editing_rules' -Key 'do_not_edit')
    if ($explicitDoNotEdit.Count -gt 0) {
        return (Compress-PathLikeItems $explicitDoNotEdit)
    }

    return (Compress-PathLikeItems `
        (Get-ContextArray -Context $Context -Section 'paths' -Key 'do_not_touch'))
}

function Get-DerivedHardTriggers {
    param([hashtable]$Context)

    $triggers = [System.Collections.Generic.List[string]]::new()
    foreach ($item in (Get-ContextArray -Context $Context -Section 'triggers' -Key 'hard')) { $triggers.Add($item) }

    $routeConstants = Get-ContextString -Context $Context -Section 'architecture' -Key 'route_constants'
    if ($routeConstants) { $triggers.Add("Changing route constants or route ownership in $routeConstants") }

    $shellRuntime = Get-ContextString -Context $Context -Section 'architecture' -Key 'shell_runtime'
    if ($shellRuntime) { $triggers.Add("Changing shared shell runtime behavior in $shellRuntime") }

    $webappMirror = Get-ContextString -Context $Context -Section 'architecture' -Key 'webapp_mirror'
    if ($webappMirror) { $triggers.Add("Touching deployment mirror path $webappMirror") }

    $springMirror = Get-ContextString -Context $Context -Section 'architecture' -Key 'spring_mirror'
    if ($springMirror) { $triggers.Add("Touching deployment mirror path $springMirror") }

    return $triggers.ToArray()
}

function Get-DerivedApprovalZones {
    param([hashtable]$Context)

    $explicitZones = @(Get-ContextArray -Context $Context -Section 'approval' -Key 'zones')
    if ($explicitZones.Count -gt 0) {
        return $explicitZones
    }

    $zones = [System.Collections.Generic.List[string]]::new()

    $deployMethod = Get-ContextString -Context $Context -Section 'deployment_current' -Key 'deploy_method'
    if ($deployMethod) { $zones.Add("Deployment method changes: $deployMethod") }

    $deployTarget = Get-ContextString -Context $Context -Section 'deployment_current' -Key 'deploy_target'
    if ($deployTarget) { $zones.Add("Deploy target changes: $deployTarget") }

    $executionMode = Get-ContextString -Context $Context -Section 'deployment_target' -Key 'final_execution_mode'
    if (-not $executionMode) {
        $executionMode = Get-ContextString -Context $Context -Section 'deployment_goal' -Key 'target_execution_mode'
    }
    if ($executionMode) { $zones.Add("Execution mode changes: $executionMode") }

    $targetPlatform = Get-ContextString -Context $Context -Section 'deployment_goal' -Key 'target_platform'
    if ($targetPlatform) { $zones.Add("Target platform changes: $targetPlatform") }

    $oraclePriority = Get-ContextString -Context $Context -Section 'deployment_goal' -Key 'oracle_cloud_priority'
    if ($oraclePriority) { $zones.Add("Oracle Cloud rollout changes: $oraclePriority") }

    $futurePlan = Get-ContextString -Context $Context -Section 'env_strategy' -Key 'future_plan'
    if ($futurePlan) { $zones.Add("Runtime env ownership changes: $futurePlan") }

    return (Merge-ContextItems $zones.ToArray())
}

function Get-DerivedWorkerMappings {
    param([hashtable]$Context)

    $explicitMappings = @(Get-ContextArray -Context $Context -Section 'workers' -Key 'mapping')
    if ($explicitMappings.Count -gt 0) {
        return $explicitMappings
    }

    $mappings = [System.Collections.Generic.List[string]]::new()

    $shellRuntime = Get-ContextString -Context $Context -Section 'architecture' -Key 'shell_runtime'
    $routeConstants = Get-ContextString -Context $Context -Section 'architecture' -Key 'route_constants'
    if ($shellRuntime) {
        $shellScope = @($shellRuntime)
        if ($routeConstants) { $shellScope += $routeConstants }
        $mappings.Add(('worker_shell_runtime = {0}' -f ($shellScope -join ', ')))
    }

    $sharedReact = Get-ContextString -Context $Context -Section 'architecture' -Key 'shared_react_components'
    $headerComponent = Get-ContextString -Context $Context -Section 'architecture' -Key 'header_component'
    $footerComponent = Get-ContextString -Context $Context -Section 'architecture' -Key 'footer_component'
    if ($sharedReact -or $headerComponent -or $footerComponent) {
        $sharedScope = @()
        if ($sharedReact) { $sharedScope += $sharedReact }
        if ($headerComponent) { $sharedScope += $headerComponent }
        if ($footerComponent) { $sharedScope += $footerComponent }
        $mappings.Add(('worker_shared = {0}' -f ((Merge-ContextItems $sharedScope) -join ', ')))
    }

    $landingScript = Get-ContextString -Context $Context -Section 'architecture' -Key 'landing_script'
    $landingStylesheet = Get-ContextString -Context $Context -Section 'architecture' -Key 'landing_stylesheet'
    $primaryEntry = Get-ContextString -Context $Context -Section 'workspace' -Key 'primary_entry'
    if ($primaryEntry -or $landingScript -or $landingStylesheet) {
        $landingScope = @()
        if ($primaryEntry) { $landingScope += $primaryEntry }
        if ($landingScript) { $landingScope += $landingScript }
        if ($landingStylesheet) { $landingScope += $landingStylesheet }
        $mappings.Add(('worker_feature_landing = {0}' -f ((Merge-ContextItems $landingScope) -join ', ')))
    }

    return (Merge-ContextItems $mappings.ToArray())
}

function Get-DerivedReviewerFocus {
    param([hashtable]$Context)

    $explicitFocus = @(Get-ContextArray -Context $Context -Section 'reviewer' -Key 'focus')
    if ($explicitFocus.Count -gt 0) {
        return $explicitFocus
    }

    return (Merge-ContextItems `
        (Get-ContextArray -Context $Context -Section 'editing_rules' -Key 'notes'))
}

function Get-DerivedForbiddenPatterns {
    param([hashtable]$Context)

    return (Merge-ContextItems `
        (Get-ContextArray -Context $Context -Section 'forbidden' -Key 'patterns') `
        (Get-ContextArray -Context $Context -Section 'content_guidelines' -Key 'avoid'))
}

function Add-MarkdownSection {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Title,
        [string[]]$Items
    )

    $normalizedItems = @($Items | Where-Object { $_ })

    if ($normalizedItems.Count -eq 0) {
        return
    }

    $Lines.Add('')
    $Lines.Add("## $Title")
    $Lines.Add('')
    foreach ($item in $normalizedItems) {
        $Lines.Add("- $item")
    }
}

function New-DefaultWorkspaceAgents {
    param(
        [string]$WorkspaceName,
        [string]$TemplateName
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Workspace Override: $WorkspaceName")
    $lines.Add('')
    $lines.Add('This file adds repository-specific rules on top of the global multi-agent defaults.')
    $lines.Add('Global multi-agent defaults remain in effect unless this file narrows them.')
    $lines.Add('')
    if ($TemplateName -eq 'minimal') {
        $lines.Add('## Minimal Repository Rules')
        $lines.Add('')
        $lines.Add('- Error log path: `ERROR_LOG.md`')
        $lines.Add('- Fill `WORKSPACE_CONTEXT.toml` first if you want project-aware generation instead of generic fallback rules')
        $lines.Add('- Keep changes small')
        $lines.Add('- Add repository-specific verification commands, source-of-truth paths, and do-not-touch paths here')
        $lines.Add('- Keep `STATE.md` updated with `score_total`, `score_breakdown`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget`, `writer_slot`, `contract_freeze`, and `write_sets`')
        $lines.Add('- If multiple roles are used, append real participation to `MULTI_AGENT_LOG.md`')
    }
    else {
        $lines.Add('## Repository Facts To Fill')
        $lines.Add('')
        $lines.Add('- Primary source of truth paths')
        $lines.Add('- Shared asset paths')
        $lines.Add('- Do-not-touch or generated paths')
        $lines.Add('- Error log path: `ERROR_LOG.md`')
        $lines.Add('- Verification commands')
        $lines.Add('- Manual approval zones')
        $lines.Add('- Dynamic agent budget guidance and ownership mapping for `worker`, `worker_shared`, `reviewer`, and `explorer` roles')
        $lines.Add('')
        $lines.Add('## Repository Overrides')
        $lines.Add('')
        $lines.Add('- Fill `WORKSPACE_CONTEXT.toml` first if you want project-aware generation instead of generic fallback rules')
        $lines.Add('- Keep `STATE.md` updated with `score_total`, `score_breakdown`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, `delegation_plan`, `agent_budget`, `writer_slot`, `contract_freeze`, and `write_sets`')
        $lines.Add('- If multiple roles are used, append real participation to `MULTI_AGENT_LOG.md` before reporting that they ran')
        $lines.Add('- Add repository-specific verification commands, hard triggers, approval zones, delegation hints, and worker ownership here')
        $lines.Add('- Let this repository narrow agent-driven routing further only when it truly needs stricter local rules')
    }

    return ($lines -join "`n") + "`n"
}

function New-DefaultState {
    param([string]$WorkspaceName)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# STATE')
    $lines.Add('')
    $lines.Add('## Current Task')
    $lines.Add('')
    $lines.Add(('- task: `Replace with the first concrete task for {0} before execution`' -f $WorkspaceName))
    $lines.Add('- phase: `explore`')
    $lines.Add('- scope: `n/a`')
    $lines.Add('- verification_target: `n/a`')
    $lines.Add('')
    $lines.Add('## Orchestration Profile')
    $lines.Add('')
    $lines.Add('- score_total: `0`')
    $lines.Add('- score_breakdown: `n/a`')
    $lines.Add('- hard_triggers: `n/a`')
    $lines.Add('- selected_rules: `n/a`')
    $lines.Add('- selected_skills: `n/a`')
    $lines.Add('- execution_topology: `single-session`')
    $lines.Add('- delegation_plan: `agent-driven, task-scoped, and override-aware`')
    $lines.Add('- agent_budget: `n/a`')
    $lines.Add('- shared_assets_owner: `n/a`')
    $lines.Add('- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`')
    $lines.Add('')
    $lines.Add('## Writer Slot')
    $lines.Add('')
    $lines.Add('- owner: `main`')
    $lines.Add('- write_set: `n/a`')
    $lines.Add('- write_sets:')
    $lines.Add('  - `main`: `n/a`')
    $lines.Add('  - `worker`: `n/a`')
    $lines.Add('  - `reviewer`: `n/a`')
    $lines.Add('- note: `writer_slot`, `contract_freeze`, and `write_sets` stay in use while agent-driven delegation, skill routing, and dynamic budgets decide how much support is spawned.`')
    $lines.Add('')
    $lines.Add('## Contract Freeze')
    $lines.Add('')
    $lines.Add('- contract_freeze: `n/a`')
    $lines.Add('- note: `Freeze the contract before parallel or multi-write changes and track the frozen scope here.`')
    $lines.Add('')
    $lines.Add('## Seed')
    $lines.Add('')
    $lines.Add('- status: `n/a`')
    $lines.Add('- path: `n/a`')
    $lines.Add('- revision: `n/a`')
    $lines.Add('- note: `Use this section to track the active frozen seed once a spec-first task starts.`')
    $lines.Add('')
    $lines.Add('## Reviewer')
    $lines.Add('')
    $lines.Add('- reviewer: `n/a`')
    $lines.Add('- reviewer_target: `n/a`')
    $lines.Add('- reviewer_focus: `n/a`')
    $lines.Add('')
    $lines.Add('## Last Update')
    $lines.Add('')
    $lines.Add('- timestamp: `[timestamp]`')
    $lines.Add('- note: `Template generated by installer.`')

    return ($lines -join "`n") + "`n"
}

function New-WorkspaceAgentsFromContext {
    param(
        [hashtable]$Context,
        [string]$WorkspaceName,
        [string]$TemplateName,
        [string]$WorkspaceRoot
    )

    $taskBoardPath = Get-ContextString -Context $Context -Section 'workspace' -Key 'task_board_path' -DefaultValue 'STATE.md'
    $multiAgentLogPath = Get-ContextString -Context $Context -Section 'workspace' -Key 'multi_agent_log_path' -DefaultValue 'MULTI_AGENT_LOG.md'
    $errorLogPath = Get-DerivedErrorLogPath -Context $Context
    $title = Get-ContextString -Context $Context -Section 'workspace' -Key 'name' -DefaultValue $WorkspaceName
    $summary = Get-DerivedWorkspaceSummary -Context $Context -WorkspaceName $WorkspaceName

    Resolve-WorkspaceRelativePath -WorkspaceRoot $WorkspaceRoot -RelativePath $taskBoardPath -PathLabel 'task_board_path' | Out-Null
    Resolve-WorkspaceRelativePath -WorkspaceRoot $WorkspaceRoot -RelativePath $errorLogPath -PathLabel 'error_log_path' | Out-Null

    $repositoryFacts = @(Get-DerivedRepositoryFacts -Context $Context)
    $requiredRead = @(Get-DerivedRequiredRead -Context $Context)
    $verificationCommands = @(Get-DerivedVerificationCommands -Context $Context)
    $sharedContracts = @(Get-DerivedSharedContracts -Context $Context)
    $sharedAssetPaths = @(Get-DerivedSharedAssetPaths -Context $Context)
    $doNotTouchPaths = @(Get-DerivedDoNotTouchPaths -Context $Context)
    $hardTriggers = @(Get-DerivedHardTriggers -Context $Context)
    $approvalZones = @(Get-DerivedApprovalZones -Context $Context)
    $workerMappings = @(Get-DerivedWorkerMappings -Context $Context)
    $reviewerFocus = @(Get-DerivedReviewerFocus -Context $Context)
    $forbiddenPatterns = @(Get-DerivedForbiddenPatterns -Context $Context)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Workspace Override: $title")
    $lines.Add('')
    if ($summary) {
        $lines.Add($summary)
        $lines.Add('')
    }
    $lines.Add('This file adds repository-specific rules on top of the global multi-agent defaults.')
    $lines.Add('Global multi-agent defaults remain in effect unless this file narrows them.')

    Add-MarkdownSection -Lines $lines -Title 'Repository Facts' -Items ($repositoryFacts + @(
        ('Task board path: `{0}`' -f $taskBoardPath),
        ('Multi-agent log path: `{0}`' -f $multiAgentLogPath),
        ('Error log path: `{0}`' -f $errorLogPath)
    ))
    Add-MarkdownSection -Lines $lines -Title 'Required Context Before Editing' -Items $requiredRead
    Add-MarkdownSection -Lines $lines -Title 'Verification Commands' -Items $verificationCommands
    Add-MarkdownSection -Lines $lines -Title 'Shared Contracts' -Items $sharedContracts
    Add-MarkdownSection -Lines $lines -Title 'Shared Asset Paths' -Items $sharedAssetPaths
    Add-MarkdownSection -Lines $lines -Title 'Repo-Specific Hard Triggers' -Items $hardTriggers
    Add-MarkdownSection -Lines $lines -Title 'Do-Not-Touch Paths' -Items $doNotTouchPaths
    Add-MarkdownSection -Lines $lines -Title 'Manual Approval Zones' -Items $approvalZones
    Add-MarkdownSection -Lines $lines -Title 'Worker Mapping' -Items $workerMappings

    $lines.Add('')
    $lines.Add('## Repository Overrides')
    $lines.Add('')
    $lines.Add('- Use score-based orchestration to choose the role mix and task-scoped budget instead of fixed caps')
    $lines.Add('  `agent_budget`, `execution_topology`, `selected_rules`, and `selected_skills` decide how much support is spawned')
    $lines.Add(('- Keep `{0}` updated with `score_total`, `score_breakdown`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, `delegation_plan`, `agent_budget`, `writer_slot`, `contract_freeze`, and `write_sets`' -f $taskBoardPath))
    $lines.Add(('- If multiple roles are used, append real participation to `{0}` before reporting that they ran' -f $multiAgentLogPath))
    if ($TemplateName -eq 'minimal') {
        $lines.Add('- Keep changes small')
        $lines.Add('- Let this repository narrow agent-driven routing further only when it truly needs stricter local rules')
    }
    else {
        $lines.Add('- Add repository-specific worker ownership, hard triggers, approval zones, and delegation hints here as they become clear')
        $lines.Add('- Let this repository narrow agent-driven routing further only when it truly needs stricter local rules')
    }

    Add-MarkdownSection -Lines $lines -Title 'Reviewer Focus' -Items $reviewerFocus
    Add-MarkdownSection -Lines $lines -Title 'Forbidden Patterns' -Items $forbiddenPatterns

    return ($lines -join "`r`n") + "`r`n"
}

function New-DefaultErrorLog {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# ERROR LOG')
    $lines.Add('')
    $lines.Add('Append-only log for installer, execution, tool, and verification errors.')
    $lines.Add('Add new entries with timestamp, location, summary, and details.')
    $lines.Add('Do not rewrite existing entries; append only.')

    return ($lines -join "`r`n") + "`r`n"
}

function New-WorkspaceStateFromContext {
    param(
        [hashtable]$Context,
        [string]$WorkspaceName
    )

    $title = Get-ContextString -Context $Context -Section 'workspace' -Key 'name' -DefaultValue $WorkspaceName

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# STATE')
    $lines.Add('')
    $lines.Add('## Current Task')
    $lines.Add('')
    $lines.Add(('- task: `Replace with the first concrete task for {0} before execution`' -f $title))
    $lines.Add('- phase: `explore`')
    $lines.Add('- scope: `n/a`')
    $lines.Add('- verification_target: `n/a`')
    $lines.Add('')
    $lines.Add('## Orchestration Profile')
    $lines.Add('')
    $lines.Add('- score_total: `0`')
    $lines.Add('- score_breakdown: `n/a`')
    $lines.Add('- hard_triggers: `n/a`')
    $lines.Add('- selected_rules: `n/a`')
    $lines.Add('- selected_skills: `n/a`')
    $lines.Add('- execution_topology: `single-session`')
    $lines.Add('- delegation_plan: `agent-driven, task-scoped, and override-aware`')
    $lines.Add('- agent_budget: `n/a`')
    $lines.Add('- shared_assets_owner: `n/a`')
    $lines.Add('- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`')
    $lines.Add('')
    $lines.Add('## Writer Slot')
    $lines.Add('')
    $lines.Add('- owner: `main`')
    $lines.Add('- write_set: `n/a`')
    $lines.Add('- write_sets:')
    $lines.Add('  - `main`: `n/a`')
    $lines.Add('  - `worker`: `n/a`')
    $lines.Add('  - `reviewer`: `n/a`')
    $lines.Add('- note: `writer_slot`, `contract_freeze`, and `write_sets` stay in use while agent-driven delegation, skill routing, and dynamic budgets decide how much support is spawned.`')
    $lines.Add('')
    $lines.Add('## Contract Freeze')
    $lines.Add('')
    $lines.Add('- contract_freeze: `n/a`')
    $lines.Add('- note: `Freeze the contract before parallel or multi-write changes and track the frozen scope here.`')
    $lines.Add('')
    $lines.Add('## Seed')
    $lines.Add('')
    $lines.Add('- status: `n/a`')
    $lines.Add('- path: `n/a`')
    $lines.Add('- revision: `n/a`')
    $lines.Add('- note: `Use this section to track the active frozen seed once a spec-first task starts.`')
    $lines.Add('')
    $lines.Add('## Reviewer')
    $lines.Add('')
    $lines.Add('- reviewer: `n/a`')
    $lines.Add('- reviewer_target: `n/a`')
    $lines.Add('- reviewer_focus: `n/a`')
    $lines.Add('')
    $lines.Add('## Last Update')
    $lines.Add('')
    $lines.Add('- timestamp: `[timestamp]`')
    $lines.Add('- note: `Template generated by installer.`')

    return ($lines -join "`r`n") + "`r`n"
}

function Install-CodexCustomAgents {
    param(
        [string]$SourceKitRoot,
        [string]$BackupRoot
    )

    $sourceAgentsRoot = Join-Path $SourceKitRoot 'codex_agents'
    if (-not (Test-Path -LiteralPath $sourceAgentsRoot -PathType Container)) {
        return
    }

    Ensure-Directory -Path $GlobalCustomAgentsRoot
    Backup-PathIfExists -Path $GlobalCustomAgentsRoot -BackupRoot $BackupRoot -Name 'agents'

    Get-ChildItem -LiteralPath $GlobalCustomAgentsRoot -Filter *.toml -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($ManagedAgentFiles -notcontains $_.Name) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }

    Get-ChildItem -LiteralPath $sourceAgentsRoot -File | ForEach-Object {
        $target = Join-Path $GlobalCustomAgentsRoot $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
}

function Install-CodexSkills {
    param(
        [string]$SourceKitRoot,
        [string]$BackupRoot
    )

    $sourceSkillsRoot = Join-Path $SourceKitRoot 'codex_skills'
    if (-not (Test-Path -LiteralPath $sourceSkillsRoot -PathType Container)) {
        return
    }

    Ensure-Directory -Path $GlobalSkillsRoot
    Backup-PathIfExists -Path $GlobalSkillsRoot -BackupRoot $BackupRoot -Name 'skills'
    Backup-PathIfExists -Path $GlobalManagedSkillsManifest -BackupRoot $BackupRoot -Name 'installer-managed-skills.manifest'

    $previousManagedSkills = @()
    if (Test-Path -LiteralPath $GlobalManagedSkillsManifest) {
        $previousManagedSkills = @(Get-Content -LiteralPath $GlobalManagedSkillsManifest | Where-Object { $_ })
    }

    $currentManagedSkills = @(
        Get-ChildItem -LiteralPath $sourceSkillsRoot -Directory | ForEach-Object { $_.Name }
    )

    foreach ($managedSkillName in $previousManagedSkills) {
        if ($currentManagedSkills -notcontains $managedSkillName) {
            $managedSkillPath = Join-Path $GlobalSkillsRoot $managedSkillName
            if (Test-Path -LiteralPath $managedSkillPath) {
                Remove-Item -LiteralPath $managedSkillPath -Recurse -Force
            }
        }
    }

    Copy-DirectoryContents -Source $sourceSkillsRoot -Destination $GlobalSkillsRoot
    Set-Content -LiteralPath $GlobalManagedSkillsManifest -Value $currentManagedSkills -Encoding utf8
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

function Ensure-ConfigArrayContains {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Key,
        [string[]]$RequiredValues
    )

    $required = @($RequiredValues | Where-Object { $_ })
    if ($required.Count -eq 0) {
        return
    }

    $pattern = "^\s*$([regex]::Escape($Key))\s*=\s*\[(.*)\]\s*$"
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            $currentItems = [System.Collections.Generic.List[string]]::new()
            foreach ($match in [regex]::Matches($Matches[1], '"((?:[^"\\]|\\.)*)"')) {
                $currentItems.Add($match.Groups[1].Value)
            }

            $merged = [System.Collections.Generic.List[string]]::new()
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($item in ($required + $currentItems.ToArray())) {
                if ($item -and $seen.Add($item)) {
                    $merged.Add($item)
                }
            }

            $quoted = ($merged | ForEach-Object { '"{0}"' -f $_ }) -join ', '
            $Lines[$i] = "$Key = [$quoted]"
            return
        }
    }

    $quotedRequired = ($required | ForEach-Object { '"{0}"' -f $_ }) -join ', '
    $insertIndex = 0
    while ($insertIndex -lt $Lines.Count -and $Lines[$insertIndex].StartsWith('#')) {
        $insertIndex += 1
    }
    $Lines.Insert($insertIndex, "$Key = [$quotedRequired]")
}

function Ensure-ConfigSectionKeyValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Section,
        [string]$Key,
        [string]$ValueLiteral
    )

    $sectionHeader = "[$Section]"
    $keyPattern = "^\s*$([regex]::Escape($Key))\s*="

    $sectionIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].Trim() -eq $sectionHeader) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -ge 0) {
        for ($j = $sectionIndex + 1; $j -lt $Lines.Count; $j++) {
            $trimmed = $Lines[$j].Trim()
            if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
                break
            }
            if ($Lines[$j] -match $keyPattern) {
                $Lines[$j] = "$Key = $ValueLiteral"
                return
            }
        }

        $insertIndex = $sectionIndex + 1
        while ($insertIndex -lt $Lines.Count) {
            $trimmed = $Lines[$insertIndex].Trim()
            if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
                break
            }
            $insertIndex += 1
        }
        $Lines.Insert($insertIndex, "$Key = $ValueLiteral")
        return
    }

    if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1] -ne '') {
        $Lines.Add('')
    }
    $Lines.Add($sectionHeader)
    $Lines.Add("$Key = $ValueLiteral")
}

function Get-ConfigDeveloperInstructionsLines {
    return @(
        'Use score-based orchestration and agent-driven skill routing to decide when to delegate work.',
        '',
        'Execution requirements:',
        '- Always load and follow the nearest applicable AGENTS.md before implementation.',
        '- Prefer workspace AGENTS.md over global AGENTS.md when both exist.',
        '- Treat AGENTS.md as the source of truth for orchestration selection, skill routing, state updates, and verification flow.',
        '- On each new user request, compare it against the active current_task in STATE.md before continuing, even if the work looks like a continuation of the same feature.',
        '- Do not continue implementation from an existing STATE.md unless the request is clearly the same task.',
        '- Treat investigation, planning, and implementation as separate stages.',
        '- If read-only investigation or planning turns into implementation, re-check the score and trigger basis, update STATE.md, and explicitly enter implementation before writing.',
        '- Before parallelizing larger tasks, freeze the contract and write sets first.',
        '',
        'Error logging:',
        '- Leave interrupted or paused errors in ERROR_LOG.md as open or deferred until a later append marks them resolved.',
        '',
        'Default behavior:',
        '- Use score-based orchestration to decide whether to stay single-session or delegate work to subagents.',
        '- Do not treat a task as single-session from final output file count alone; re-evaluate when upstream collection, normalization, or read-heavy investigation can be owned separately.',
        '- If the user changes the contract from sample or demo output to real data integration, recalculate `execution_topology` before continuing writes.',
        '- Route skill selection from task intent: use `ouroboros-interview` for ambiguous scope, `ouroboros-seed` for contract freeze, `ouroboros-run` for implementation, and `ouroboros-evaluate` for verification against the frozen seed.',
        '- Delegate proactively for read-heavy, parallelizable, or shared-asset work without waiting for the user to say "spawn" or "parallelize".',
        '- Close finished agents promptly once their output is consumed.',
        '- Prefer spawning reviewers late unless earlier review is explicitly needed by the score and trigger set.',
        '- Prefer `explorer` for read-only investigation, `worker` for bounded implementation after scope is clear, `worker_shared` for shared assets, and `reviewer` for close-out checks.',
        '- Keep the main thread focused on requirements, decisions, synthesis, orchestration selection, and final answers.',
        '- Apply user natural-language overrides first; then compute the task-scoped agent budget and selected skills from the score and trigger set.',
        '',
        'Spawn requirements:',
        '- These spawn settings are mandatory. Do not rely on inherited defaults, implicit role defaults, or absent custom agent files.',
        '- Every explorer-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "medium".',
        '- Every worker-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "medium".',
        '- Every reviewer-style spawn_agent call must explicitly set model = "gpt-5.4-mini" and reasoning_effort = "high".',
        '- Do not use `fork_context` unless exact thread context is required.',
        '- Do not substitute other models or lower reasoning effort unless the user explicitly overrides this in the current conversation.',
        '- If a planned spawn does not match these requirements, correct the parameters before calling spawn_agent.',
        '',
        'Delegation rules:',
        '- Use `score_total`, `hard_triggers`, `selected_rules`, `execution_topology`, and `agent_budget` to decide whether delegation is allowed and how much support to spawn.',
        '- Count intermediate collection and normalization responsibility as part of `write_sets`; do not collapse that upstream work into the final frontend file owner by default.',
        '- Assign exactly one write set to each worker unless the selected rules and budget explicitly require a shared owner for shared assets.',
        '- Select `reviewer` only when the task-scoped rules or budget call for review-required validation.',
        '- Select `worker_shared` when a shared asset owner is required by the current task.',
        '- Do not exceed the computed task budget, even when the repair loop needs another pass.',
        '- Log the selected skills and delegation plan in `STATE.md` before or immediately after the work starts, as the workspace instructions require.',
        '- Do not open browsers or inspect external domains unless AGENTS.md permits it or the user explicitly asks for it.',
        '',
        'Execution bias:',
        '- Assume agent-driven delegation is allowed when the score, triggers, and user overrides justify it.'
    )
}

function Ensure-ConfigTopLevelMultilineValue {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Key,
        [string[]]$ValueLines
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $keyPattern = "^\s*$([regex]::Escape($Key))\s*="
    $skipMultiline = $false

    foreach ($line in $Lines) {
        $trimmed = $line.Trim()

        if (-not $skipMultiline -and $line -match $keyPattern) {
            if ($trimmed.Contains('"""') -and (($trimmed -split '"""').Count -lt 3)) {
                $skipMultiline = $true
            }
            continue
        }

        if ($skipMultiline) {
            if ($trimmed -eq '"""') {
                $skipMultiline = $false
            }
            continue
        }

        $result.Add($line)
    }

    $insertIndex = 0
    while ($insertIndex -lt $result.Count) {
        $trimmed = $result[$insertIndex].Trim()
        if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
            break
        }
        $insertIndex += 1
    }

    $block = [System.Collections.Generic.List[string]]::new()
    $block.Add($Key + ' = """')
    foreach ($valueLine in $ValueLines) {
        $block.Add($valueLine)
    }
    $block.Add('"""')

    if ($insertIndex -gt 0 -and $result[$insertIndex - 1] -ne '') {
        $block.Add('')
    }

    for ($i = $block.Count - 1; $i -ge 0; $i--) {
        $result.Insert($insertIndex, $block[$i])
    }

    $Lines.Clear()
    foreach ($line in $result) {
        $Lines.Add($line)
    }
}

function Remove-LegacyConfigAgentSections {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string[]]$AllowedAgents
    )

    $allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $AllowedAgents) {
        $allowed.Add($name) | Out-Null
    }

    $result = [System.Collections.Generic.List[string]]::new()
    $skip = $false
    foreach ($line in $Lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[agents\.([^\]]+)\]$') {
            $skip = -not $allowed.Contains($Matches[1])
        }
        elseif ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
            $skip = $false
        }

        if (-not $skip) {
            $result.Add($line)
        }
    }

    return $result.ToArray()
}

function Install-CodexConfig {
    param(
        [string]$ConfigPath,
        [string]$BackupRoot
    )

    Backup-PathIfExists -Path $ConfigPath -BackupRoot $BackupRoot -Name 'config.toml'
    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $ConfigPath) {
        foreach ($line in (Get-Content -LiteralPath $ConfigPath)) {
            $lines.Add($line)
        }
    }
    else {
        $lines.Add('# Codex Configuration')
        $lines.Add('')
    }

    $filteredLines = @(Remove-LegacyConfigAgentSections -Lines $lines -AllowedAgents @('default', 'worker', 'explorer', 'reviewer'))
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $filteredLines) {
        $lines.Add([string]$line)
    }
    Ensure-ConfigArrayContains -Lines $lines -Key 'project_doc_fallback_filenames' -RequiredValues @('AGENTS.md')
    Ensure-ConfigTopLevelMultilineValue -Lines $lines -Key 'developer_instructions' -ValueLines (Get-ConfigDeveloperInstructionsLines)
    Ensure-ConfigSectionKeyValue -Lines $lines -Section 'features' -Key 'multi_agent' -ValueLiteral 'true'
    Ensure-ConfigSectionKeyValue -Lines $lines -Section 'agents.default' -Key 'config_file' -ValueLiteral '"./agents/default.toml"'
    Ensure-ConfigSectionKeyValue -Lines $lines -Section 'agents.worker' -Key 'config_file' -ValueLiteral '"./agents/worker.toml"'
    Ensure-ConfigSectionKeyValue -Lines $lines -Section 'agents.explorer' -Key 'config_file' -ValueLiteral '"./agents/explorer.toml"'
    Ensure-ConfigSectionKeyValue -Lines $lines -Section 'agents.reviewer' -Key 'config_file' -ValueLiteral '"./agents/reviewer.toml"'

    Set-Content -LiteralPath $ConfigPath -Value ($lines -join "`n") -Encoding utf8
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
    $backupRoot = Join-Path (Join-Path (Join-Path $GlobalHome 'backups') (Get-BackupStamp)) 'global'
    Backup-PathIfExists -Path $GlobalAgentsPath -BackupRoot $backupRoot -Name 'AGENTS.md'

    $items = @(
        'README.md',
        'CHANGELOG.md',
        'AGENTS.md',
        'WORKSPACE_CONTEXT_TEMPLATE.toml',
        'MULTI_AGENT_GUIDE.md',
        'codex_agents',
        'codex_rules',
        'codex_skills',
        'docs',
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

    if (-not (Should-OverwriteFile -Path $GlobalAgentsPath)) {
        Write-Host 'Skipped global AGENTS.md overwrite' -ForegroundColor Yellow
    }
    else {
        Copy-Item -LiteralPath (Join-Path $LocalKitRoot 'AGENTS.md') -Destination $GlobalAgentsPath -Force
    }
    Install-CodexConfig -ConfigPath $GlobalConfigPath -BackupRoot $backupRoot
    Install-CodexCustomAgents -SourceKitRoot $LocalKitRoot -BackupRoot $backupRoot
    Install-CodexSkills -SourceKitRoot $LocalKitRoot -BackupRoot $backupRoot
    Install-CodexRules -SourceKitRoot $LocalKitRoot

    Write-Host "Installed global defaults at $GlobalAgentsPath" -ForegroundColor Green
    Write-Host "Patched Codex config at $GlobalConfigPath" -ForegroundColor Green
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
    $contextPath = Get-WorkspaceContextPath -WorkspacePath $resolvedWorkspace
    $context = if (Test-Path -LiteralPath $contextPath) { Read-WorkspaceContext -Path $contextPath } else { $null }
    $agentsTarget = Join-Path $resolvedWorkspace 'AGENTS.md'
    $stateRelativePath = if ($context) { Get-ContextString -Context $context -Section 'workspace' -Key 'task_board_path' -DefaultValue 'STATE.md' } else { 'STATE.md' }
    $stateTarget = Resolve-WorkspaceRelativePath -WorkspaceRoot $resolvedWorkspace -RelativePath $stateRelativePath -PathLabel 'task_board_path'
    $errorLogRelativePath = if ($context) { Get-ContextString -Context $context -Section 'workspace' -Key 'error_log_path' -DefaultValue 'ERROR_LOG.md' } else { 'ERROR_LOG.md' }
    $errorLogTarget = Resolve-WorkspaceRelativePath -WorkspaceRoot $resolvedWorkspace -RelativePath $errorLogRelativePath -PathLabel 'error_log_path'
    $backupRoot = Join-Path (Join-Path (Join-Path $resolvedWorkspace '.codex-backups') (Get-BackupStamp)) 'workspace'

    Write-Section -Text 'Applying workspace override'
    Write-Host "Workspace: $resolvedWorkspace"
    Write-Host "Template: $TemplateName"
    Write-Host "Supporting docs: $CopyDocs"
    if ($context) {
        Write-Host "Workspace context: $contextPath"
    }

    Backup-PathIfExists -Path $agentsTarget -BackupRoot $backupRoot -Name 'AGENTS.md'
    Backup-PathIfExists -Path $stateTarget -BackupRoot $backupRoot -Name 'STATE.md'

    if ($context) {
        $agentsContent = New-WorkspaceAgentsFromContext -Context $context -WorkspaceName (Split-Path -Leaf $resolvedWorkspace) -TemplateName $TemplateName -WorkspaceRoot $resolvedWorkspace
        Set-Content -LiteralPath $agentsTarget -Value $agentsContent -Encoding utf8
    }
    else {
        $agentsContent = New-DefaultWorkspaceAgents -WorkspaceName (Split-Path -Leaf $resolvedWorkspace) -TemplateName $TemplateName
        Set-Content -LiteralPath $agentsTarget -Value $agentsContent -Encoding utf8
    }

    Ensure-Directory -Path (Split-Path -Parent $stateTarget)
    if ($context) {
        $stateContent = New-WorkspaceStateFromContext -Context $context -WorkspaceName (Split-Path -Leaf $resolvedWorkspace)
        Set-Content -LiteralPath $stateTarget -Value $stateContent -Encoding utf8
    }
    else {
        $stateContent = New-DefaultState -WorkspaceName (Split-Path -Leaf $resolvedWorkspace)
        Set-Content -LiteralPath $stateTarget -Value $stateContent -Encoding utf8
    }

    Ensure-Directory -Path (Split-Path -Parent $errorLogTarget)
    if (-not (Test-Path -LiteralPath $errorLogTarget)) {
        $errorLogContent = New-DefaultErrorLog
        Set-Content -LiteralPath $errorLogTarget -Value $errorLogContent -Encoding utf8
    }

    if ($CopyDocs) {
        $docsRoot = Join-Path $resolvedWorkspace 'docs\codex-multiagent'
        Ensure-Directory -Path $docsRoot

        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'README.md') -Destination (Join-Path $docsRoot 'README.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'CHANGELOG.md') -Destination (Join-Path $docsRoot 'CHANGELOG.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'MULTI_AGENT_GUIDE.md') -Destination (Join-Path $docsRoot 'MULTI_AGENT_GUIDE.md') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'WORKSPACE_CONTEXT_TEMPLATE.toml') -Destination (Join-Path $docsRoot 'WORKSPACE_CONTEXT_TEMPLATE.toml') -Force
        Copy-Item -LiteralPath (Join-Path $sourceKitRoot 'docs\WORKSPACE_CONTEXT_GUIDE.md') -Destination (Join-Path $docsRoot 'WORKSPACE_CONTEXT_GUIDE.md') -Force
        if (Test-Path -LiteralPath (Join-Path $sourceKitRoot 'codex_agents')) {
            Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'codex_agents') -Destination (Join-Path $docsRoot 'codex_agents')
        }
        if (Test-Path -LiteralPath (Join-Path $sourceKitRoot 'codex_rules')) {
            Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'codex_rules') -Destination (Join-Path $docsRoot 'codex_rules')
        }
        if (Test-Path -LiteralPath (Join-Path $sourceKitRoot 'codex_skills')) {
            Copy-DirectoryContents -Source (Join-Path $sourceKitRoot 'codex_skills') -Destination (Join-Path $docsRoot 'codex_skills')
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
