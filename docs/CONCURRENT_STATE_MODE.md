# Concurrent State Mode

Default operation is one shared `STATE.md`.
Keep that default unless same-workspace concurrent threads are truly necessary.

## When To Turn It On

- Two or more live threads must work in the same workspace at the same time
- Write ownership can stay disjoint
- Shared contracts are already pinned or can be pinned before concurrent writes
- Moving one slice to another worktree is worse than keeping one registry in place

If two live threads need the same file, the same shared asset, or the same contract surface, do not use concurrent mode.
Serialize the work or split the workspace instead.

## Shape

Use the root `STATE.md` as the registry only.

Track:

- `state_mode`
- `active_threads`
- `workspace_locks`
- shared-contract notes
- escalation or handoff notes

Move per-thread execution tracking into files such as:

- `states/STATE.<thread_id>.md`

Each thread file still keeps the usual sections:

- `Current Task`
- `Orchestration Profile`
- `Writer Slot`
- `Contract Freeze`
- `Reviewer`
- `Last Update`

## Minimum Rules

- One live thread owns one state file
- One live thread owns one write set
- Root registry changes happen before implementation writes
- A thread may not claim a file already locked by another live thread
- If ownership becomes ambiguous, stop and reclassify before more writes

## Suggested Root Fields

- `state_mode: concurrent-registry`
- `active_threads`
- `workspace_locks`
- `shared_contracts`
- `handoff_queue`
- `last_registry_update`

## Suggested Thread Fields

- `thread_id`
- `task`
- `selected_profile`
- `owned_write_sets`
- `status`
- `started_at`
- `last_heartbeat`
- `verification_target`

## Recommended Workflow

1. Freeze the contract first.
2. Register live threads in root `STATE.md`.
3. Lock files or globs before implementation.
4. Write only through the owning thread state file.
5. Release locks when the thread finishes or hands off.

## Examples

- [Registry Example](/C:/lsh/git/codex_multiagent/examples/STATE.registry.example.md)
- [Thread Example](/C:/lsh/git/codex_multiagent/examples/STATE.thread.example.md)
