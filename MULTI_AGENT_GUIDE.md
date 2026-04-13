# Multi-Agent Operating Guide

This document explains why the template is shaped the way it is.

The core idea is simple:
reduce collisions first, then add delegation only when the task actually needs it.

## 1. Why The Default Is `single-session`

- Most confusion comes from splitting too early, not from having too few roles.
- Parallel work gets expensive fast while shared contracts are still moving.
- On small tasks, handoff cost is often larger than implementation cost.
- Single-session execution can look slower while still producing a shorter total lead time.

## 2. Hard Trigger + Scorecard Gate

Use task-size gating before deciding whether `main` should write directly or switch into a delegated profile.

Hard triggers first:

- Shared contract changes
- Shared asset changes
- Multi-layer changes
- Naturally separable write sets
- A contract shift from sample/demo output to real data integration
- Read-heavy collection or normalization that can run independently from downstream rendering
- Contract instability that can change API, schema, props, payload, env keys, or normalized data shape
- High investigation uncertainty where implementation depends on facts not yet discovered
- Data fidelity risk, especially when real-world data, coordinates, metrics, or external sources must be trusted
- External source dependency that must be checked before implementation can be correct
- Implementation depending on discovery results that may change the planned write sets
- Ambiguous acceptance criteria that can change the contract or verification target
- Medium-or-higher regression risk
- A clearly necessary reviewer pass

If any hard trigger exists, classify the task as delegated or mixed.
Hard triggers are gates, not hidden score boosts; record the trigger by name instead of converting it into points.

Do not score only from the final edited file count.
One rendered HTML or frontend file can still hide separate upstream responsibilities such as data collection, coordinate extraction, normalization, or schema confirmation.

If no hard trigger exists, score these at `1` point each:

- `3+` modified files
- `2+` directories
- `2+` new files
- test changes required
- meaningful code reading required before editing
- at least one design decision required before implementation
- `2+` verification steps

Profile selection:

- `single-session`
  - `0-3` points
  - `main` may edit directly in one tight slice
  - use this only when upstream investigation and downstream implementation are not independently ownable
  - allowed only when the contract is stable, no independent discovery slice exists, verification is small, and the reason is more specific than "one final file"
- `delegated-serial`
  - `4-6` points
  - `main` coordinates workers one slice at a time
  - good fit when collection or normalization must finish before rendering, but each slice is still independently verifiable
  - choose this when dependencies exist between slices or the contract must be frozen after discovery
- `delegated-parallel`
  - `7+` points, or any hard trigger when the write sets are separable
  - `main` delegates safe slices to workers
  - good fit when collection, normalization, and rendering can proceed with pinned contracts and separate ownership
  - allowed only when the contract is frozen, write sets are disjoint, shared assets have one owner, `main` will not write during the parallel phase, and slice verification exists
- `mixed`
  - uneven tasks that need both sequential and parallel delegation
  - choose this when one phase must run serially to freeze the contract and later phases can fan out safely

Before any write begins:

- record the exact `orchestration_profile` and concrete `reason` in `STATE.md`
- record `score_total`, `score_breakdown`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, and `agent_budget`
- report to the user which score or trigger basis was read from `STATE.md` and how that changes the startup plan, such as staying local, starting serial delegation, or opening parallel worker lanes
- do not use legacy route labels or hedge labels such as `single-agent fallback`
- on `single-session`, keep one write-capable lane and no subagent calls
- if the user changes the contract mid-task, record whether the old `single-session` reason still holds; if not, reclassify before continuing
- on delegated profiles, `main` delegates implementation to workers and keeps ownership boundaries explicit
- on delegated profiles, a `reviewer` pass is mandatory when `review_required` is selected
- on delegated profiles, if shared assets and feature files are both touched, use `worker_shared` plus at least one feature worker

Decision gate:

- If `delegated-parallel` fails any required condition, downgrade to `delegated-serial` or run discovery first.
- If `single-session` has a vague reason such as "small task" or "one file", stop and replace it with a concrete ownership and verification reason.
- If implementation correctness depends on facts that are not yet known, use explorer-first discovery before implementation.

Start decision tree:

1. Did a hard trigger fire?
2. If yes, does correctness depend on facts not yet known?
3. If yes, start in explorer-first discovery.
4. If no, are the contract and write sets already pinned and disjoint?
5. If yes, choose `delegated-parallel` when `main` can stay read-only during fan-out; otherwise choose `delegated-serial`.
6. If no hard trigger fired, score the task.
7. `0-3` points stays `single-session` only when no independent upstream slice exists.
8. `4-6` points starts `delegated-serial`.
9. `7+` points starts `delegated-parallel` only if the parallel gate passes; otherwise downgrade to `delegated-serial`.
10. If one early phase must freeze the contract and a later phase can fan out, choose `mixed`.

