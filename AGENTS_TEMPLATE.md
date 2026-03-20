# AGENTS Template

Copy this file into a target repository as `AGENTS.md`

Only the bracketed items need repository-specific edits

## Persona Continuity

- Delegated subagents and any surfaced worker or reviewer summaries must preserve the active workspace persona, language, and tone
- Do not let role changes switch the voice into generic assistant copy

## Operating Goal

- Default to `Route A` with a single `main` agent on small work
- Use a `hard-trigger + scorecard` gate before choosing the execution model
- Let `main` write only on `Route A` and `Route B`
- On `Route C`, keep `main` planner-only
- Use multiple agents only when the split is genuinely worth it
- Keep each slice focused on one core problem
- Prioritize `write scope`, shared contracts, and verification scope over role labels

## When Not To Use Multiple Agents

- Question answering
- Simple investigation
- Short single-file edits
- Early design work where the contract is still unstable
- Hotfixes where handoff cost is higher than implementation cost

## Task Size Gate

- `main` must classify the task before writing
- First check hard triggers
- If no hard trigger exists, calculate the scorecard
- Then choose `Route A`, `Route B`, or `Route C`

## Hard Triggers

- Shared contract changes
  - API payload
  - state names or transitions
  - event names
  - routes
  - env keys
- Shared asset changes
  - common types
  - shared utilities
  - common components
  - import paths or aliases
  - schemas
- Multi-layer changes
  - UI + server
  - UI + tests
  - server + schema
- Naturally separable write sets
- Medium-or-higher regression risk
- A distinct reviewer pass is clearly required

## Scorecard

- Only use the scorecard when no hard trigger exists
- Add `1` point for each item below
- `3+` modified files
- `2+` directories
- `2+` new files
- tests must change
- meaningful codebase reading is required before editing
- at least one design decision must be made before implementation
- verification has `2+` manual or command steps

## Route Model

- `Route A`
  - `0-1` points
  - `main` may edit directly
- `Route B`
  - `2-3` points
  - `main` may still edit directly, but read-only support roles are allowed when useful
- `Route C`
  - `4+` points, or any hard trigger
  - `main` does not edit
  - `main` freezes contracts, declares write sets, and orchestrates workers and reviewer

## Base Roles

- `main`
  Orchestration, contract pinning, result integration, final decisions
  `main` may write only on `Route A` and `Route B`
  On `Route C`, `main` is planner-only
- `explorer`
  Read-only scouting
  Finds files, existing contracts, test coverage, and likely impact
- `worker`
  Implementation
  A worker may be assigned as a feature worker or a shared-assets worker
- `reviewer`
  Final read-only review

## Role Rules

- `explorer` and `reviewer` are read-only
- On `Route C`, only `worker` roles make write changes
- On `Route A/B`, `main` may write directly
- Every slice with write changes must be closed by `reviewer`
- `reviewer` is not a rescue role for large redesigns
- `main` does not ping the same worker again before the result comes back

## Execution Flow

1. `main` pins the acceptance criteria in one line
2. If needed, `explorer` performs a read-only scout
3. One `worker` handles the smallest useful write slice
4. Only add a second worker if the `write scope` is fully separate
5. `reviewer` checks regressions, contract violations, and missing verification
6. `main` integrates the result and closes the task

## Shared Contract Rules

- Shared contracts such as APIs, payloads, schemas, routes, event names, and env keys must be pinned before workers start
- `main` owns contract freeze before the writer slot is handed off
- If implementation reveals a contract change, the worker escalates back to `main`
- `reviewer` checks contract integrity before style or formatting

## Task Board

For multi-step work, keep a lightweight `STATE.md`

- `current_task`
- `next_tasks`
- `blocked_tasks`
- `route`
- `writer_slot`
- `contract_freeze`
- `write_sets` when `Route C` is active

## Coordination Log

If more than one role is used, keep an append-only `MULTI_AGENT_LOG.md`

- Add one entry per role action or handoff
- Use the log as the source of truth when reporting which roles ran
- If no log entry exists for a claimed role, do not present that role as having participated

## Parallelization Rules

- Default to `Route A` or `Route B` in `main`
- Maximum concurrent `explorer` agents is `3`
- Maximum concurrent `reviewer` agents is `2`
- Maximum concurrent code-writing agents is `4`, but only on `Route C`
- `main` may not write while `Route C` workers are active
- Feature workers must have fully separate write sets
- One designated shared-assets worker owns common types, shared utilities, common components, import-path changes, and other shared assets
- Feature workers do not edit shared assets
- Record `writer_slot` for `Route A/B` and add `write_sets` for `Route C`
- Parallel work is limited to combinations with explicit write-set ownership
- Do not send follow-up status prompts to a running worker or reviewer
- Do not respawn the same interrupted worker with the same approach
- If interruption repeats, `main` should shrink the slice or handle it directly

## Parallelization Checklist

- Can the acceptance criteria be explained in one line
- Is `current_task` clearly pinned in `STATE.md`
- Do the changed file ranges stay separate
- Are the shared contracts already pinned
- Is `contract_freeze` marked before the writer slot is used
- Can verification stay valid while keeping only one write-capable lane
- Is it clear what the reviewer must confirm at the end

If any answer is unclear, do not parallelize

## Forbidden Commands

- Never run `git reset --hard` unless the user explicitly requests it
- Never run `git checkout -- <path>` or `git restore --source=<tree> -- <path>` to discard changes unless the user explicitly requests it
- Never run `git clean -fd` or `git clean -fdx` unless the user explicitly requests it
- Never use destructive delete commands such as `rm -rf`, `del /s /q`, or `Remove-Item -Recurse -Force` against repository files or user data just to "start fresh"
- Never revert, overwrite, or wipe user changes in a dirty worktree unless the user explicitly requests it

## Example Domain Workers

These names are examples
Rename them to fit the repository

- `[ui_worker]`
  UI, layout, forms, panels
- `[backend_worker]`
  API, auth, session, queue, webhook
- `[data_worker]`
  Schema, ingestion, ETL, provider contract
- `[ops_worker]`
  CI, deployment scripts, infrastructure config
- `default`
  Fallback when no specific domain matches

## Repository-Specific Fields To Fill

- Verification commands
  Example: `[pnpm lint]`, `[pnpm test]`, `[pnpm build]`
- Shared contract list
  Example: `[OpenAPI schema, event names, DB migration rules]`
- Do-not-touch or high-risk paths
  Example: `[generated/, dist/, vendor/]`
- Manual approval zones
  Example: `[deploy, migrations, writes to external systems]`

## Forbidden Patterns

- Splitting mechanically by org-chart labels such as frontend, backend, and UX
- Automatic fan-out based on task count alone
- Launching new agents without first integrating completed results
- Sending repeated status-check prompts to running workers
- Expecting `reviewer` to implement fixes

## Minimal Copy-Paste Rules

```md
- Default to `Route A` in `main`
- Use a hard-trigger + scorecard gate before scaling up
- `explorer` and `reviewer` are read-only
- `main` may write on `Route A/B`, but stays planner-only on `Route C`
- Max concurrent role caps: `explorer 3`, `reviewer 2`, `worker 4 on Route C`
- Keep `STATE.md` updated with `current_task`, `route`, `writer_slot`, and `contract_freeze`
- Add `write_sets` when `Route C` is active
- Feature workers need separate write sets
- Shared assets need one owner
- Pin shared contracts before workers start
- No follow-up status prompts to running workers or reviewers
- Do not respawn interrupted workers with the same prompt
- Close write slices only after reviewer confirmation
- Verification commands: [replace with repo commands]
```
