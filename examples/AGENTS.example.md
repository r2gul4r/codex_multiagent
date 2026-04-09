# AGENTS Example

This example shows how the template can look in a larger web or service repository.

Adjust the paths and commands to match the real repository.

## Operating Goal

- Use a score-based orchestration profile instead of a fixed route split
- Let `main` select `selected_rules`, `selected_skills`, `execution_topology`, and `agent_budget`
- Pin API, schema, and ownership contracts before workers start
- Keep `writer_slot`, `contract_freeze`, and `write_sets` as the shared tracking primitives
- Use automatic delegation and automatic skill routing unless a user instruction overrides it

## Roles

- `main`
  Orchestration, contract pinning, and final integration
- `explorer`
  Read-only scouting when `exploration_required` is selected
- `worker_shared`
  Shared types, common utilities, and other shared assets
- `ui_worker`
  `apps/web`, `packages/ui`
- `backend_worker`
  `apps/api`, `packages/server`
- `data_worker`
  `packages/schema`, migrations, provider contracts
- `reviewer`
  Final read-only review when `review_required` is selected

## Repository-Specific Rules

- `explorer` and `reviewer` are read-only
- `main` selects the orchestration profile, not a fixed route
- Workers write only inside their assigned `write_set`
- Keep `STATE.md` updated with `score_total`, `score_breakdown`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget`, `writer_slot`, `contract_freeze`, and `write_sets`
- If both `apps/web` and `apps/api` are touched, request payload contracts must be pinned first
- If a migration file is involved, do not parallelize unless the selected rules and write sets prove the split is safe
- Do not edit `generated/` or `dist/` directly
- Treat explicit natural-language overrides from the user as higher priority than automatic selection

## Verification Commands

- `pnpm lint`
- `pnpm test`
- `pnpm build`

## Parallel Work That Is Safe

- Up to three `explorer` agents can narrow scope in read-only mode when the selected rules allow exploration
- One `worker_shared` owns shared types and common utilities
- Feature workers edit separate file ranges
- Reviewers can split final checking by concern if the selected rules and budget allow it
- `main` keeps the work inside the selected orchestration profile and budget

## Parallel Work That Is Not Safe

- Splitting a form UI, validator, and submit payload across different workers without a pinned contract
- Splitting one migration and the code that depends on it
- Letting feature workers edit shared types or shared utilities directly
- Any flow where reviewer would need to implement fixes just to make the task finish

## Done Means

- The goal can be explained in one line
- Shared contracts match across code and docs
- Required verification passed or the skip reason is explicit
- Reviewer can close with no critical risk
