# Workspace Override

This file adds the smallest repository-specific layer on top of the global multi-agent defaults

## Fill Only What Matters

- Verification commands
- Shared contracts
- Do-not-touch paths
- Task board path

## Minimal Repository Rules

- Role caps inherited from global defaults stay fixed
  `explorer 3`, `reviewer 2`, `writer 1`
- Keep `STATE.md` updated with at least `current_task`, `writer_slot`, and `contract_freeze`
- Keep changes small
- Do not parallelize unless `write scope` is obviously separate
- Add repository-specific review checks here
