# Task Retrospective Example

```md
- task: `installer update-flow hardening`
- date: `2026-04-13`
- score_total: 6
- selected_profile: `single-session`
- actual_topology: `single-session`
- verification_outcome: `macOS workflow passed; local Linux smoke remained indirect`
- collisions_or_reclassifications:
  - `reclassified from implementation to verification-only when real smoke evidence became the primary goal`
- what_worked:
  - `Keeping one write lane avoided shell and PowerShell template drift`
- what_broke:
  - `The previous task state was still pinned to the older slice until reclassification`
- next_rule_change:
  - `Always report the current score basis from STATE.md before entering the next slice`
```
