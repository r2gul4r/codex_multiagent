# Wrapper MCP Decision

This note records the current decision about whether the shell-helper layer should stay as-is or be upgraded to a wrapper MCP.

## Current Decision

Keep shell/file control as the near-term default.

Do not build a wrapper MCP yet.

The current roadmap keeps wrapper MCP behind projection/state sync and shell-helper stabilization, so it is not the next implementation step.

The shell-helper layer is enough for the current external-first phase because:

- the control contract is already stable enough to run manually
- the app-side flow is still being clarified
- the external runtime is already working through WSL shell calls
- wrapper MCP would add transport complexity before the command contract is fully proven in daily use

## Why Not Wrapper Yet

A wrapper MCP should only come after the shell helper proves that:

- the command contract is stable
- the app-side request mapping is stable
- projection/state sync is stable
- Route A/B gating is stable

Without that, the wrapper would just mirror an unstable control flow.
That would add transport without adding certainty.

## When A Wrapper MCP Makes Sense

Move to a wrapper MCP only if at least one of these becomes true:

- the shell helper starts accumulating too much glue logic
- the app needs a stronger tool boundary than raw shell/file calls
- the action contract needs a transport that is easier to expose consistently to the Codex app
- the app-side control flow becomes repetitive enough that a tool-shaped interface clearly improves clarity

## What The Wrapper Would Add

If we do build it later, the wrapper MCP should only add transport and normalization.

It should not add workflow ownership.

That means the wrapper may expose tools like:

- `start_interview`
- `resume_interview`
- `inspect_latest_seed`
- `run_seed`
- `inspect_run_outputs`
- `evaluate_result`
- `list_runtime_artifacts`
- `check_runtime_health`

But it should still stay thin and defer to:

- Ouroboros for workflow semantics
- workspace policy for route and write governance
- the Codex app for user-facing control

## Decision Criteria

Before approving a wrapper MCP, check:

1. Does the shell helper still feel simple enough to maintain?
2. Does the command contract still map cleanly to the app request model?
3. Do projection rules stay one-way and explicit?
4. Do Route A/B decisions still remain outside the wrapper?
5. Is there a real transport problem, or just a preference for more abstraction?

If the answer to those questions is mostly yes, stay with shell/file control.

## Current Recommendation

For now:

- keep shell/file control
- keep the command contract
- keep the projection rules
- keep the wrapper MCP optional

Immediate next implementation step:

- continue hardening the shell helper and projection/state-sync rules, not the wrapper MCP itself

That is the safest choice while the external Ouroboros workflow is still being wrapped into the Codex desktop app's control surface.

## Relationship To Other Docs

- command contract: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- shell helper: `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- roadmap: `docs/DELIVERY_ROADMAP.md`
- app ownership: `docs/APP_VS_ENGINE_OWNERSHIP.md`

## Summary

The current answer is no wrapper MCP yet.

Use shell/file control first, and only promote to a wrapper when the control flow proves it actually needs a richer transport boundary.
