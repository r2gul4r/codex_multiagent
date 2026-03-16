# AGENTS Template

Copy this file into a target repository as `AGENTS.md`

Only the bracketed items need repository-specific edits

## Operating Goal

- Default to a single `main` agent
- Use multiple agents only when the split is genuinely worth it
- Keep each slice focused on one core problem
- Prioritize `write scope`, shared contracts, and verification scope over role labels

## When Not To Use Multiple Agents

- Question answering
- Simple investigation
- Short single-file edits
- Early design work where the contract is still unstable
- Hotfixes where handoff cost is higher than implementation cost

## Base Roles

- `main`
  Orchestration, contract pinning, result integration, final decisions
- `explorer`
  Read-only scouting
  Finds files, existing contracts, test coverage, and likely impact
- `worker`
  Implementation
- `reviewer`
  Final read-only review

## Role Rules

- `explorer` and `reviewer` are read-only
- Only `worker` roles make write changes
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
- If implementation reveals a contract change, the worker escalates back to `main`
- `reviewer` checks contract integrity before style or formatting

## Parallelization Rules

- Default to `main` alone
- Normal operating count is `1~3`
- Hard cap for concurrent sub-agents is `5`
- Do not run `6` or more at the same time
- `worker 2` is allowed only when the `write scope` is fully separate
- Do not send follow-up status prompts to a running worker or reviewer
- Do not respawn the same interrupted worker with the same approach
- If interruption repeats, `main` should shrink the slice or handle it directly

## Parallelization Checklist

- Can the acceptance criteria be explained in one line
- Do the changed file ranges stay separate
- Are the shared contracts already pinned
- Can verification be split by worker
- Is it clear what the reviewer must confirm at the end

If any answer is unclear, do not parallelize

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
- Default to `main` alone
- `explorer` and `reviewer` are read-only
- Start with one domain worker for implementation
- Parallelize only when `write scope` does not overlap
- Pin shared contracts before workers start
- Hard cap for concurrent sub-agents is `5`
- No follow-up status prompts to running workers or reviewers
- Do not respawn interrupted workers with the same prompt
- Close write slices only after reviewer confirmation
- Verification commands: [replace with repo commands]
```
