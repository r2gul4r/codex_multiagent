# App Vs Engine Ownership

This note defines who owns what between:

- the Codex desktop app
- the external Ouroboros runtime in WSL
- the workspace multi-agent policy layer

This split is needed so later wrapper or MCP work does not turn into a blurry mess.

## Core Principle

Use this rule everywhere:

- Codex app = control surface
- Ouroboros = workflow engine
- workspace policy = execution governance

If two layers try to own the same concern, the design is wrong.

## Why This Boundary Matters

Without a hard ownership split, these failures show up fast:

- the app tries to become a second workflow engine
- Ouroboros starts competing with `STATE.md` and route governance
- worker / reviewer rules become half-app, half-engine, and impossible to enforce cleanly

The goal is not just clarity.
The goal is to keep each layer debuggable.

## What The Codex App Owns

The Codex desktop app should own:

- user interaction
- request intake
- top-level command selection
- shell or wrapper calls into WSL
- reading returned artifacts
- deciding the next user-visible transition
- workspace-facing state projection such as `STATE.md`

In practice, the app answers questions like:

- what did the user just ask for
- should we start `interview`, `run`, or inspect results
- which artifact do we read next
- what should the user see or choose next

The app should not own:

- seed semantics
- workflow phase semantics
- evaluation semantics
- core execution lineage

Those belong to Ouroboros.

## What Ouroboros Owns

The external Ouroboros runtime should own:

- `interview`
- `seed`
- `run`
- `evaluate`
- workflow progression
- seed interpretation
- evaluation and workflow outputs
- its own runtime data under `~/.ouroboros`

In practice, Ouroboros answers questions like:

- how requirements are clarified
- how a seed is generated
- how a run proceeds
- what the evaluation result is

Ouroboros should not own:

- Codex desktop UX
- workspace-specific route policy
- our `STATE.md` contract
- our worker / reviewer enforcement rules

Those belong outside the engine.

## What The Workspace Policy Owns

The workspace policy layer should own:

- `Route A / Route B`
- `writer_slot`
- `write_sets`
- worker / reviewer obligations
- execution gating before writes
- workspace logging and state discipline

In practice, the workspace policy answers questions like:

- who is allowed to write
- whether fan-out is required
- whether the task is still safe as Route A
- whether a reviewer is mandatory

The policy layer should not own:

- requirement clarification
- seed generation
- overall workflow progression

Those belong to Ouroboros.

## Ownership By Stage

### Interview Stage

Primary owner:

- Ouroboros

Supporting owner:

- Codex app

Meaning:

- Ouroboros runs the interview
- the app decides when to start or resume it, and what to show after it ends

The workspace policy is mostly passive here.

### Seed Stage

Primary owner:

- Ouroboros

Supporting owner:

- Codex app

Meaning:

- Ouroboros generates and stores the seed
- the app chooses whether to inspect it, accept it, or continue clarification

The workspace policy is still mostly passive here.

### Run Planning Stage

Primary owners:

- Ouroboros
- workspace policy

Meaning:

- Ouroboros expands the seed into executable work
- the workspace policy classifies `Route A/B` before writes begin

This is the boundary-heavy stage.
It is where the app controller must coordinate both sides.

### Run Execution Stage

Primary owners:

- Ouroboros
- workspace policy

Meaning:

- Ouroboros owns the actual run lifecycle
- the workspace policy owns who may write and how execution lanes are structured

The app remains supervisory, not execution-semantic.

### Evaluate Stage

Primary owner:

- Ouroboros

Supporting owner:

- Codex app

Meaning:

- Ouroboros owns evaluation mechanics
- the app reads the outcome and decides whether to show, summarize, retry, or loop back

## What Must Not Be Shared Ownership

The following should each have one clear owner.

### Workflow Stages

Owner:

- Ouroboros

Do not duplicate stage ownership in the app.

### Route Classification

Owner:

- workspace policy

Do not let Ouroboros and the app both invent route decisions independently.

### User-Facing Next Step Choice

Owner:

- Codex app

Do not force Ouroboros to become the app's conversation manager.

### Workspace State Projection

Owner:

- Codex app and workspace policy together

But this is still projection, not workflow truth.

## Recommended Boundary Contract

For the first version, use this contract:

### Codex App Inputs To Ouroboros

- chosen command
- target seed or interview id
- target workspace context

### Ouroboros Outputs Back To The App

- interview artifacts
- seed artifacts
- run outputs
- evaluation outputs
- runtime errors

### Workspace Policy Inputs

- planned implementation scope
- affected files or directories
- verification expectations

### Workspace Policy Outputs

- route
- writer slot
- contract freeze when needed
- write sets
- worker / reviewer requirements

## Controller Rule

The app-side controller should think like this:

1. choose which Ouroboros stage to call
2. call the external engine
3. inspect outputs
4. if entering implementation, apply workspace policy
5. reflect the result back into workspace state and user-facing flow

That keeps the controller thin but still responsible.

## Anti-Patterns

Avoid these:

- making the app duplicate `interview -> seed -> run -> evaluate`
- making Ouroboros generate workspace route policy by itself
- letting `STATE.md` become a second source of workflow truth
- mixing user-facing next-step UX into the external runtime

## Relationship To Other Docs

- app request mapping: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- Route A/B run hook: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- app control action contract: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- shell helper and control loop: `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- projection and state sync: `docs/PROJECTION_AND_STATE_SYNC.md`
- delivery roadmap: `docs/DELIVERY_ROADMAP.md`
- wrapper MCP decision: `docs/WRAPPER_MCP_DECISION.md`
- full external-runtime overview: `docs/EXTERNAL_OUROBOROS_PLAN.md`

This document answers one question only:

- who owns what in the combined design

The next implementation path is still shell-helper + projection/state-sync first.
Wrapper MCP stays later and only becomes attractive if the shell/file path proves too noisy or too repetitive.
