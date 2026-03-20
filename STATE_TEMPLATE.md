# STATE Template

Use this file as the lightweight task board and execution lock sheet for multi-agent work

## Current Task

- id: `[task_id]`
- summary: `[one-line acceptance criteria]`
- owner: `[main | worker name]`
- phase: `[explore | freeze | write | review | done | blocked]`

## Route

- name: `[Route A | Route B | Route C]`
- reason: `[hard trigger or score summary]`

## Next Tasks

- `[next_task_1]`
- `[next_task_2]`
- `[next_task_3]`

## Blocked Tasks

- `[blocked_task]`
  reason: `[why blocked]`

## Writer Slot

- status: `[free | main | worker_name | parallel]`
- target_scope: `[files or directories currently being edited]`
- write_sets:
  - `[worker_name = files or directories]`

## Contract Freeze

- status: `[open | frozen]`
- shared_contracts:
  - `[API / schema / event / props / env key]`
- freeze_owner: `[main]`

## Review Focus

- `[contract check]`
- `[regression risk]`
- `[verification gaps]`

## Last Update

- updated_by: `[agent name]`
- updated_at: `[timestamp]`
