# Shell Helper And Control Loop

This note defines the first practical shell/file control layer for the Codex desktop app.

The goal is to drive the external Ouroboros runtime without a wrapper MCP yet, while still keeping the control flow explicit and debuggable.
Per the current roadmap, this is the immediate control layer after the command contract and ownership boundary are in place. Wrapper MCP comes later, if the shell path proves too thin.

## Purpose

The helper layer should:

- translate stable app actions into shell commands
- run those commands in WSL
- capture outputs and artifacts
- decide the next control step from the observed result

It should not:

- invent new workflow semantics
- own the Ouroboros engine
- replace the route hook or ownership split

## Inputs

The helper layer should accept the app-facing actions from:

- `docs/APP_CONTROL_COMMAND_CONTRACT.md`

Typical inputs:

- action name
- action arguments
- target workspace
- optional current interview or seed context

## Core Helper Behavior

The helper should do the same thing every time:

1. build the WSL command string
2. run the command in the external runtime
3. capture stdout, stderr, exit status, and artifact paths
4. classify the result
5. tell the app what to do next

The helper should remain thin.
It is a control adapter, not a second planner.

## Recommended Helper Shape

The helper can be thought of as a single dispatcher with a few stable behaviors:

- normalize the action name
- attach the standard WSL prefix
- run the command
- detect auth/runtime failures early
- read the expected artifact set for the action
- return a stable summary object

That summary object should resemble the app command contract:

- `status`
- `summary`
- `artifacts`
- `next_actions`
- `error_kind` when failed

## Control Loop

For the first version, the Codex app can use this loop:

### 1. Read The User Request

Decide what the user is trying to do.

Examples:

- start a fresh interview
- resume an existing interview
- run a seed
- check runtime health

### 2. Pick The App Action

Select one stable app-facing action.

Examples:

- `start_interview`
- `resume_interview`
- `inspect_latest_seed`
- `run_seed`
- `check_runtime_health`

### 3. Run The Shell Helper

The helper converts the action into the WSL command and executes it.

### 4. Read Artifacts

The helper returns the artifacts that matter for the action.

Examples:

- interview JSON
- seed YAML
- run logs
- changed files
- runtime health output

### 5. Decide The Next Transition

The app decides whether to:

- stop
- resume interview
- run a seed
- inspect outputs
- apply Route A/B policy before more writes

## Suggested Helper Responsibilities By Action

### `start_interview`

Helper should:

- run the interview command
- read the latest interview file
- read the generated seed if present

### `resume_interview`

Helper should:

- run the resume command
- read the updated interview state
- read any new seed artifact

### `inspect_latest_seed`

Helper should:

- find the most recent seed file
- return its path and content

### `run_seed`

Helper should:

- run the external seed execution command
- capture changed files and runtime logs
- report whether the output is ready for Route A/B handling

### `inspect_run_outputs`

Helper should:

- read run outputs and changed files
- summarize the result
- avoid inventing evaluation semantics

### `evaluate_result`

Helper should:

- collect the evaluation command output or evaluation artifacts
- return a verdict summary if available

### `check_runtime_health`

Helper should:

- verify Codex CLI login status
- run a minimal Codex exec probe when needed
- stop early if auth is missing

## Failure Handling

The helper should classify failures before the app guesses.

Recommended failure kinds:

- `runtime_auth_failure`
- `runtime_exec_failure`
- `filesystem_failure`
- `missing_seed`
- `missing_interview`
- `missing_target`
- `missing_artifact`
- `not_logged_in`
- `codex_exec_failure`
- `shell_failure`

If runtime health is broken, the helper should not pretend the problem is inside Ouroboros.

## Relationship To Projection

The helper should read artifacts first, then let the projection layer update:

- `STATE.md`
- `MULTI_AGENT_LOG.md`

That keeps the control loop and the projection loop separate.

## Relationship To Route Policy

If the helper reaches a `run` transition that can write files, the route hook must still fire before more writes happen.

The helper is not allowed to skip:

- route classification
- writer slot assignment
- contract freeze
- worker/reviewer requirements when `Route B` is needed

The helper should therefore stop at the planning boundary and hand control to the workspace policy before the first write-capable action continues.

## What This Replaces For Now

This helper layer replaces scattered raw shell strings in the app-side design.

It does not replace:

- the app control contract
- the ownership boundary
- the run-stage route hook

## Minimum Viable Manual Flow

The smallest useful version is:

1. user asks for work
2. app picks a stable action
3. helper runs the WSL command
4. helper returns artifacts
5. app decides the next step

That is enough to keep the external runtime steerable before any wrapper MCP exists.

## Relationship To Other Docs

- app control contract: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- app request mapping: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- ownership boundary: `docs/APP_VS_ENGINE_OWNERSHIP.md`
- route hook: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- external runtime overview: `docs/EXTERNAL_OUROBOROS_PLAN.md`

## Summary

The shell helper is the thin layer that makes the command contract operational.

It should stay simple:

- run the right WSL command
- read the right artifacts
- classify failure correctly
- hand control back to the app

If that stays stable, a wrapper MCP can be added later without changing the control logic.
That is why wrapper MCP is not the immediate next implementation step. The helper and projection rules need to prove themselves first.
