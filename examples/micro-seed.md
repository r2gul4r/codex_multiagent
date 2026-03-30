# Micro Seed Template

Use this template when the team wants the Ouroboros-lite workflow without the full original runtime payload.

The goal is simple:

- freeze intent before implementation
- make `ooo run` consume a stable contract
- make `ooo evaluate` judge against the same contract

## Rules

- Keep it short.
- Make every acceptance criterion testable.
- Write only what later implementation and evaluation actually need.
- If scope changes materially, create a new revision instead of silently mutating the old seed.
- For workspace overrides that run concurrent threads, keep root `STATE.md` entries compact and move per-thread detail into `state/TASK-*.md`.
- Fresh workspace overrides can include a starter task-state template in `state/` if the installer generates one.

## Template

Copy this template into `SEED.yaml`; that file is the actual workflow contract for the workflow.

```yaml
goal: "<primary objective>"

constraints:
  - "<hard limit or invariant>"

acceptance_criteria:
  - "<observable success condition>"

verification:
  - "<command, check, or review condition>"

out_of_scope:
  - "<explicit non-goal>"
```

## Example

```yaml
goal: "Add Ouroboros-lite workflow support to the repository without introducing background orchestration or MCP-only dependencies."

constraints:
  - "Keep the existing Route A/Route B system as the top-level orchestration layer."
  - "Route A is main-only with no subagent calls."
  - "Route B is the delegated route with worker/reviewer use."
  - "Workspace overrides may use a root STATE board plus task-state files for concurrent threads."
  - "Use active_tasks, blocked_tasks, owned_write_sets, and task_state_dir as the root-board vocabulary."
  - "Do not require Codex CLI-only features."
  - "Do not introduce polling-based workflow steps."

acceptance_criteria:
  - "`ooo interview`, `ooo seed`, `ooo run`, and `ooo evaluate` each have repository-packaged skill definitions."
  - "Implementation entry uses the existing Route A/Route B rules."
  - "Evaluation explicitly checks compliance against the frozen seed."

verification:
  - "Review the generated skill files for alignment with the seed contract."
  - "Run `git diff --check` after edits."

out_of_scope:
  - "Full Ouroboros MCP server integration."
  - "Lineage/evolution automation."
  - "Background job monitoring or polling."
```
