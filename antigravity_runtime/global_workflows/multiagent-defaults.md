---
description: Global multi-agent defaults installed by the Codex Multi-Agent Kit for Antigravity.
---

# Multi-Agent Defaults

## Operational Mandate
Use this multi-agent structure as the default execution model across Antigravity workspaces.

If the current repository has an `AGENTS.md`, treat it as the repository-specific override.

Do not invent extra built-in agents, review bots, test bots, or browser subagents unless they are explicitly defined in the current workspace or in installed runtime files.

## Base Roles
- `main`
  Orchestration, contract pinning, result integration, and final decisions
- `explorer`
  Read-only scouting for files, contracts, tests, and likely impact
- `worker`
  Implementation
- `reviewer`
  Final read-only review for regressions, contract drift, and missing verification

## Role Rules
- `explorer` and `reviewer` are read-only
- Only `worker` roles make write changes
- Close every write slice with a reviewer pass
- `reviewer` is not a rescue role for large redesigns
- `main` does not ping the same worker again before the result comes back

## Execution Flow
1. `main` pins the acceptance criteria in one line
2. If needed, `explorer` performs a read-only scout
3. One `worker` handles the smallest useful write slice
4. Add a second worker only when `write scope` is fully separate
5. `reviewer` checks regressions, contract violations, and missing verification
6. `main` integrates the result and closes the task

## Parallelization Rules
- Default to `main` alone
- Normal operating count is `1~3`
- Hard cap for concurrent sub-agents is `5`
- Do not run `6` or more at the same time
- A second worker is allowed only when `write scope` is fully separate
- If the split is unclear, do not parallelize

## Installed Role Reporting
When a user asks which multi-agent roles are installed, report only:

- `main`
- `explorer`
- `worker`
- `reviewer`
- repository-specific worker names explicitly declared in the current `AGENTS.md`
