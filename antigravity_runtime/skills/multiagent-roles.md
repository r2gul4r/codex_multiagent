---
name: multiagent-roles
description: Role map and split rules for the installed multi-agent kit.
---

# Multi-Agent Roles

## Core Roles
- `main`
  Orchestrates the task, pins shared contracts, integrates results, and makes final decisions
- `explorer`
  Read-only scouting for files, existing contracts, verification scope, and likely impact
- `worker`
  Handles the smallest useful write slice
- `reviewer`
  Performs the final read-only review before a write slice is considered closed

## Split Policy
- Default to `main` alone
- Use multiple agents only when the split is genuinely safer than staying single-agent
- Split by `write scope`, shared contracts, and verification scope
- If contract drift appears, collapse back to `main` or shrink the slice

## Repository Overrides
If the current repository has an `AGENTS.md`, use it as the local override layer.

Repository overrides may define:
- verification commands
- repository-specific worker names
- shared contracts
- do-not-touch paths
- manual approval zones

## Forbidden Inference
Do not claim the runtime has built-in agents such as Browser Subagent, Go Build Resolver, Go Reviewer, TDD bots, or coverage bots unless the current installed files explicitly define them.
