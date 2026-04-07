# External Ouroboros Plan

This note captures the current plan for keeping Ouroboros as an external WSL runtime while making it controllable from the Codex desktop app.

## Current Status

- WSL2 and Ubuntu are installed and working
- Upstream `Q00/ouroboros` was installed and validated inside WSL
- Codex CLI works in WSL with ChatGPT OAuth login
- `uv run ouroboros init start "build a tiny hello-world cli"` completed successfully on the Codex backend
- External runtime bring-up is done; the remaining work is app-side control and integration design

## Goal

- Keep upstream Ouroboros as intact as possible
- Run Ouroboros as an external engine inside WSL
- Use the Codex desktop app as the top-level control surface
- Keep the current multi-agent rules as an execution-governance layer on top of the Ouroboros core flow

## Layers

### 1. Runtime Layer

- Windows host
- WSL2
- Ubuntu distro
- Codex CLI

Responsibility:

- Provide the actual execution environment for upstream Ouroboros
- Own shell behavior, local CLI auth, filesystem paths, and runtime dependencies

### 2. Ouroboros Core

- `interview`
- `seed`
- `run`
- `evaluate`

Responsibility:

- Own the workflow engine
- Own core progress state such as requirement refinement, seed generation, lineage, and evaluation

### 3. Codex App Control Layer

Initial form:

- shell invocation
- file-based result capture

Later form:

- wrapper MCP
- thinner app-side command surface

Responsibility:

- Let the Codex desktop app call and observe the external Ouroboros engine
- Make the external engine feel close to integrated without rewriting the engine into the app

### 4. Multi-Agent Policy Layer

- `Route A`
- `Route B`
- `writer_slot`
- `write_sets`
- worker / reviewer
- verification / logging / security rules

Responsibility:

- Decide who executes what once Ouroboros enters an implementation-bearing phase
- Stay as execution governance rather than replacing the Ouroboros workflow engine

### 5. Projection Layer

- `STATE.md`
- `MULTI_AGENT_LOG.md`
- later, machine-readable projections if needed

Responsibility:

- Provide human-readable state for the workspace
- Eventually reflect core state rather than competing with it

## Execution Model

The responsibilities are split like this:

- Ouroboros decides how work converges through stages
- The Codex app decides when and how to invoke the external engine
- The multi-agent policy decides who owns which execution slice

In short:

- Ouroboros = workflow engine
- Codex app = control surface
- multi-agent policy = execution governance

## Control Flow

### Phase 1. User Request

The user asks for work in the Codex desktop app.

Examples:

- "Start with an interview"
- "Run this seed"
- "Evaluate the latest result"

### Phase 2. App-Side Decision

The app-side control logic decides which Ouroboros command should run next.

Examples:

- interview needed -> `ouroboros init start`
- seed already exists -> `ouroboros run <seed>`
- review or result check needed -> inspect evaluate outputs, logs, or workflow artifacts

At first, this decision can stay explicit and manual.

### Phase 3. External Runtime Call

The Codex app calls Ouroboros through WSL shell commands.

Example:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros init start 'build a tiny hello-world cli'"
```

Example:

```powershell
wsl bash -lc "cd ~/ouroboros && uv run ouroboros run ~/.ouroboros/seeds/seed_xxx.yaml"
```

### Phase 4. Result Capture

The external engine writes its outputs first.

Examples:

- `~/.ouroboros/data/...`
- `~/.ouroboros/seeds/...`
- workflow outputs
- execution logs

The Codex app then reads those artifacts and chooses the next action.

### Phase 5. Multi-Agent Execution Governance

When Ouroboros enters `run` and real implementation work begins, the multi-agent layer applies the current policy.

Examples:

- small slice -> `Route A`
- fan-out needed -> `Route B`
- `Route B` -> worker / reviewer / write-set split

This keeps Ouroboros as the workflow engine while our kit stays responsible for execution control.

### Phase 6. Projection

The workspace reflects the external results into `STATE.md`, `MULTI_AGENT_LOG.md`, and related notes.

For now this can stay document-first. Later it can become a stricter projection model.

## Why External First

Going straight to a fully embedded app model is risky right now because:

- upstream runtime behavior and Codex app session behavior are not fully aligned yet
- our state files and Ouroboros core state are not unified yet
- direct embedding would make failures harder to isolate

External-first is useful because:

- it proves the upstream runtime really works
- it separates engine problems from app-control problems
- it gives us a stable baseline before adding a wrapper MCP or tighter integration

## Near-Term Integration Path

### Step 1. Keep the External Baseline Stable

- keep the WSL Ouroboros checkout working
- keep Codex CLI OAuth working
- keep validating `interview`, `seed`, and `run`

### Step 2. Standardize Shell/File Control

- define the common WSL commands the app will call
- define which artifacts are read after each call
- define where seeds, state, and logs are expected
- shell-helper execution note: `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- projection/state-sync note: `docs/PROJECTION_AND_STATE_SYNC.md`

### Step 3. Map App Requests to Ouroboros Commands

- write down how user intents map to `interview`, `run`, and `evaluate`
- keep this explicit before trying to automate it
- first concrete mapping note: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`

### Step 4. Define the Policy Hook

- define where `Route A/B` attaches during `run`
- define how worker/reviewer ownership relates to Ouroboros execution slices
- first concrete hook note: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`

### Step 5. Consider a Wrapper MCP

- only after shell/file control is stable
- only after projection/state sync is stable
- this would be a wrapper for Codex app control, not a replacement for Ouroboros internals
- first app-side action surface note: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- wrapper decision note: `docs/WRAPPER_MCP_DECISION.md`

## Immediate Next Steps

1. Refine `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md` as the first shell/file control surface
2. Refine `docs/ROUTE_POLICY_HOOK_IN_RUN.md` as the execution-governance hook spec
3. Refine `docs/APP_VS_ENGINE_OWNERSHIP.md` as the ownership-boundary contract
4. Refine `docs/APP_CONTROL_COMMAND_CONTRACT.md` as the app-facing action contract
5. Refine `docs/SHELL_HELPER_AND_CONTROL_LOOP.md` as the manual shell/file control layer
6. Refine `docs/PROJECTION_AND_STATE_SYNC.md` as the state projection contract
7. Keep `docs/WRAPPER_MCP_DECISION.md` as the later wrapper decision record after shell/helper and projection are stable

## Not Doing Yet

- full in-app embedded UX
- machine-readable state rollout
- event store migration
- full Codex app adapter implementation
- deep code-level fusion of the multi-agent policy into upstream Ouroboros execution

## Summary

The current answer is simple:

- keep Ouroboros as a WSL external engine
- use the Codex desktop app as the controller
- keep the current multi-agent rules as a policy layer above the engine
- harden shell-helper and projection/state-sync first
- consider wrapper MCP only if the shell/file path proves it actually needs a richer transport boundary

That gives us a stable path now without prematurely forcing an embedded app design.
