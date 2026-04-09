# Minimal AGENTS Example

This is the fast-start version for small repositories or personal projects.

## Core Rules

- Default to a score-based orchestration profile
- Do not use multiple agents for simple investigation or short edits unless the selected rules justify it
- Use a hard-trigger plus score gate before selecting delegation
- Let `main` choose `selected_rules`, `selected_skills`, and `execution_topology`
- Before closing delegated work, let `reviewer` do one read-only pass when `review_required` is selected
- Keep a small `STATE.md` with `score_total`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget`, `writer_slot`, and `contract_freeze`

## Roles

- `main`
  Pins the goal, selects the orchestration profile, integrates the result, makes the final call
- `worker`
  Makes the actual changes
- `reviewer`
  Performs the final read-only review

## Parallelization

- Default to no parallelization
- Make an exception only when the score and hard triggers justify delegation
- If the shared contract starts drifting, collapse back to `main`

## Done Means

- The goal fits in one line
- The edit scope is small and clear
- Required verification ran or the reason for skipping is recorded
- Reviewer can close with no critical risk
