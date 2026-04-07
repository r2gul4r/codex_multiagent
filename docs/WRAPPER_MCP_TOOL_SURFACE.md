# Wrapper MCP Tool Surface

This note defines the candidate MCP tool surface for a future wrapper around the external Ouroboros runtime.

The wrapper is optional.
It must not duplicate Ouroboros workflow semantics.
It should only expose stable app-facing control actions in a tool-shaped form.

## Scope

The wrapper may expose tools for:

- starting or resuming interviews
- inspecting seeds and runtime artifacts
- running a seed
- checking runtime health
- reading execution outputs

The wrapper must not become a second workflow engine.

## Design Rules

1. Keep the wrapper external-first.
2. Keep the tool list stable and app-facing.
3. Map each tool to one existing control action.
4. Do not invent new workflow semantics inside the wrapper.
5. Keep Route A/B policy outside the wrapper.

## Candidate Tools

### `ouroboros.start_interview`

Purpose:

- start a new clarification flow from a rough goal

Required inputs:

- `goal`

Optional inputs:

- `cwd_context`

Outputs:

- `interview_id`
- `interview_state_path`
- optional `seed_path`
- `summary`

Error semantics:

- `runtime_auth_failure`
- `runtime_exec_failure`
- `interview_generation_failure`
- `user_interrupted`

### `ouroboros.resume_interview`

Purpose:

- continue an existing interview session

Required inputs:

- `interview_id`

Outputs:

- `interview_id`
- `interview_state_path`
- optional `seed_path`
- `summary`

Error semantics:

- `missing_interview`
- `runtime_auth_failure`
- `runtime_exec_failure`
- `user_interrupted`

### `ouroboros.inspect_latest_seed`

Purpose:

- read the newest seed artifact before deciding to run it

Required inputs:

- none

Outputs:

- `seed_path`
- `seed_contents`
- `summary`

Error semantics:

- `missing_seed`
- `filesystem_failure`

### `ouroboros.run_seed`

Purpose:

- start implementation-bearing workflow execution from a chosen seed

Required inputs:

- `seed_path`

Optional inputs:

- `target_workspace`

Outputs:

- `run_summary`
- `artifact_paths`
- `changed_files`
- `logs`

Error semantics:

- `missing_seed`
- `runtime_auth_failure`
- `runtime_exec_failure`
- `run_failure`

### `ouroboros.inspect_run_outputs`

Purpose:

- collect the immediate outputs after a run

Required inputs:

- `target_workspace` or known artifact paths

Outputs:

- `output_summary`
- `changed_files`
- `log_paths`
- `evaluation_artifacts`

Error semantics:

- `missing_artifact`
- `filesystem_failure`

### `ouroboros.evaluate_result`

Purpose:

- assess whether the latest result should be accepted, retried, or looped back

Required inputs:

- `target` or latest run context

Outputs:

- `verdict`
- `uncertainty`
- `artifact_paths`
- `summary`

Error semantics:

- `missing_target`
- `runtime_exec_failure`
- `missing_evaluation_surface`

### `ouroboros.list_runtime_artifacts`

Purpose:

- list available interviews, seeds, or other useful runtime artifacts

Required inputs:

- none

Outputs:

- `interviews`
- `seeds`
- `summary`

Error semantics:

- `filesystem_failure`
- `missing_runtime_data`

### `ouroboros.check_runtime_health`

Purpose:

- separate Codex CLI auth/runtime problems from Ouroboros workflow problems

Required inputs:

- none

Outputs:

- `login_status`
- `exec_status`
- `summary`

Error semantics:

- `not_logged_in`
- `codex_exec_failure`
- `shell_failure`

## Output Shape Guidance

The wrapper should normalize all tool responses into a small, stable shape.

Recommended common fields:

- `status`
- `summary`
- `artifacts`
- `next_actions`
- `error_kind` when failed

The wrapper can add tool-specific fields, but these should remain optional.

## What Stays Outside The Wrapper

The wrapper must not own:

- `interview -> seed -> run -> evaluate` semantics
- Route A/B classification
- `writer_slot`
- `write_sets`
- worker / reviewer assignment
- `STATE.md` as workflow truth
- app-side UX decisions

Those belong to:

- Ouroboros core
- workspace policy
- Codex app control flow

## Relationship To Existing Control Contract

The wrapper should mirror, not redefine, the app-facing command contract in:

- `docs/APP_CONTROL_COMMAND_CONTRACT.md`

It should also remain consistent with:

- `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- `docs/APP_VS_ENGINE_OWNERSHIP.md`
- `docs/ROUTE_POLICY_HOOK_IN_RUN.md`

## Minimum Viable Wrapper

If a wrapper is built later, the first usable version should probably expose only:

- `start_interview`
- `resume_interview`
- `run_seed`
- `check_runtime_health`

The more read-only inspection tools can follow once the command contract is stable.

## Summary

The wrapper MCP should be a thin transport layer for the stable app-facing actions.
It should not become another workflow engine and should not absorb route or ownership policy.
