---
name: ouroboros-evaluate
description: Verify implementation against the frozen seed using staged repository checks. Use when the user invokes `ooo evaluate` or asks whether the finished work satisfies `SEED.yaml`, the acceptance criteria, the verification steps, and any Route B reviewer obligations.
---

# `ooo evaluate`

Evaluate completed work against the frozen seed and the repository's verification path.

## Usage

```text
ooo evaluate
ooo evaluate <seed-path>
```

## Workflow

1. Re-read `STATE.md` and confirm the active task, route, and ownership state.
2. Read the seed from the provided path, or default to `SEED.yaml` in the workspace root.
3. If no valid seed exists, stop and return to `ooo seed`.
4. Run evaluation in stages:
   - Stage 1: mechanical verification
   - Stage 2: seed compliance review
   - Stage 3: reviewer integration when Route B requires it
5. Report pass/fail against the seed, not just against implementation intent.
6. If the result fails, route the next action explicitly:
   - missing or broken implementation -> back to `ooo run`
   - unclear or changing contract -> back to `ooo interview` or `ooo seed`
7. Close the workflow only when the required route-specific verification path is complete.

## Evaluation Stages

### Stage 1: Mechanical Verification

Use repository verification commands where available:

- lint
- test
- build
- targeted repro

Fail fast if required mechanical checks fail.

### Stage 2: Seed Compliance Review

Check the implementation against the seed:

- `goal`
- `constraints`
- `acceptance_criteria`
- `verification`
- `out_of_scope`

Explicitly call out:

- unmet acceptance criteria
- seed drift
- out-of-scope additions
- verification gaps

### Stage 3: Reviewer Integration

If the active route is Route B:

- require the reviewer pass to be reflected in the final evaluation
- do not mark the task complete before the reviewer obligation is satisfied

If the active route is Route A:

- keep evaluation local unless the user asks for extra review depth

## Guardrails

- Do not skip mechanical checks that the repository expects.
- Do not treat "looks good" as sufficient.
- Do not bypass Route B reviewer requirements.
- Do not invent a model-consensus stage or long-running evaluation loop.
- Do not close the task while seed drift or verification gaps are still open.

## Handoff

When evaluation is complete:

- summarize pass/fail by stage
- state whether the seed contract was satisfied
- if failed, point to `ooo run`, `ooo seed`, or `ooo interview` as the next corrective step
