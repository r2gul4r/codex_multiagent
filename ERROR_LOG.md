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
