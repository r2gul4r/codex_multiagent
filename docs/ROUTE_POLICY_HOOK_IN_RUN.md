# Route Policy Hook In Run

This note defines where the workspace `Route A/B` policy should attach once the external Ouroboros engine reaches `run`.

The key rule is simple:

- Ouroboros still owns workflow progression
- the workspace policy owns execution governance

That means `Route A/B` should not replace `run`.
It should hook into `run` at the point where implementation ownership and write scope become concrete.

## What Problem This Solves

Without a defined hook point, three bad things happen:

- `run` starts writing before route selection exists
- `STATE.md` and actual execution behavior drift apart
- worker / reviewer rules become optional instead of enforced

The hook exists to stop that.

## High-Level Placement

The policy hook belongs inside the transition from:

- "seed accepted"

to:

- "implementation writes begin"

In other words:

- not during `interview`
- not during `seed`
- not after files are already being edited
- exactly at the execution planning gate inside `run`

## Run Phases With Hook Points

### Phase 1. Seed Intake

Input:

- accepted seed
- target workspace
- current app-side request context

Purpose:

- confirm what `run` is about to execute
- gather the implementation slice implied by the seed

At this point, no route decision should be final yet.
The seed alone may still be too abstract.

### Phase 2. Execution Planning

This is the first required hook point.

Purpose:

- translate the seed into the concrete implementation slice
- identify affected directories, shared assets, likely verification steps, and whether work naturally splits

Required output:

- tentative task scope
- affected files or file groups
- expected verification shape
- route scorecard input

This is where the app-side controller or orchestration layer should classify the route.

## Route Selection Gate

This is the real policy gate.

Before any implementation file is written, the controller must:

1. classify `Route A` or `Route B`
2. record the route and reason in `STATE.md`
3. define the writer slot
4. if `Route B`, freeze the contract and write sets
5. if `Route B`, assign at least one worker and one reviewer target

No implementation writes should happen before this gate completes.

## Route A Hook Behavior

If the planning result shows a small, single-lane slice:

- one write-capable lane only
- no subagents
- one tight implementation slice
- minimal verification surface

Then:

- the controller records `Route A`
- `writer_slot: main`
- `run` may continue with a single execution lane

Route A remains valid only while the scope stays small.

If any of these appear during execution:

- shared assets
- two or more directories
- two or more new files
- test changes
- multiple verification steps

Then the run should stop at the next safe checkpoint and reclassify to `Route B` before more writes.

## Route B Hook Behavior

If the planning result shows fan-out, shared ownership, or multiple execution slices:

- `Route B` must be selected before implementation writes
- `main` becomes planner-only
- implementation is delegated
- reviewer is mandatory

Required preconditions:

- `contract_freeze` recorded
- `write_sets` recorded
- `reviewer` named
- at least one worker assigned

If the scope touches both shared assets and feature files:

- assign a dedicated shared-assets worker
- assign at least one feature worker separately

If the work naturally splits into two or more feature slices:

- split them into separate workers instead of one oversized worker lane

## Exact Hook Recommendation

The cleanest hook is:

1. `ouroboros run` starts
2. seed is loaded
3. execution planning expands the seed into a concrete implementation slice
4. route gate runs
5. `STATE.md` is updated
6. only then do implementation writes begin

That is the earliest point where the policy has enough information to make a real route decision, and the latest point before execution becomes unsafe.

## Ownership Split

### What Ouroboros Owns

- seed interpretation
- workflow progression
- run lifecycle
- evaluation lifecycle

### What The Workspace Policy Owns

- route classification
- write ownership
- worker / reviewer requirements
- route-specific execution constraints
- state recording for the workspace

This split matters.
The policy should constrain execution behavior, not fork the workflow engine into a second competing engine.

## App-Side Controller Behavior

When the Codex app triggers `run`, it should treat the call as a two-stage operation:

### Stage A. Pre-write Planning

- inspect seed
- derive likely implementation scope
- classify route
- update `STATE.md`

### Stage B. Execution

- if `Route A`, allow single-lane execution
- if `Route B`, require delegated implementation structure

This means the app-side controller is not just a dumb shell launcher.
It is the place where workspace governance is attached before the external engine writes.

## Minimal First-Version Rule

For the first working version, use this rule:

- every `run` must pass through a route-selection checkpoint before implementation writes

And then:

- `Route A` -> one lane, no subagents
- `Route B` -> contract freeze, write sets, worker, reviewer

That is enough to keep the current workspace rules intact while still letting Ouroboros own the actual workflow.

## Relationship To Other Docs

- request-to-command entry mapping lives in `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- ownership boundary lives in `docs/APP_VS_ENGINE_OWNERSHIP.md`
- shell helper and control loop lives in `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- projection and state sync lives in `docs/PROJECTION_AND_STATE_SYNC.md`
- delivery roadmap lives in `docs/DELIVERY_ROADMAP.md`
- external runtime and layer overview lives in `docs/EXTERNAL_OUROBOROS_PLAN.md`

This document only answers one question:

- where and how `Route A/B` attaches once `run` begins

The next implementation path still runs through shell-helper and projection/state-sync first; wrapper MCP stays later unless the command surface proves it needs richer transport.
