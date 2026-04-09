# Micro Seed Template

Use this template when the team wants the Ouroboros-lite workflow without the full original runtime payload.

The goal is simple:

- freeze intent before implementation
- make `ooo run` consume a stable contract
- make `ooo evaluate` judge against the same contract

## Rules

- Keep it short
- Make every acceptance criterion testable
- Write only what later implementation and evaluation actually need
- If scope changes materially, create a new revision instead of silently mutating the old seed
- Preserve `writer_slot`, `contract_freeze`, and `write_sets` as the ownership primitives
- Let score-based orchestration choose skills and delegation automatically unless the user overrides it

## Template

Copy this template into `SEED.yaml`; that file is the actual workflow contract for the workflow.

```yaml
goal: "<primary objective>"

constraints:
  - "<hard limit or invariant>"

orchestration:
  score_total: "<small | medium | large>"
  selected_rules:
    - "<rule name>"
  selected_skills:
    - "<skill name>"
  execution_topology: "<single-session | delegated-serial | delegated-parallel | mixed>"
  agent_budget:
    total_budget: "<number or task-scoped cap>"
    worker_budget: "<number>"
    reviewer_budget: "<number>"
    explorer_budget: "<number>"

acceptance_criteria:
  - "<observable success condition>"

verification:
  - "<command, check, or review condition>"

out_of_scope:
  - "<explicit non-goal>"
```

## Example

```yaml
goal: "Add Ouroboros-lite workflow support to the repository without introducing background orchestration or MCP-only dependencies."

constraints:
  - "Keep the existing orchestration model documented in the repository consistent with score-based selection."
  - "Do not require Codex CLI-only features."
  - "Do not introduce polling-based workflow steps."
  - "Preserve writer_slot, contract_freeze, and write_sets in the workflow contract."

orchestration:
  score_total: "medium"
  selected_rules:
    - "spec_first_required"
    - "contract_freeze_required"
    - "review_required"
  selected_skills:
    - "ouroboros-seed"
    - "ouroboros-run"
    - "ouroboros-evaluate"
  execution_topology: "single-session"
  agent_budget:
    total_budget: 2
    worker_budget: 1
    reviewer_budget: 1
    explorer_budget: 0

acceptance_criteria:
  - "`ooo interview`, `ooo seed`, `ooo run`, and `ooo evaluate` each have repository-packaged skill definitions."
  - "The workflow contract clearly records the selected rules, skills, topology, and budget."
  - "Evaluation explicitly checks compliance against the frozen seed."

verification:
  - "Review the generated skill files for alignment with the seed contract."
  - "Run `git diff --check` after edits."

out_of_scope:
  - "Full Ouroboros MCP server integration."
  - "Lineage/evolution automation."
  - "Background job monitoring or polling."
```
