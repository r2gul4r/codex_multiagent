# Codex Multi-Agent Kit

[Korean](./README.md) | English

Codex Multi-Agent Kit adds global defaults, workspace-local overrides, task
state, and verification routines on top of Codex's built-in subagent
capabilities.

The main README is Korean. This file is the separate English version.

Quick Start 쨌 Install Modes 쨌 Workflow 쨌 File Map 쨌 Verification

---

## Quick Start

### Windows PowerShell

Install global defaults.

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression
Install-CodexMultiAgent -Mode InstallGlobal
```

Apply project-local rules to a workspace.

```powershell
$workspace = 'C:\path\to\your\workspace'
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression
Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh \
  | bash -s -- install-global
```

```bash
workspace="/path/to/your/workspace"
curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh \
  | bash -s -- apply-workspace --workspace "$workspace" --include-docs
```

---

## At A Glance

| Area | What The Kit Does |
| :-- | :-- |
| Global rules | Installs `~/.codex/AGENTS.md`, `config.toml`, agents, and command rules |
| Workspace rules | Creates workspace `AGENTS.md`, `STATE.md`, and `ERROR_LOG.md` |
| Task classification | Records score, hard triggers, write sets, and verification targets |
| Execution topology | Defaults to `single-session`; delegates only when the split has value |
| Safety | Preserves user changes and blocks destructive command patterns |
| Verification | Runs markdown, shell, PowerShell, and generated-doc checks through `make check` |

This kit does not replace Codex's agent system. It gives that system a safer
operating contract for real repository work.

---

## Install Modes

| Mode | Target | Result |
| :-- | :-- | :-- |
| `InstallGlobal` / `install-global` | Codex home | Global `AGENTS.md`, `config.toml`, agents, and rules |
| `ApplyWorkspace` / `apply-workspace` | Project root | Workspace `AGENTS.md`, `STATE.md`, and `ERROR_LOG.md` |
| `UpdateGlobal` / `update-global` | Codex home | Refresh global install from the current kit |
| `UpdateWorkspace` / `update-workspace` | Project root | Refresh workspace override from the current template |

Existing files are backed up before replacement.

| Location | Backup Path |
| :-- | :-- |
| Global Codex home | `~/.codex/backups/<timestamp>/global` |
| Workspace | `<workspace>/.codex-backups/<timestamp>/workspace` |

---

## Workspace Flow

| Step | Action | Output |
| :-- | :-- | :-- |
| 1 | Install global defaults | Codex home baseline rules |
| 2 | Write `WORKSPACE_CONTEXT.toml` | Project commands, protected paths, verification targets |
| 3 | Apply workspace override | Project `AGENTS.md` and `STATE.md` |
| 4 | Start a task | Current task, profile, and write sets recorded in `STATE.md` |
| 5 | Verify | Repository checks and review evidence |

When `WORKSPACE_CONTEXT.toml` exists, the installer reads it first and generates
project-aware `AGENTS.md` and initial `STATE.md` files. Without it, built-in
fallback rules are used.

See:

- [WORKSPACE_CONTEXT_TEMPLATE.toml](./WORKSPACE_CONTEXT_TEMPLATE.toml)
- [WORKSPACE_CONTEXT_GUIDE.md](./docs/WORKSPACE_CONTEXT_GUIDE.md)

---

## Workflow

Every non-trivial task follows this flow:

```text
plan -> classify -> freeze -> implement -> verify -> retrospective
```

| Stage | Meaning |
| :-- | :-- |
| `plan` | Compare the request with the active task in `STATE.md` |
| `classify` | Decide score, hard triggers, profile, and agent budget |
| `freeze` | Pin acceptance, non-goals, write sets, and verification |
| `implement` | Edit only inside the frozen write set |
| `verify` | Run repository commands, review, and generated-doc drift checks |
| `retrospective` | Record outcomes and next rule adjustments when useful |

---

## Execution Profiles

| Profile | When To Use |
| :-- | :-- |
| `single-session` | Default. Only `main` writes. |
| `delegated-serial` | Sequential handoff is safer because dependencies exist. |
| `delegated-parallel` | Contract, ownership, and independent verification are all clear. |
| `mixed` | The task needs both serial and parallel phases. |

`score_total` is only a complexity and risk prior. `evaluation_need`,
`orchestration_value`, and `agent_budget` are separate decisions.

---

## State Files

| File | Role | Git Tracking |
| :-- | :-- | :-- |
| `AGENTS.md` | Global or repository execution rules | Tracked |
| `STATE.md` | Active task profile, contract, and write sets | Usually ignored |
| `MULTI_AGENT_LOG.md` | Actual agent participation and handoff log | Usually ignored |
| `ERROR_LOG.md` | Append-only execution, installer, and verification errors | Usually ignored |
| `WORKSPACE_CONTEXT.toml` | Project-specific installer input | Project choice |

---

## File Map

| Path | Description |
| :-- | :-- |
| [AGENTS.md](./AGENTS.md) | Canonical global multi-agent rule set |
| [Makefile](./Makefile) | Lint, smoke test, and generated-doc verification entrypoint |
| [installer/CodexMultiAgent.ps1](./installer/CodexMultiAgent.ps1) | Windows PowerShell installer |
| [installer/CodexMultiAgent.sh](./installer/CodexMultiAgent.sh) | macOS/Linux/WSL installer |
| [installer/Bootstrap.ps1](./installer/Bootstrap.ps1) | Remote PowerShell bootstrap |
| [installer/Bootstrap.sh](./installer/Bootstrap.sh) | Remote shell bootstrap |
| [codex_agents/](./codex_agents) | Codex agent role configs |
| [codex_rules/](./codex_rules) | Command safety rules |
| [profiles/](./profiles) | main, explorer, worker, reviewer role contracts |
| [scripts/](./scripts) | Repo metrics, gap extraction, and quality normalization tools |
| [docs/](./docs) | Operating guides, patch notes, and generated analysis docs |

---

## Verification

Default local verification:

```bash
make check
```

| Target | Checks |
| :-- | :-- |
| `make lint` | markdownlint, bash syntax, shellcheck, PowerShell parse |
| `make test` | installer smoke, quality normalizer, repo metrics, generated docs |
| `make check` | `lint + test` |

Generated docs must match the current repository scan output:

- [docs/FEATURE_GAP_AREAS.md](./docs/FEATURE_GAP_AREAS.md)
- [docs/TEST_GAP_AREAS.md](./docs/TEST_GAP_AREAS.md)
- [docs/REFACTOR_CANDIDATES.md](./docs/REFACTOR_CANDIDATES.md)

---

## Recent Changes

- [2026-04-15 patch notes](./docs/PATCH_NOTES_2026-04-15.md)
- [2026-04-14 patch notes](./docs/PATCH_NOTES_2026-04-14.md)
- [2026-04-13 patch notes](./docs/PATCH_NOTES_2026-04-13.md)
- [CHANGELOG.md](./CHANGELOG.md)

---

## License

This repository follows the license and distribution policy declared in the
repository metadata.
