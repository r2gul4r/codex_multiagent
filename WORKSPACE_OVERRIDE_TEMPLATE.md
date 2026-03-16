# Workspace Override

This file adds repository-specific rules on top of the global multi-agent defaults

## Repository Facts To Fill

- Verification commands
  Example: `[pnpm lint]`, `[pnpm test]`, `[pnpm build]`
- Worker names
  Example: `[ui_worker]`, `[backend_worker]`, `[data_worker]`
- Shared contracts
  Example: `[OpenAPI schema, event names, DB migration rules]`
- Do-not-touch paths
  Example: `[generated/, dist/, vendor/]`
- Manual approval zones
  Example: `[deploy, migrations, writes to external systems]`
- Task board path
  Example: `[STATE.md]`

## Repository Overrides

- Role caps inherited from global defaults stay fixed
  `explorer 3`, `reviewer 2`, `writer 1`
- Keep `STATE.md` updated with `current_task`, `next_tasks`, `blocked_tasks`, `writer_slot`, and `contract_freeze`
- Add repository-specific worker mapping here
- Add forbidden patterns that are unique to this repository
- Add rules for migrations, deployments, or risky directories
- Add verification expectations for reviewer

## Example Worker Mapping

- `[ui_worker]`
  UI, layout, forms, panels
- `[backend_worker]`
  API, auth, session, queue, webhook
- `[data_worker]`
  Schema, ingestion, ETL, provider contract
- `default`
  Fallback when no specific domain matches
