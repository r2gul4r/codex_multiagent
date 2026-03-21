# STATE

## Current Task

- task: Fix the failing macOS `apply-workspace` test path that uses `WORKSPACE_CONTEXT.toml`.
- phase: verification
- scope: `.github/workflows/macos-codex-installer.yml`
- verification_target: `git diff --check`, `bash -n installer/CodexMultiAgent.sh`, and a targeted reproduction of the `apply-workspace --include-docs` flow with `WORKSPACE_CONTEXT.toml`

## Route

- route: `Route A`
- reason: Initial scope is a tight CI regression investigation in the shell installer path. One write-capable lane is enough unless the fix expands beyond the installer/workflow slice.

## Writer Slot

- owner: `main`
- write_set: `.github/workflows/macos-codex-installer.yml`, `ERROR_LOG.md`, `STATE.md`
- note: Single write-capable lane only. Reproduction showed the installer succeeds and the stale workflow assertions are the actual failing slice.

## Contract Freeze

- contract_freeze: Keep the installer behavior untouched. Update only the stale macOS workflow assertions so they match the current generated `STATE.md` template.

## Seed

- status: `n/a`
- path: `n/a`
- revision: `n/a`
- note: `Use this section to track the active frozen seed once a spec-first task starts.`

## Reviewer

- reviewer: `n/a`
- reviewer_target: `n/a`
- reviewer_focus: `n/a`

## Last Update

- timestamp: `2026-03-22 06:42:00 +09:00`
- note: Updated the stale workflow assertions to the current generated `STATE.md` strings and re-ran the WORKSPACE_CONTEXT reproduction successfully.
