# PowerShell Paste Install

Open Windows PowerShell as Administrator

Then paste one of the blocks below

Replace the path in `$kitRoot` with the real path to this repository

## Interactive Menu

```powershell
$kitRoot = "\\wsl$\Ubuntu\home\lefelx\code\jejugroup\codex_multiagent"
& "$kitRoot\installer\CodexMultiAgent.ps1"
```

This opens the built-in menu

- `1` Install or update the global kit
- `2` Apply the kit to one workspace
- `3` Install globally and then apply to one workspace

## Global Install Only

```powershell
$kitRoot = "\\wsl$\Ubuntu\home\lefelx\code\jejugroup\codex_multiagent"
& "$kitRoot\installer\CodexMultiAgent.ps1" -Mode InstallGlobal
```

## Workspace Apply Only

```powershell
$kitRoot = "\\wsl$\Ubuntu\home\lefelx\code\jejugroup\codex_multiagent"
$workspace = "C:\path\to\your\workspace"
& "$kitRoot\installer\CodexMultiAgent.ps1" -Mode ApplyWorkspace -TargetWorkspace $workspace -Template standard -IncludeDocs
```

## Global Install And Workspace Apply

```powershell
$kitRoot = "\\wsl$\Ubuntu\home\lefelx\code\jejugroup\codex_multiagent"
$workspace = "C:\path\to\your\workspace"
& "$kitRoot\installer\CodexMultiAgent.ps1" -Mode InstallAndApply -TargetWorkspace $workspace -Template standard -IncludeDocs
```
