# Operations Retrospective

The point of a retrospective here is not ceremony.
It is evidence for future rule changes.

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

## Two Useful Artifacts

- task retrospective
  - what happened on one concrete task
- rule evolution log
  - what global rule or template should change because the same pattern keeps repeating

Keep both append-only when possible.

## What Good Looks Like

- short
- concrete
- tied to one failure or one win
- ends with a rule or template change worth making

## What To Avoid

- vague feelings without evidence
- giant narrative dumps
- patch notes masquerading as a retrospective
- blaming "the model" instead of naming the contract or ownership failure

## Examples

- [Task Retrospective Example](../examples/TASK_RETROSPECTIVE.example.md)
- [Rule Evolution Log Example](../examples/RULE_EVOLUTION_LOG.example.md)
