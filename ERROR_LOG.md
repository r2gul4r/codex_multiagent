# ERROR_LOG

Append-only log for work errors that materially affect implementation, installer, tool, or verification flow. Add new entries at the end and do not rewrite prior ones. If work is interrupted or paused, keep the entry `open` or `deferred` until a later append marks it resolved.

## Entry Format

- time: `YYYY-MM-DD HH:MM:SS ±HH:MM`
- location: command, file, step, or system
- summary: short error label
- details: concise impact and context
- status: `open` | `deferred` | `mitigated` | `resolved`

## Entries

- time:
  location:
  summary:
  details:
  status:

- time: `2026-03-22 05:53:00 +09:00`
  location: `GitHub Actions macos-install / Test local installer global`
  summary: `bash 3.2 empty-array expansion crashed install-global`
  details: `installer/CodexMultiAgent.sh` hit `unbound variable` errors in `iter_top_level_sorted_paths` and the managed-skill cleanup path under `set -u` when those collections were empty on macOS.
  status: `open`

- time: `2026-03-22 06:01:00 +09:00`
  location: `installer/CodexMultiAgent.sh`
  summary: `bash 3.2 empty-array expansion crashed install-global`
  details: Removed the empty-array-dependent iteration in `iter_top_level_sorted_paths` and `install_codex_skills`, then re-ran `git diff --check`, `bash -n installer/CodexMultiAgent.sh`, and a local `install-global` plus `apply-workspace` verification script successfully.
  status: `resolved`
