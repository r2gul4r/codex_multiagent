# Root Registry Example

```md
# Current Task

- Root registry for same-workspace concurrent execution.

# Orchestration Profile

- state_mode: `concurrent-registry`
- shared_contracts:
  - `installer rule text must stay aligned across shell and PowerShell generators`
- active_threads:
  - `thread-1042`: `states/STATE.thread-1042.md`
  - `thread-1043`: `states/STATE.thread-1043.md`
- workspace_locks:
  - `AGENTS.md`: `thread-1042`
  - `docs/CONCURRENT_STATE_MODE.md`: `thread-1042`
  - `examples/TASK_RETROSPECTIVE.example.md`: `thread-1043`

# Writer Slot

- writer_slot: `registry-only`
- owned_files:
  - `STATE.md`
- shared_assets_owner: `none`

# Contract Freeze

- contract_freeze: `root registry only`
- handoff_queue:
  - `none`
- escalation_note: `If a thread needs a locked file, stop and reclassify before writes.`

# Reviewer

- reviewer: `none`
- reviewer_target: `none`
- reviewer_focus: `n/a`

# Last Update

- phase: coordination
- last_registry_update: `2026-04-13T16:20:00+09:00`
```
