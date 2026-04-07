# Delivery Roadmap

This roadmap sequences the remaining external-Ouroboros planning work after the current documentation package.

## Starting Point

The following are already in place:

- external Ouroboros runs in WSL with Codex CLI OAuth
- app request mapping exists
- Route A/B run hook exists
- app vs engine ownership exists
- app-facing command contract exists

The remaining work is documentation and control-surface design, not runtime implementation.

## Execution Order

### 1. Projection And State Sync Rules

Purpose:

- define how `STATE.md`, `MULTI_AGENT_LOG.md`, and any future structured state should reflect external runtime results
- prevent projection from becoming a second source of truth

Depends on:

- `docs/APP_VS_ENGINE_OWNERSHIP.md`
- `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`

Recommended validation:

- every projected field has one authoritative source
- route and write ownership always come from the workspace policy layer
- runtime artifacts can be reconstructed from the external engine outputs

Exit criteria:

- projection rules are explicit for interview, seed, run, and evaluate transitions
- `STATE.md` is clearly documented as projection, not workflow truth
- sync direction is one-way by default unless a later note says otherwise

### 2. Shell Helper And Control Loop

Purpose:

- define the minimal shell helper behavior that can drive the app-side control flow without a wrapper MCP
- document the first practical loop for request -> command -> artifact -> next action

Depends on:

- `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- `docs/APP_VS_ENGINE_OWNERSHIP.md`

Recommended validation:

- each action in the contract has a concrete shell helper shape
- runtime health checks happen before blaming the workflow engine
- the loop is explicit enough to run manually before automation

Exit criteria:

- shell/file control is fully described for the first practical app-side flow
- wrapper MCP remains optional, not required
- the app can be controlled using stable named actions instead of ad hoc shell strings

### 3. Wrapper MCP Tool Surface

Purpose:

- turn the app-facing command contract into a stable MCP-shaped tool list
- define tool names, required inputs, outputs, and failure kinds

Depends on:

- `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- `docs/APP_VS_ENGINE_OWNERSHIP.md`
- the previous two slices being stable

Recommended validation:

- every tool maps back to one existing app-facing action
- no tool invents a new workflow semantic
- each tool has a clear success/failure path

Exit criteria:

- tool list is complete
- tool inputs and outputs are stable enough for a later wrapper implementation
- no overlap exists between app ownership and engine ownership

### 4. Wrapper Decision Note

Purpose:

- decide whether the shell-helper layer is enough or whether a wrapper MCP should be the next step

Depends on:

- the previous three slices being stable

Recommended validation:

- compare control complexity against the need for MCP portability
- check whether the command contract already feels stable enough for direct wrapping

Exit criteria:

- one clear recommendation exists: keep shell/file only, or move to wrapper MCP
- the recommendation is based on control complexity, not implementation enthusiasm

## Quality Gates Between Slices

Before each next slice starts:

1. the previous slice is reviewed
2. the next dependency is satisfied
3. the new scope does not introduce a new workflow owner
4. the contract stays external-first

If any slice starts to blur engine ownership, pause and reclassify before writing more.

## Final Readiness Gate

This planning package is ready to hand off to implementation only when all of the following are true:

- projection rules are one-way and explicit
- shell helper flow is stable enough to run manually
- command contract and wrapper tool surface agree
- wrapper MCP decision is recorded
- no document still leaves app ownership, engine ownership, or policy ownership ambiguous

## Result

When this roadmap is complete, the project should have:

- a stable app-side control vocabulary
- a stable route hook
- a stable ownership split
- a clear next move on wrapper MCP

That is the point where implementation work can begin without guessing at the contract.
