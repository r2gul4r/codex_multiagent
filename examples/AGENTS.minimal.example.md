# Minimal AGENTS Example

This is the fast-start version for small repositories or personal projects

## Core Rules

- Default to `Route A` in `main`
- Do not use multiple agents for simple investigation or short edits
- Use a hard-trigger + scorecard gate before switching into `Route C`
- Before closing, let `reviewer` do one read-only pass
- Max concurrent role caps are `explorer 3`, `reviewer 2`, `worker 4 on Route C`
- Keep a small `STATE.md` with `current_task`, `route`, `writer_slot`, and `contract_freeze`

## Roles

- `main`
  Pins the goal, integrates the result, makes the final call
- `worker`
  Makes the actual changes
- `reviewer`
  Performs the final read-only review

## Parallelization

- Default to no parallelization
- Make an exception only when hard triggers or scorecard move the task into `Route C`
- If the shared contract starts drifting, collapse back to `main`

## Done Means

- The goal fits in one line
- The edit scope is small and clear
- Required verification ran or the reason for skipping is recorded
- Reviewer can close with no critical risk
