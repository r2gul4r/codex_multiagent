[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$Json,
    [string]$StatePath,
    [switch]$PrettyJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($StatePath)) {
    $StatePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'STATE.md'
}

function Read-InputJson {
    param(
        [string]$PathValue,
        [string]$JsonValue
    )

    if (-not [string]::IsNullOrWhiteSpace($JsonValue)) {
        return $JsonValue
    }

    if (-not [string]::IsNullOrWhiteSpace($PathValue)) {
        return Get-Content -LiteralPath $PathValue -Raw
    }

    if (-not [Console]::IsInputRedirected) {
        throw 'Provide -Json, -InputPath, or pipe JSON through stdin.'
    }

    return [Console]::In.ReadToEnd()
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

function Normalize-ContractValue {
    param(
        $Value,
        [string]$Key
    )

    $listKeys = @('changed_files', 'next_actions', 'interviews', 'seeds')

    if ($listKeys -contains $Key) {
        if ($null -eq $Value) {
            return @()
        }

        if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
            return @($Value)
        }

        return @($Value)
    }

    if ($Value -is [hashtable]) {
        $table = @{}
        foreach ($nestedKey in $Value.Keys) {
            $table[$nestedKey] = Normalize-ContractValue -Value $Value[$nestedKey] -Key $nestedKey
        }
        return $table
    }

    if ($Value -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = Normalize-ContractValue -Value $property.Value -Key $property.Name
        }
        return $table
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(Normalize-ContractValue -Value $item -Key $null)
        }
        return $items
    }

    return $Value
}

function Convert-JsonTextToHashtable {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'Projection input JSON is empty.'
    }

    $value = $Text | ConvertFrom-Json
    return Normalize-ContractValue -Value (ConvertTo-Hashtable -Value $value)
}

function Get-StringValue {
    param(
        [hashtable]$Table,
        [string]$Key
    )

    if ($null -eq $Table -or -not $Table.ContainsKey($Key)) {
        return $null
    }

    $value = $Table[$Key]
    if ($null -eq $value) {
        return $null
    }

    return [string]$value
}

function Get-ArrayValue {
    param(
        [hashtable]$Table,
        [string]$Key
    )

    if ($null -eq $Table -or -not $Table.ContainsKey($Key)) {
        return @()
    }

    $value = $Table[$Key]
    if ($null -eq $value) {
        return @()
    }

    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
        return @($value)
    }

    return @($value)
}

function Get-NestedValue {
    param(
        [hashtable]$Table,
        [string[]]$Path
    )

    $current = $Table
    foreach ($part in $Path) {
        if ($null -eq $current -or -not ($current -is [hashtable]) -or -not $current.ContainsKey($part)) {
            return $null
        }

        $current = $current[$part]
    }

    return $current
}

function Get-ProjectionString {
    param(
        [object[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        if ($null -eq $candidate) {
            continue
        }

        if ($candidate -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                return $candidate
            }
            continue
        }

        if ($candidate -is [System.Collections.IDictionary]) {
            continue
        }

        if ($candidate -is [System.Collections.IEnumerable] -and -not ($candidate -is [string])) {
            continue
        }

        $text = [string]$candidate
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text
        }
    }

    return $null
}

function Format-ProjectionValue {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [hashtable]) {
        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value)
    }

    return [string]$Value
}

function Get-ProjectionFields {
    param([hashtable]$Result)

    $artifacts = @{}
    $runtimeArtifacts = Get-NestedValue -Table $Result -Path @('artifacts')
    if ($runtimeArtifacts -is [hashtable]) {
        $artifacts = $runtimeArtifacts
    }

    $projection = [ordered]@{}
    $projection.last_action = Get-StringValue -Table $Result -Key 'action'
    $projection.action_status = Get-StringValue -Table $Result -Key 'status'

    $nextActions = Get-ArrayValue -Table $Result -Key 'next_actions'
    if ($nextActions.Count -gt 0) {
        $projection.next_actions = @($nextActions)
    }

    $runtimeTrace = $null
    if ($artifacts.ContainsKey('runtime_trace') -and $artifacts.runtime_trace -is [hashtable]) {
        $runtimeTrace = $artifacts.runtime_trace
    }

    $runtimeSnapshotAfter = $null
    if ($artifacts.ContainsKey('runtime_snapshot_after') -and $artifacts.runtime_snapshot_after -is [hashtable]) {
        $runtimeSnapshotAfter = $artifacts.runtime_snapshot_after
    }

    $runtimeSnapshotBefore = $null
    if ($artifacts.ContainsKey('runtime_snapshot_before') -and $artifacts.runtime_snapshot_before -is [hashtable]) {
        $runtimeSnapshotBefore = $artifacts.runtime_snapshot_before
    }

    foreach ($candidate in @('session_id', 'execution_id', 'interview_id')) {
        foreach ($source in @($runtimeTrace, $runtimeSnapshotAfter, $runtimeSnapshotBefore)) {
            if ($null -eq $source -or -not $source.ContainsKey($candidate)) {
                continue
            }

            $value = Get-ProjectionString -Candidates @($source[$candidate])
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $projection[$candidate] = $value
                break
            }
        }
    }

    $latestInterviewPath = Get-ProjectionString -Candidates @(
        Get-StringValue -Table $artifacts -Key 'interview_path'
        Get-StringValue -Table $artifacts -Key 'latest_interview_path'
        Get-StringValue -Table $runtimeTrace -Key 'interview_path'
        Get-StringValue -Table $runtimeTrace -Key 'latest_interview_path'
        Get-StringValue -Table $runtimeSnapshotAfter -Key 'interview_path'
        Get-StringValue -Table $runtimeSnapshotAfter -Key 'latest_interview_path'
        Get-StringValue -Table $runtimeSnapshotBefore -Key 'interview_path'
        Get-StringValue -Table $runtimeSnapshotBefore -Key 'latest_interview_path'
    )
    if (-not [string]::IsNullOrWhiteSpace($latestInterviewPath)) {
        $projection.latest_interview_path = $latestInterviewPath
    }

    $latestSeedPath = Get-ProjectionString -Candidates @(
        Get-StringValue -Table $artifacts -Key 'latest_seed_path'
        Get-StringValue -Table $artifacts -Key 'seed_path'
        Get-NestedValue -Table $artifacts -Path @('latest_seed', 'seed_path')
        Get-StringValue -Table $runtimeTrace -Key 'seed_path'
        Get-StringValue -Table $runtimeTrace -Key 'latest_seed_path'
        Get-StringValue -Table $runtimeSnapshotAfter -Key 'latest_seed_path'
        Get-StringValue -Table $runtimeSnapshotBefore -Key 'latest_seed_path'
    )
    if (-not [string]::IsNullOrWhiteSpace($latestSeedPath)) {
        $projection.latest_seed_path = $latestSeedPath
    }

    $syncedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $projection.last_synced_at = $syncedAt

    return $projection
}

