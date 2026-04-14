# Patch Notes

## 2026-04-14

### Summary

- Added repository quality-signal tooling for metrics, feature gaps, test gaps, refactor candidates, and normalized tool output.
- Added a root `Makefile` verification entrypoint with best-effort local checks.
- Refined delegation policy so subagent spawning is based on score, hard triggers, write-set separability, and an explicit efficiency gate.
- Added a compact recursive improvement gate for policy/template changes so reviews converge on verdicts, minimal edits, and second-pass self-checks.

### Included Changes

- Added `collect_repo_metrics.py` for module size, complexity, duplication, and git-history signals.
- Added `normalize_quality_signals.py` to normalize tool failures, warnings, coverage, and repository metric payloads into common JSON.
- Added extraction helpers for feature-gap, test-gap, and refactor-candidate reports.
- Added generated reports under `docs/` for goal alignment, area evaluation, repository metrics, feature gaps, test gaps, and refactor candidates.
- Added `examples/quality_signal_samples.json` as a stable sample input for normalization smoke tests.
- Added Python generated-file ignores to `.gitignore`.
- Updated `AGENTS.md` and `MULTI_AGENT_GUIDE.md` so delegation is not driven by score alone:
  - `4-6` point work uses a lightweight efficiency check when the choice is non-obvious.
  - `7+` point work records an explicit `spawn_decision` unless a concrete blocker keeps it local.
  - installer, template, global-default, and authorization wording must distinguish existing authority from newly created authority.
- Updated shell and PowerShell installer generated instructions to describe delegation authorization only when user or workspace instructions grant it.

### Operator Impact

- Operators can run a consistent local verification surface through `make lint`, `make test`, and `make check` when `make` is available.
- Agents should avoid spawning subagents just because `score_total` is high; score starts the analysis, and efficiency plus ownership decides the call.
- Recursive policy review should now produce a short decision-oriented output instead of a long critique: failure mode, effect, blast radius, verdict, minimal edit, self-check, and recommendation.
- Installer defaults no longer imply that every user has granted automatic subagent-spawn authorization.

### Verification

- `git diff --check`
- `bash -n installer/CodexMultiAgent.sh`
- PowerShell parser check for `installer/CodexMultiAgent.ps1`
- `bash installer/CodexMultiAgent.sh --help`
- `python -m py_compile collect_repo_metrics.py normalize_quality_signals.py extract_feature_gap_candidates.py extract_refactor_candidates.py extract_test_gap_candidates.py`
- `python normalize_quality_signals.py --input examples/quality_signal_samples.json`
- Generated markdown comparison for feature-gap, refactor-candidate, and test-gap reports

### Known Local Notes

- `make` was not available in the local PATH during validation, so equivalent checks were run directly.