## 3. What Makes A Safe Slice

A safe slice satisfies all four conditions below:

- The goal can be described in one line.
- The changed file range is small and closed.
- The shared contract is already pinned.
- There is a clear way to verify the result.

For upstream work, the "changed file range" may be a produced dataset, normalization note, or other intermediate artifact responsibility rather than only the final UI file.

If any part is blurry, shrink the slice or keep it in `single-session`.

## 3.1 Explorer-First And Re-Orchestration

Use explorer-first discovery when the task mentions real data, external sources, coordinates, schema inference, broad codebase scouting, unstable acceptance criteria, or any implementation that depends on not-yet-known facts.

Discovery mode rules:

- `phase` is `discovery`
- `writer_slot` is `none` unless updating `STATE.md` or `MULTI_AGENT_LOG.md`
- output is findings, proposed contract, write-set recommendation, verification target, and reclassification recommendation
- implementation waits until `main` records the updated contract and execution topology

If a worker or `main` discovers a new hard trigger, contract mismatch, or write-set conflict during execution, stop and mark the task `contract_blocked` or `reclassify_required`.

Record:

- `trigger_found`
- `discovered_by`
- `impact`
- `required_action`

No implementation writes continue until `main` updates `STATE.md`, refreshes `execution_topology`, and records whether the task stays local, moves serial, moves parallel, or becomes mixed.

## 3.2 Verification Gates

Use the selected profile to set the minimum verification gate before close-out:

- `single-session`: code review plus the smallest relevant repository command when available
- `delegated-serial`: verify each slice output, then verify the integrated contract after the final slice
- `delegated-parallel`: verify each worker output, check shared-contract consistency, check write-set ownership, then run final integration verification
- `mixed`: verify the serial contract-freeze phase before fan-out, then apply the parallel gate to the fan-out phase

If no verification target can be named, do not fan out; return to discovery or shrink the slice.

## 4. When To Use Skills

Skill selection is automatic and follows the task state.

- `ouroboros-interview`
  - requirements are unclear or still moving
- `ouroboros-seed`
  - the contract must be frozen before implementation
- `ouroboros-run`
  - the task is ready to enter implementation
- `ouroboros-evaluate`
  - verification against the frozen seed is the active goal

The user can still override the default picker with natural language. That override wins.

## 5. When To Use `explorer`

`explorer` only matters when scouting is cheaper than guessing.

- Files are spread across a wide area.
- Existing contracts need to be confirmed before editing.
- Test scope needs to be narrowed first.
- Discovery cost is higher than implementation cost.

If the file and the edit are obvious, splitting out an explorer is just ceremony.

## 6. When Multiple Agents Are Actually Safe

Parallel work is reasonable only when all of these are true:

- `main` is not writing during the parallel phase
- Shared contracts such as API, schema, or payload are already pinned
- Shared assets have one clear owner
- Verification can also stay separate
- `main` already knows the integration point
- `agent_budget` is large enough to cover the parallel slices

There are no fixed role caps anymore. The task budget decides.

Recommended topology examples:

- `worker_feature_1`
- `worker_feature_2`
- `worker_feature_3`
- `worker_shared`

Good example:

- `main` freezes payload shape, state names, and write sets
- `worker_shared` updates common types and shared helpers
- feature workers edit separate feature directories
- reviewer checks contracts, regressions, and scope ownership at the end

Bad example:

- `worker_feature_1` edits a shared type file
- `worker_feature_2` edits the same shared type file differently
- `main` keeps writing while both workers are active
- This creates contract drift even when the changed feature files are separate

## 7. What Every Handoff Should Include

The more roles you split across, the more the input contract matters.

Recommended handoff format:

```md
Goal
- One-line acceptance criteria

Edit scope
- Files or directories

Pinned contracts
- APIs, schemas, routes, events, or env keys that must not drift

Selection
- `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget`

Verification
- Commands

Done means
- What the reviewer should be able to confirm at the end
```

## 8. Lightweight Task Board Beats A Heavy Queue

For this kit, a full runtime queue is overkill.
But a lightweight task board is worth it.

Use `STATE.md` to track:

