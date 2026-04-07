# App Control Command Contract

This note defines the first app-facing command contract for controlling the external Ouroboros runtime in WSL.

The purpose is not to implement a wrapper yet.
The purpose is to freeze the action surface that the Codex desktop app should think in.

That same surface can later be backed by:

- direct shell calls
- a helper script
- a wrapper MCP

## Design Goal

The app should not think in raw shell strings first.
It should think in stable control actions.

For the first version, each action needs:

- action name
- required inputs
- WSL command shape
- primary outputs
- failure meaning
- next-step expectation

## Global Assumptions

- upstream Ouroboros checkout lives at `~/ouroboros`
- runtime data lives at `~/.ouroboros`
- Codex CLI in WSL is already logged in
- app-side control still uses shell/file behavior underneath

## Standard Runtime Prefix

Unless noted otherwise, each action resolves to this form:

```powershell
wsl bash -lc "cd ~/ouroboros && <command>"
```

## Contract Shape

Each action should be thought of as returning:

- `status`
- `summary`
- `artifacts`
- `next_actions`
- `error_kind` when failed

This is a conceptual contract for now, not a wire format.

## Actions

### `start_interview`

Purpose:

- begin a new clarification flow from a rough goal

Required inputs:

- `goal`

Optional inputs:

- `cwd_context`

WSL command:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros init start '<goal>'"
```

Primary outputs:

- latest interview file under `~/.ouroboros/data/`
- latest seed file under `~/.ouroboros/seeds/` if generated

Success meaning:

- interview session was created or completed
- a seed may now exist

Failure kinds:

- `runtime_auth_failure`
- `runtime_exec_failure`
- `interview_generation_failure`
- `user_interrupted`

Expected next actions:

- `inspect_latest_seed`
- `resume_interview`
- `run_seed`

### `resume_interview`

Purpose:

- continue a previously created interview

Required inputs:

- `interview_id`

WSL command:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros init start --resume <interview_id>"
```

Primary outputs:

- updated `~/.ouroboros/data/interview_<id>.json`
- possibly a new seed file

Success meaning:

- interview resumed and progress was saved

Failure kinds:

- `missing_interview`
- `runtime_auth_failure`
- `runtime_exec_failure`
- `user_interrupted`

Expected next actions:

- `inspect_latest_seed`
- `run_seed`
- `resume_interview`

### `inspect_latest_seed`

Purpose:

- read the most recent seed before deciding to run it

Required inputs:

- none

WSL command shape:

```powershell
wsl bash -lc "latest=$(ls -t ~/.ouroboros/seeds | head -n 1) && cat ~/.ouroboros/seeds/$latest"
```

Primary outputs:

- latest seed path
- latest seed contents

Success meaning:

- the app now has a concrete seed to show or approve

Failure kinds:

- `missing_seed`
- `filesystem_failure`

Expected next actions:

- `run_seed`
- `resume_interview`

### `run_seed`

Purpose:

- start implementation-bearing workflow execution from a chosen seed

Required inputs:

- `seed_path`

Optional inputs:

- `target_workspace`

WSL command:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros run <seed_path>"
```

Primary outputs:

- runtime stdout/stderr
- changed workspace files
- generated run artifacts
- evaluation or verification artifacts if produced

Success meaning:

- the run reached a meaningful execution checkpoint or completed

Failure kinds:

- `missing_seed`
- `runtime_auth_failure`
- `runtime_exec_failure`
- `run_failure`

Expected next actions:

- `inspect_run_outputs`
- `evaluate_result`
- `check_runtime_health`

### `inspect_run_outputs`

Purpose:

- read the immediate outputs after `run`

Required inputs:

- `target_workspace` or known artifact locations

WSL command shape:

- no single fixed command
- this action is a read phase over:
  - run stdout/stderr
  - changed files
  - generated evaluation artifacts
  - runtime logs

Primary outputs:

- summarized run result
- changed-file list
- failure or success indicators

Success meaning:

- the app has enough information to decide whether the result should be accepted, reviewed, retried, or re-routed

Failure kinds:

- `missing_artifact`
- `filesystem_failure`

Expected next actions:

- `evaluate_result`
- `run_seed`
- workspace policy application

### `evaluate_result`

Purpose:

- assess whether the latest result should be accepted or looped back

Required inputs:

- `target` or latest known run context

WSL command:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros evaluate <target>"
```

