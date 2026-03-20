# Multi-Agent Operating Guide

This document explains why the template is shaped the way it is

The core idea is simple
Reduce collisions first
Only then worry about concurrency

## 1. Why The Default Is `main` Alone

- Most confusion comes from splitting too early, not from having too few roles
- Parallel work gets expensive fast while shared contracts are still moving
- On small tasks, handoff cost is often larger than implementation cost
- Single-agent execution can look slower while still producing a shorter total lead time

## 2. Hard Trigger + Scorecard Gate

Use task-size gating before deciding whether `main` should write directly or switch into planner-only mode

Hard trigger first

- Shared contract changes
- Shared asset changes
- Multi-layer changes
- Naturally separable write sets
- Medium-or-higher regression risk
- A clearly necessary reviewer pass

If any hard trigger exists, treat the task as `Route C`

If no hard trigger exists, score these at `1` point each

- `3+` modified files
- `2+` directories
- `2+` new files
- test changes required
- meaningful code reading required before editing
- at least one design decision required before implementation
- `2+` verification steps

Route selection

- `Route A`
  - `0-1` points
  - `main` may edit directly
- `Route B`
  - `2-3` points
  - `main` may still edit directly, with optional read-only help
- `Route C`
  - `4+` points, or any hard trigger
  - `main` becomes planner-only
  - workers implement and reviewer validates

Before any write begins

- record the exact `route` and concrete `reason` in `STATE.md`
- do not use hedge labels such as `Route C-equivalent` or `single-agent fallback`
- on `Route A`, keep one tight slice and one write-capable lane
- on `Route B`, keep one write-capable lane and read-only support only
- on `Route B`, if a second write-capable lane would help, promote to `Route C`
- on `Route C`, `main` must stop writing implementation files and delegate to at least one `worker`
- on `Route C`, a `reviewer` pass is mandatory before the task is closed
- on `Route C`, if shared assets and feature files are both touched, use `worker_shared` plus at least one feature worker

## 3. What Makes A Safe Slice

A safe slice satisfies all four conditions below

- The goal can be described in one line
- The changed file range is small and closed
- The shared contract is already pinned
- There is a clear way to verify the result

If any part is blurry, shrink the slice or keep it in `main`

## 4. When To Use `explorer`

`explorer` only matters when scouting is cheaper than guessing

- Files are spread across a wide area
- Existing contracts need to be confirmed before editing
- Test scope needs to be narrowed first
- Discovery cost is higher than implementation cost

If the file and the edit are obvious, splitting out an explorer is just ceremony

## 5. When Multiple Agents Are Actually Safe

Parallel work is reasonable only when all of these are true

- `main` is not writing during the parallel phase
- Shared contracts such as API, schema, or payload are already pinned
- Shared assets have one clear owner
- Verification can also stay separate
- `main` already knows the integration point

Hard role caps in this kit

- `explorer` up to `3`
- `reviewer` up to `2`
- code-writing agents up to `4`, but only on `Route C`

Recommended Route C topology

- `worker_feature_1`
- `worker_feature_2`
- `worker_feature_3`
- `worker_shared`

Good example

- `main` freezes payload shape, state names, and write sets
- `worker_shared` updates common types and shared helpers
- feature workers edit separate feature directories
- reviewer checks contracts, regressions, and scope ownership at the end

Bad example

- `worker_feature_1` edits a shared type file
- `worker_feature_2` edits the same shared type file differently
- `main` keeps writing while both workers are active
- This creates contract drift even when the changed feature files are separate

## 6. What Every Handoff Should Include

The more roles you split across, the more the input contract matters

Recommended handoff format

```md
Goal
- One-line acceptance criteria

Edit scope
- Files or directories

Pinned contracts
- APIs, schemas, routes, events, or env keys that must not drift

Verification
- Commands or manual checks

Done means
- What the reviewer should be able to confirm at the end
```

## 7. Lightweight Task Board Beats A Heavy Queue

For this kit, a full runtime queue is overkill
But a lightweight task board is worth it

Use `STATE.md` to track

- `current_task`
- `next_tasks`
- `blocked_tasks`
- `route`
- `writer_slot`
- `contract_freeze`
- `write_sets` when `Route C` is active
- `reviewer_target` when a reviewer is assigned

That gives `main` enough structure to sequence work without pretending this repo is a full scheduler

## 8. Why Explicit Route And Write Sets Help

Small and large tasks need different visibility

Recommended values

- `route = Route A | Route B | Route C`
- `reason = hard trigger name | concrete score summary`
- `writer_slot = free | main | worker_name | parallel`
- `write_sets = [worker_name = file globs]`
- `reviewer_target = reviewer | reviewer_name`

Before Route C starts

- freeze the contract
- declare write-set ownership
- name the shared-assets owner
- name the reviewer target

After Route C ends

- collapse back to `writer_slot = free`
- keep the handoff evidence in `MULTI_AGENT_LOG.md`

That makes accidental ownership drift much harder to hide

## 9. Why Contract Freeze Should Be Explicit

The most common multi-agent breakage is contract drift

- API shapes change
- props change
- schema changes
- env keys change

So `main` should mark `contract_freeze` before handing off the writer slot

## 10. What `reviewer` Should Actually Look For

`reviewer` is not there to finish the implementation
It is the last risk filter

Recommended priority order

1. Contract violations
2. Regression risk
3. Missing tests or verification
4. Write-set or shared-asset ownership violations
5. Minor style issues

Style comes last
If the structure is broken, formatting comments are noise

## 11. What To Do When A Worker Gets Stuck

- Do not respawn the same worker with the same prompt
- Check whether the problem is an unclear contract or an oversized slice
- If the contract is unclear, let `main` pin it again
- If the slice is too large, cut it in half
- If the slice crosses shared assets, move that part to `worker_shared`
- If discovery was too thin, add a short `explorer` pass

## 12. What To Customize Per Repository

- Real verification commands
- Generated folders or risky paths that should not be edited
- Shared contract lists
- Manual approval zones such as deploys, migrations, or external writes
- Domain worker names

## 13. Recommended Adoption Order

1. Start with `main`
2. Add hard-trigger + scorecard gating
3. Add `STATE.md` once tasks stop fitting in your head
4. Add `explorer` only when discovery cost is consistently high
5. Move large work into `Route C` only after contract freeze is reliable
6. Add `worker_shared` when common types, shared utils, or common components keep causing collisions
7. When real collisions appear, add repository-specific forbidden patterns

## 14. One-Line Summary

Multi-agent work is not a free productivity buff
It is distributed coordination with extra failure modes

Gate task size first
Pin contracts early
Use reviewer as the last firewall
