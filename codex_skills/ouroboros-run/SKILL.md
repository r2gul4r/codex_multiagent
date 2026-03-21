---
name: ouroboros-run
description: Enter implementation from a frozen seed using the repository's existing Route A/B system. Use when the user invokes `ooo run` or asks to build from the spec, start implementation from `SEED.yaml`, or execute the agreed contract without introducing separate polling or orchestration layers.
---

# `ooo run`

Enter implementation from the frozen seed while keeping the repository's multi-agent rules in control.

## Usage

```text
ooo run
ooo run <seed-path>
```

## Workflow

1. Re-read `STATE.md` and confirm the current request still matches the active seed and task.
2. Read the seed from the provided path, or default to `SEED.yaml` in the workspace root.
3. If no valid seed exists, stop and return to `ooo seed`.
4. Reclassify the task using the repository Route A/B rules before editing implementation files.
5. Update `STATE.md` with the active task, route, reason, phase, and ownership before further writes.
6. Execute implementation through the selected route:
   - Route A: keep one tight write slice, one writer, and no subagent calls
   - Route B: keep `main` planner-only, freeze contracts/write sets in `STATE.md`, and delegate implementation to workers and reviewer
7. Stop after implementation is complete and hand off to `ooo evaluate` for verification and final close-out.

## Guardrails

- Do not invent behavior outside the frozen seed.
- Do not skip `STATE.md` route logging.
- Do not start background jobs, polling loops, or separate orchestration runtimes.
- Do not bypass Route B reviewer requirements.
- Do not let `main` write implementation files on Route B.
- Do not close the task until the required verification path is complete.

## Handoff

When implementation reaches a stable checkpoint:

- summarize what changed against the seed
- note the seed path and active route
- direct the workflow to `ooo evaluate`