If upstream does not expose a stable evaluate command in the current flow:

- this action temporarily maps to reading evaluation artifacts and run outputs instead

Primary outputs:

- evaluation verdict
- uncertainty or failure signals
- artifacts backing the verdict

Success meaning:

- the app can now accept, retry, or return to clarification

Failure kinds:

- `missing_target`
- `runtime_exec_failure`
- `missing_evaluation_surface`

Expected next actions:

- `run_seed`
- `resume_interview`
- stop and summarize

### `list_runtime_artifacts`

Purpose:

- discover interviews, seeds, and useful runtime files

Required inputs:

- none

WSL command shape:

```powershell
wsl bash -lc "ls ~/.ouroboros/data && ls ~/.ouroboros/seeds"
```

Primary outputs:

- interview listing
- seed listing

Success meaning:

- the app can offer concrete resume or run options

Failure kinds:

- `filesystem_failure`
- `missing_runtime_data`

Expected next actions:

- `resume_interview`
- `inspect_latest_seed`
- `run_seed`

### `check_runtime_health`

Purpose:

- separate Codex CLI auth/runtime failures from Ouroboros workflow failures

Required inputs:

- none

WSL command shape:

```powershell
wsl bash -lc "cd ~/ouroboros && codex login status"
```

Optional deeper probe:

```powershell
wsl bash -lc "cd ~/ouroboros && codex exec --skip-git-repo-check -C ~/ouroboros 'Reply with exactly OK.'"
```

Primary outputs:

- login status
- direct Codex exec behavior

Success meaning:

- the app knows whether the runtime base is healthy

Failure kinds:

- `not_logged_in`
- `codex_exec_failure`
- `shell_failure`

Expected next actions:

- re-authenticate Codex CLI
- retry the original Ouroboros action
- stop and report runtime failure

## Error Kinds

Use these categories consistently:

- `runtime_auth_failure`
- `runtime_exec_failure`
- `filesystem_failure`
- `missing_seed`
- `missing_interview`
- `missing_target`
- `missing_artifact`
- `missing_evaluation_surface`
- `interview_generation_failure`
- `run_failure`
- `user_interrupted`
- `shell_failure`
- `not_logged_in`
- `codex_exec_failure`

These do not need to be final forever, but they should stay stable enough that later wrappers keep the same semantics.

## First-Version Controller Rules

1. Prefer action names over raw shell commands in design discussions
2. Resolve each action to a WSL command only at the control layer
3. Read artifacts immediately after each action rather than guessing state
4. Before blaming Ouroboros, use `check_runtime_health`
5. Before implementation writes continue, route policy must still gate `run`

## Relationship To Other Docs

- request mapping: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- run-stage route hook: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- ownership boundary: `docs/APP_VS_ENGINE_OWNERSHIP.md`
- shell helper and control loop: `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- projection and state sync: `docs/PROJECTION_AND_STATE_SYNC.md`
- delivery roadmap: `docs/DELIVERY_ROADMAP.md`
- wrapper MCP decision: `docs/WRAPPER_MCP_DECISION.md`
- full external-runtime overview: `docs/EXTERNAL_OUROBOROS_PLAN.md`

This document answers one question:

- what app-facing control actions should exist before we build a wrapper or MCP layer

The next implementation path is still shell-helper + projection/state-sync first.
Wrapper MCP remains optional until the control flow proves it actually needs a richer transport boundary.
