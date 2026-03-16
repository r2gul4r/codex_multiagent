# Global Multi-Agent AGENTS

These are the default multi-agent rules that apply across workspaces

Repository-level `AGENTS.md` files should be treated as more specific overrides

## Global Defaults

- Default to a single `main` agent
- Use multiple agents only when the split is genuinely safer than staying single-agent
- Split by `write scope`, shared contracts, and verification scope
- Keep `explorer` and `reviewer` read-only
- Close every write slice with a reviewer pass
- Do not send follow-up status prompts to running workers
- Do not respawn interrupted workers with the same prompt

## Base Roles

- `main`
  Orchestration, contract pinning, result integration, final decisions
  If `main` writes code directly, it consumes the single `writer` slot
- `explorer`
  Read-only scouting for files, contracts, and tests
- `worker`
  Implementation
  When implementation is delegated, that worker consumes the single `writer` slot
- `reviewer`
  Final read-only review

## Global Contract Rules

- Shared contracts such as APIs, schemas, routes, event names, payloads, and env keys must be pinned before implementation fans out
- If the contract is not pinned, stay in `main` or reduce the slice
- `reviewer` checks contract integrity before style or formatting

## Parallelization Rules

- Default to `main` alone
- Maximum concurrent `explorer` agents is `3`
- Maximum concurrent `reviewer` agents is `2`
- Maximum concurrent code-writing agents is `1`
- The single `writer` slot may be held by `main` or by one delegated `worker`
- Do not open a second write-capable lane under any circumstance
- Do not let `main` and a `worker` write at the same time
- Parallel work is limited to combinations that keep the single writer rule intact
- If the split is unclear, do not parallelize

## Repository Overrides

When a repository has its own `AGENTS.md`, treat it as the local override layer

Repository overrides should mainly define

- verification commands
- worker names
- shared contracts for that repo
- forbidden paths
- manual approval zones
