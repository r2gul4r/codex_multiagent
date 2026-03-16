# Minimal AGENTS Example

This is the fast-start version for small repositories or personal projects

## Core Rules

- Default to `main` alone
- Do not use multiple agents for simple investigation or short edits
- If there is write work, start with one `worker`
- Before closing, let `reviewer` do one read-only pass
- Max concurrent role caps are `explorer 3`, `reviewer 2`, `writer 1`

## Roles

- `main`
  Pins the goal, integrates the result, makes the final call
- `worker`
  Makes the actual changes
- `reviewer`
  Performs the final read-only review

## Parallelization

- Default to no parallelization
- Make an exception only when `write scope` is fully separate
- If the shared contract starts drifting, collapse back to `main`

## Done Means

- The goal fits in one line
- The edit scope is small and clear
- Required verification ran or the reason for skipping is recorded
- Reviewer can close with no critical risk