function Get-SectionStartIndex {
    param(
        [string[]]$Lines,
        [string]$Heading
    )

    for ($index = 0; $index -lt $Lines.Length; $index++) {
        if ($Lines[$index].Trim() -eq $Heading) {
            return $index
        }
    }

    return -1
}

function Remove-ExistingRuntimeProjection {
    param([string[]]$Lines)

    $startIndex = Get-SectionStartIndex -Lines $Lines -Heading '# Runtime Projection'
    if ($startIndex -lt 0) {
        return $Lines
    }

    $endIndex = $Lines.Length
    for ($index = $startIndex + 1; $index -lt $Lines.Length; $index++) {
        if ($Lines[$index] -match '^#\s+') {
            $endIndex = $index
            break
        }
    }

    $prefix = @()
    if ($startIndex -gt 0) {
        $prefix = $Lines[0..($startIndex - 1)]
    }

    $suffix = @()
    if ($endIndex -lt $Lines.Length) {
        $suffix = $Lines[$endIndex..($Lines.Length - 1)]
    }

    return @($prefix + $suffix)
}

function Format-ProjectionSection {
    param([hashtable]$Projection)

    $lines = @('# Runtime Projection')
    foreach ($key in $Projection.Keys) {
        $value = $Projection[$key]
        if ($null -eq $value) {
            continue
        }

        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $lines += "- ${key}:"
            foreach ($item in @($value)) {
                $lines += "  - $item"
            }
            continue
        }

        if ($value -is [hashtable]) {
            $lines += "- ${key}:"
            foreach ($nestedKey in $value.Keys) {
                $nestedValue = $value[$nestedKey]
                if ($null -ne $nestedValue -and $nestedValue -ne '') {
                    $lines += "  - ${nestedKey}: $nestedValue"
                }
            }
            continue
        }

        $lines += "- ${key}: $value"
    }

    return $lines
}

function Update-StateProjection {
    param(
        [string]$StateText,
        [hashtable]$Projection
    )

    $normalized = $StateText -replace "`r`n", "`n"
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($normalized)) {
        $lines = $normalized -split "`n"
    }

    $lines = Remove-ExistingRuntimeProjection -Lines $lines
    $sectionLines = Format-ProjectionSection -Projection $Projection

    if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[-1])) {
        $lines += ''
    }

    $lines += $sectionLines
    return ($lines -join "`r`n") + "`r`n"
}

try {
    $rawJson = Read-InputJson -PathValue $InputPath -JsonValue $Json
    $result = Convert-JsonTextToHashtable -Text $rawJson
    $projection = Get-ProjectionFields -Result $result

    $stateText = Get-Content -LiteralPath $StatePath -Raw
    $updated = Update-StateProjection -StateText $stateText -Projection $projection
    Set-Content -LiteralPath $StatePath -Value $updated -NoNewline

    $output = [ordered]@{
        status       = 'ok'
        state_path   = (Resolve-Path -LiteralPath $StatePath).Path
        projection   = $projection
    }

    if ($PrettyJson) {
        $output | ConvertTo-Json -Depth 8
    }
    else {
        $output | ConvertTo-Json -Depth 8 -Compress
    }
}
catch {
    $failure = [ordered]@{
        status  = 'error'
        summary = $_.Exception.Message
    }

    if ($PrettyJson) {
        $failure | ConvertTo-Json -Depth 8
    }
    else {
        $failure | ConvertTo-Json -Depth 8 -Compress
    }

    exit 1
}
