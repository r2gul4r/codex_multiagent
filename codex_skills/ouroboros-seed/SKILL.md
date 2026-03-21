---
name: ouroboros-seed
description: Freeze clarified requirements into a deterministic seed contract for Codex app workflows. Use when the user invokes `ooo seed` or asks to lock the plan, turn interview results into a spec, or create the contract that `ooo run` and `ooo evaluate` must follow.
---

# `ooo seed`

Freeze the current requirement set into a shared seed artifact before implementation starts.

## Usage

```text
ooo seed
```

## Workflow

1. Re-read the active task in `STATE.md` and confirm the current request still matches the task being clarified.
2. Gather the frozen inputs from the interview output or the current conversation:
   - `goal`
   - `constraints`
   - `acceptance_criteria`
   - `verification`
   - `out_of_scope`
3. If any required section is still fuzzy, stop and return to `ooo interview` instead of inventing details.
4. Default the seed artifact path to `SEED.yaml` in the workspace root unless the user already pinned a different path.
5. Write the seed in a deterministic YAML shape that later phases can consume without reinterpretation.
6. Record the active seed path in `STATE.md` while keeping the task in a pre-implementation phase.
7. Hand off to `ooo run` only after the seed is fully frozen.

## Seed Schema

Use this minimum schema:

```yaml
goal: ...
constraints:
  - ...
acceptance_criteria:
  - ...
verification:
  - ...
out_of_scope:
  - ...
```

Keep the schema lean. Do not add ontology, lineage, ambiguity score, or runtime metadata unless the repository later standardizes them.

## Guardrails

- Do not start implementation while freezing the seed.
- Do not leave required fields implicit.
- Do not mutate the meaning of an already frozen seed; create a new revision instead.
- Do not add MCP loading, polling, setup, or update behavior.
- Do not bypass repository Route A/B rules.

## Handoff

When the seed is frozen:

- summarize the contract briefly
- note the seed path
- direct the workflow to `ooo run`
