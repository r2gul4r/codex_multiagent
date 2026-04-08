# MCP Direct Migration

If the Codex app can attach to the Ouroboros MCP directly, the shell-wrapper/control-loop path becomes a transition layer, not the long-term architecture.
Use this note as the short decision record for what stays, what is deferred, and how to move in order.

## Keep

- Keep the app-level action contract from `docs/APP_CONTROL_COMMAND_CONTRACT.md`.
- Keep the request mapping in `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`.
- Keep the route boundary from `docs/ROUTE_POLICY_HOOK_IN_RUN.md`.
- Keep the external/runtime meaning of `start_interview`, `resume_interview`, `inspect_latest_seed`, `run_seed`, `inspect_run_outputs`, `evaluate_result`, and `check_runtime_health`.
- Keep projection of artifacts and state back into `STATE.md` and `MULTI_AGENT_LOG.md`.
- Keep `docs/OUROBOROS_HANDOFF_MODE.md` as the fallback story for cases where direct MCP is unavailable.
- In this Windows workspace, the current Codex app config should use `wsl.exe -d Ubuntu ... uvx --from ouroboros-ai ouroboros mcp serve` as the direct MCP launch path; simplify to a native Windows command only when `uvx` is available natively on Windows.

Handoff mode and direct MCP are related like this:

- direct MCP is the target control path
- handoff mode is the bridge and fallback path
- once direct MCP covers the same actions safely, handoff mode should stop being the primary operator flow

## Remove/Defer

- Defer the shell-wrapper glue in `docs/SHELL_HELPER_AND_CONTROL_LOOP.md` once direct MCP can carry the same actions.
- Defer any transport-only wrapper MCP work described in `docs/WRAPPER_MCP_DECISION.md` unless direct MCP exposes a real gap.
- Remove dependency on raw WSL command construction for normal app control.
- Remove duplicated control-loop logic that only translates app actions into shell strings.
- Defer any extra normalization layer whose only job is to hide shell details from the Codex app.

What should not be removed yet:

- route checks
- writer-slot governance
- projection/state sync
- the fallback handoff note
- any recovery path for auth, runtime, or attachment failure

## Migration Order

1. Wire the Codex app to the direct Ouroboros MCP with the smallest safe action set first.
2. Start with read/inspect actions: `inspect_latest_seed`, `inspect_run_outputs`, and `check_runtime_health`.
3. Add resume/start actions next: `start_interview` and `resume_interview`.
4. Move write-capable execution last: `run_seed`, with route checks still enforced before any write.
5. Verify that artifacts and state still land in the same projection surfaces.
6. Keep the shell-wrapper path only as fallback until direct MCP proves parity for the current workflow.
7. After parity is stable, delete or freeze the shell-wrapper path and keep `docs/OUROBOROS_HANDOFF_MODE.md` only as historical fallback documentation if needed.

Practical rule:

- if direct MCP can do the job safely, use it
- if it cannot, fall back to handoff mode and the shell wrapper until the gap is closed
