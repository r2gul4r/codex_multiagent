# Deprecated Rule Evolution Log Example

This is a historical reference only, not a canonical standing artifact.
Do not create a separate rule-evolution log for current work.
Use `TASK_RETROSPECTIVE.example.md` as the standing task-level evidence artifact; repeated patterns may support future kit-level proposals.

```md
- date: `2026-04-13`
- pattern: `same-workspace concurrent tasks appended to one STATE.md and collided`
- evidence:
  - `two live tasks overwrote each other's current_task and writer_slot`
- decision:
  - `keep single STATE.md as default, but add optional concurrent registry mode with thread-owned state files`
- affected_rules:
  - `Task Continuity`
  - `State Integrity`
  - `installer-generated instructions`
- follow_up:
  - `document root registry fields and thread state examples`
- status: `deprecated_reference`
```
