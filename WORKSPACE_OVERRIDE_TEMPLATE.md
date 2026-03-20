# Workspace Override

This file adds repository-specific rules on top of the global multi-agent defaults

This file is only the repository-specific override layer

## Repository Facts To Fill

- Verification commands
  Example: `[pnpm lint]`, `[pnpm test]`, `[pnpm build]`
- Worker names
  Example: `[worker_feature_ui]`, `[worker_feature_api]`, `[worker_shared]`
- Shared contracts
  Example: `[OpenAPI schema, event names, DB migration rules]`
- Shared asset paths
  Example: `[src/types/, src/shared/, src/components/common/]`
- Repo-specific hard triggers
  Example: `[editing schema.prisma, changing route names, touching shared hooks]`
- Do-not-touch paths
  Example: `[generated/, dist/, vendor/]`
- Manual approval zones
  Example: `[deploy, migrations, writes to external systems]`
- Task board path
  Example: `[STATE.md]`
- Multi-agent log path
  Example: `[MULTI_AGENT_LOG.md]`

## Repository Overrides

- Role caps inherited from global defaults stay fixed
  `explorer 3`, `reviewer 2`, `worker up to 4 on Route C`
- Keep `STATE.md` updated with `current_task`, `next_tasks`, `blocked_tasks`, exact `route`, concrete `reason`, `writer_slot`, `contract_freeze`, and `write_sets` when Route C is active
- If multiple roles are used, append real participation to `MULTI_AGENT_LOG.md` before reporting that they ran
- If this repository narrows Route A/B/C behavior further, define those promotion and reviewer rules here explicitly
- List repository-specific shared asset paths here
- Add repository-specific hard triggers here
- Define whether this repository allows `worker_shared`
- Define Route C worker mapping here
- Define which directories may be owned by each feature worker
- Add repository-specific worker mapping here
- Add forbidden patterns that are unique to this repository
- Add rules for migrations, deployments, or risky directories
- Add verification expectations for reviewer

## Forbidden Commands

- Never run `git reset --hard` unless the user explicitly requests it
- Never run `git checkout -- <path>` or `git restore --source=<tree> -- <path>` to discard changes unless the user explicitly requests it
- Never run `git clean -fd` or `git clean -fdx` unless the user explicitly requests it
- Never use destructive delete commands such as `rm -rf`, `del /s /q`, or `Remove-Item -Recurse -Force` against repository files or user data just to "start fresh"
- Never revert, overwrite, or wipe user changes in a dirty worktree unless the user explicitly requests it

## Example Worker Mapping

- `[worker_feature_ui]`
  Feature UI, layout, panels, page wiring
- `[worker_feature_api]`
  API handlers, controllers, service logic
- `[worker_feature_test]`
  Tests, fixtures, docs, verification helpers
- `[worker_shared]`
  Shared types, common utilities, common components, import-path cleanup
- `default`
  Fallback when no specific domain matches

## Example Route C Declaration

- route: `[Route C]`
- shared asset paths: `[src/types/, src/shared/, src/components/common/]`
- shared worker: `[worker_shared]`
- `worker_feature_ui = [src/features/palworld/ui/*, src/routes/palworld/*]`
- `worker_feature_api = [src/features/palworld/api/*, src/server/palworld/*]`
- `worker_feature_test = [tests/palworld/*, docs/palworld.md]`
- `worker_shared = [src/types/*, src/shared/*, src/components/common/*]`