- `current_task`
- `next_tasks`
- `blocked_tasks`
- `orchestration_profile`
- `writer_slot`
- `contract_freeze`
- `write_sets`
- `selected_rules`
- `selected_skills`
- `execution_topology`
- `agent_budget`
- `reviewer_target` when a reviewer is assigned

That gives `main` enough structure to sequence work without pretending this repo is a full scheduler.

Default mode is still one shared task board.
Do not introduce concurrent thread-local state just because the task is large.

Use concurrent registry mode only when multiple live threads must work in the same workspace at the same time and the write ownership can actually stay disjoint.

In that mode:

- root `STATE.md` becomes the registry
- record `state_mode = concurrent-registry`
- track `active_threads`
- track `workspace_locks`
- track shared-contract notes that apply across threads
- move each live execution lane into `states/STATE.<thread_id>.md`
- keep the core sections unchanged inside each thread state file

If two live threads need the same file, the same shared asset, or the same contract surface, concurrent mode is the wrong fix.
Serialize the work or move one slice into a separate worktree.

## 9. Why Explicit Profiles And Write Sets Help

Small and large tasks need different visibility.

Recommended values:

- `orchestration_profile = single-session | delegated-serial | delegated-parallel | mixed`
- `reason = hard trigger name | concrete score summary`
- `writer_slot = free | main | worker_name | parallel`
- `write_sets = [worker_name = file globs]`
- `reviewer_target = reviewer | reviewer_name`
- `agent_budget = task-scoped budget`

Before delegated execution starts:

- freeze the contract
- declare write-set ownership
- name the shared-assets owner
- name the reviewer target

After delegated execution ends:

- collapse back to `writer_slot = free`
- keep the handoff evidence in `MULTI_AGENT_LOG.md`

That makes accidental ownership drift much harder to hide.

## 10. Why Contract Freeze Should Be Explicit

The most common multi-agent breakage is contract drift.

- API shapes change
- props change
- schema changes
- env keys change

So `main` should mark `contract_freeze` before handing off the writer slot.

## 11. What `reviewer` Should Actually Look For

`reviewer` is not there to finish the implementation.
It is the last risk filter.

Recommended priority order:

1. Contract violations
2. Regression risk
3. Missing tests or verification
4. Write-set or shared-asset ownership violations
5. Minor style issues

Style comes last.
If the structure is broken, formatting comments are noise.

## 12. What To Do When A Worker Gets Stuck

- Do not respawn the same worker with the same prompt.
- Check whether the problem is an unclear contract or an oversized slice.
- If the contract is unclear, let `main` pin it again.
- If the slice is too large, cut it in half.
- If the slice crosses shared assets, move that part to `worker_shared`.
- If discovery was too thin, add a short `explorer` pass.
- If the budget is exhausted, repair inside the remaining `agent_budget` or reclassify the task.

## 13. What To Customize Per Repository

- Real verification commands
- Generated folders or risky paths that should not be edited
- Shared contract lists
- Manual approval zones such as deploys, migrations, or external writes
- Domain worker names
- Skill-selection overrides for repository-specific workflows
- Whether concurrent registry mode is enabled and where thread state files live
- Where task retrospectives and rule-evolution notes should be appended

## 14. Retrospectives And Rule Evolution

A task board helps you not crash during execution.
A retrospective helps you not repeat the same crash next week.

After non-trivial work, especially anything involving reclassification, collisions, installer surprises, or verification gaps, capture a compact note with:

- task name
- `score_total`
- selected profile
- actual topology used
- what caused drift, collision, or reclassification
- what verification caught or missed
- what rule, template, or installer text should change next

Keep rule-evolution notes append-only.
That gives future AGENTS or installer changes an evidence trail instead of a vague memory.

## 15. Recommended Adoption Order

1. Start with `main`
2. Add hard-trigger + scorecard gating
3. Add `STATE.md` once tasks stop fitting in your head
4. Add automatic skill routing for `ouroboros-*`
5. Add `agent_budget` once delegation starts to spread across multiple slices
6. Add `worker_shared` when common types, shared utils, or common components keep causing collisions
7. When real collisions appear, add repository-specific forbidden patterns
8. Only after real same-workspace collisions appear, add concurrent registry mode
9. Once execution patterns repeat, add compact retrospectives and a rule-evolution log

## 16. One-Line Summary

Multi-agent work is not a free productivity buff.
It is distributed coordination with extra failure modes.

Gate task size first.
Pin contracts early.
Use reviewer as the last firewall.
