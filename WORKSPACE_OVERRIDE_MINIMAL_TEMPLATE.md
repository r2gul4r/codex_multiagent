# Workspace Override

This file adds the smallest repository-specific layer on top of the global multi-agent defaults

## Fill Only What Matters

- Verification commands
- Shared contracts
- Do-not-touch paths

## Minimal Repository Rules

- Role caps inherited from global defaults stay fixed
  `explorer 3`, `reviewer 2`, `writer 1`
- Keep changes small
- Do not parallelize unless `write scope` is obviously separate
- Add repository-specific review checks here
