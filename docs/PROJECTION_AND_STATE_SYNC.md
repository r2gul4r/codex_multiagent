# Projection And State Sync

This note defines how state should flow between the external Ouroboros runtime and the workspace projection files.

The main rule is simple:

- the external runtime owns workflow truth
- the workspace owns projection and governance

That keeps `STATE.md` useful without letting it become a second engine.

## Authoritative Sources

Use these as the source of truth for each stage:

### Interview

- authoritative source: `~/.ouroboros/data/interview_<id>.json`
- supporting artifacts: interview stdout/stderr, saved interview logs

### Seed

- authoritative source: `~/.ouroboros/seeds/<seed>.yaml` or the latest seed artifact created by Ouroboros
- supporting artifacts: seed generation output, interview result that produced it

### Run

- authoritative source: the external Ouroboros run output plus any generated workspace files and run logs
- supporting artifacts: changed files, stdout/stderr, runtime logs, evaluation artifacts if emitted

### Evaluate

- authoritative source: the external evaluation output and any attached artifacts from the run
- supporting artifacts: evaluation logs, command output, verification artifacts

## What `STATE.md` Should Reflect

`STATE.md` is a projection, not workflow truth.

It should reflect only the current control picture:

- current task
- route
- writer slot
- contract freeze
- reviewer
- last update
- the current high-level blocker or next action

It may also note:

- the latest known interview or seed path
- the latest route decision
- the latest control-surface decision

It should not try to store the full workflow history or replace the runtime artifacts.

## What `MULTI_AGENT_LOG.md` Should Reflect

`MULTI_AGENT_LOG.md` is append-only history for the workspace policy layer.

It should record:

- route decisions
- contract freezes
- worker assignments
- reviewer passes
- slice boundaries
- notable verification outcomes
- transitions between slices or phases

It should not rewrite old entries to pretend the history never changed.

It should also not become the live state source for the current task.

## One-Way Versus Two-Way Sync

### Default Rule

Sync should be one-way by default:

- external runtime writes artifacts
- workspace projection reads those artifacts
- the app-side controller updates `STATE.md` and `MULTI_AGENT_LOG.md`

### What Is Allowed Back

Only control decisions may go back into the external runtime, and only as explicit commands.

Examples:

- start interview
- resume interview
- run seed
- check runtime health

That is not projection sync.
That is command control.

### What Is Not Allowed

Do not let workspace projection mutate the runtime as if it were authoritative state.

In particular, do not:

- edit seed files to "fix" the runtime truth
- use `STATE.md` as a writable source of workflow semantics
- let `MULTI_AGENT_LOG.md` determine route state by itself

## Never Treat These As Workflow Truth

The following must never be treated as the source of workflow truth:

- `STATE.md`
- `MULTI_AGENT_LOG.md`
- command transcripts
- ad hoc notes in docs
- the app-side UI state

Those can inform decisions, but they are still projections or observers.

## Route A/B And External Outputs

Route state interacts with runtime outputs in a specific order.

### Route Decision Timing

The route should be set before implementation writes begin.

The order is:

1. seed is accepted
2. run planning expands scope
3. route classification happens
4. `STATE.md` is updated
5. implementation writes begin

That matches the existing `run` hook design.

### Route A

If the external runtime output suggests a small, single-lane slice:

- record `Route A`
- keep `writer_slot: main`
- allow a single write lane
- keep `STATE.md` minimal and current

If later output shows shared assets, multiple directories, new tests, or multiple verification steps:

- pause at the next safe checkpoint
- reclassify to `Route B`
- update `STATE.md` before more writes

### Route B

If the runtime output suggests fan-out or shared ownership:

- record `Route B`
- freeze the contract
- record write sets
- name the reviewer
- ensure worker assignments are reflected in the log

Route B state should be reflected in both:

- `STATE.md` for the current control picture
- `MULTI_AGENT_LOG.md` for the historical record

### Reclassification Rule

If runtime outputs change the scope after route selection, the projection must follow the new reality.

Do not keep a stale Route A entry just because the run already started.

If the actual work now requires fan-out, reclassify to Route B before more writes.

## App Side Sync Behavior

The app-side controller should treat projection updates as a follow-up to command execution, not as a substitute for it.

That means:

- run the external command first
- read the runtime artifacts second
- update `STATE.md` and `MULTI_AGENT_LOG.md` third

Do not pre-fill projection state before the external runtime has produced a result.

If the runtime output is ambiguous, keep the projection conservative and note the ambiguity instead of guessing.

## Sync Rules By Stage

### After Interview

Read:

- interview JSON

Project:

- interview id
- current high-level task
- whether a seed is ready

### After Seed

Read:

- latest seed YAML

Project:

- seed path
- route candidates if the seed already implies implementation
- next action

### After Run Planning

Read:

- seed
- run scope
- affected files
- expected verification shape

Project:

- route
- writer slot
- contract freeze if needed
- write sets if needed

### After Run Execution

Read:

- runtime output
- changed files
- logs
- verification artifacts

Project:

- current status
- whether the route still holds
- whether a new slice is needed

### After Evaluate

Read:

- evaluation verdict
- supporting artifacts

Project:

- accept
- retry
- resume interview
- stop and summarize

## Recommended Projection Discipline

Use these habits:

1. Projection should summarize, not invent
2. Projection should lag behind runtime truth only briefly
3. Projection should be regenerated or corrected from artifacts, not guessed
4. Any route decision in the projection should point back to a concrete runtime reason

## Relationship To Other Docs

- ownership boundary: `docs/APP_VS_ENGINE_OWNERSHIP.md`
- run-stage route hook: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- app control contract: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- request mapping: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`

## Summary

The clean split is:

- external artifacts = workflow truth
- `STATE.md` = current control projection
- `MULTI_AGENT_LOG.md` = append-only policy history

That keeps the workspace honest while still letting the Codex app steer the external Ouroboros runtime cleanly.
