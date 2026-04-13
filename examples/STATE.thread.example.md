# Thread State Example

```md
# Current Task

- Add concurrent registry guidance to canonical docs.

# Orchestration Profile

- thread_id: `thread-1042`
- score_total: 5
- hard_triggers:
  - `none`
- selected_rules:
  - `contract_freeze_required`
  - `state_integrity_required`
- selected_skills:
  - `ouroboros-run`
- execution_topology: `single-session`
- selection_reason: `This thread owns one closed documentation slice under the root registry.`

# Writer Slot

- writer_slot: `thread-1042`
- owned_files:
  - `AGENTS.md`
  - `docs/CONCURRENT_STATE_MODE.md`
- shared_assets_owner: `none`

# Contract Freeze

- contract_freeze:
  - `Do not change installer templates in this thread.`
- write_sets:
  - `thread-1042`:
    - `AGENTS.md`
    - `docs/CONCURRENT_STATE_MODE.md`

# Reviewer

- reviewer: `none`
- reviewer_target: `none`
- reviewer_focus: `n/a`

# Last Update

- phase: implementation
- status: `active`
- verification_target:
  - `git diff --check`
- last_heartbeat: `2026-04-13T16:24:00+09:00`
```
