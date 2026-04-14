# Operations Retrospective

The point of a retrospective here is not ceremony.
It is task-level evidence for future rule proposals.

## When To Write One

- The task was non-trivial
- The task was reclassified mid-flight
- A collision, lock conflict, or ownership bug appeared
- Verification caught something the plan missed
- Installer or template text turned out to be misleading

## Minimum Fields

- `task`
- `date`
- `score_total`
- `predicted_topology` or `selected_profile`
- `actual_topology`
- `spawn_count`
- `rework_or_reclassification`
- `reviewer_findings`
- `verification_outcome`
- `next_rule_change`

## Standing Artifact

- task retrospective
  - what happened on one concrete workspace task
  - whether the evidence suggests a future kit-level rule or template proposal

Do not introduce a separate standing rule-evolution artifact.
Reuse task retrospectives as the evidence trail; repeated patterns may inform kit-level proposals.

## What Good Looks Like

- short
- concrete
- tied to one failure or one win
- ends with a bounded next action or a rule/template proposal worth considering

## What To Avoid

- vague feelings without evidence
- giant narrative dumps
- patch notes masquerading as a retrospective
- blaming "the model" instead of naming the contract or ownership failure

## Examples

- [Task Retrospective Example](../examples/TASK_RETROSPECTIVE.example.md)
