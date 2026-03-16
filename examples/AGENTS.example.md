# AGENTS Example

This example shows how the template can look in a larger web or service repository

Adjust the paths and commands to match the real repository

## Operating Goal

- Default to `main` alone
- Allow parallel work only when `write scope` is fully separate
- Pin API, schema, and route contracts before workers start

## Roles

- `main`
  Orchestration, contract pinning, and final integration
- `explorer`
  Read-only scouting
- `ui_worker`
  `apps/web`, `packages/ui`
- `backend_worker`
  `apps/api`, `packages/server`
- `data_worker`
  `packages/schema`, migrations, provider contracts
- `reviewer`
  Final read-only review

## Repository-Specific Rules

- `explorer` and `reviewer` are read-only
- Only worker roles make write changes
- If both `apps/web` and `apps/api` are touched, request payload contracts must be pinned first
- If a migration file is involved, do not parallelize
- Do not edit `generated/` or `dist/` directly

## Verification Commands

- `pnpm lint`
- `pnpm test`
- `pnpm build`

## Parallel Work That Is Safe

- `ui_worker` changes presentation-only code
- `backend_worker` updates docs or an unrelated route
- The workers do not touch the same schema, payload, or test files

## Parallel Work That Is Not Safe

- Splitting a form UI, validator, and submit payload across different workers
- Splitting one migration and the code that depends on it
- Any flow where reviewer would need to implement fixes just to make the task finish

## Done Means

- The goal can be explained in one line
- Shared contracts match across code and docs
- Required verification passed or the skip reason is explicit
- Reviewer can close with no critical risk
