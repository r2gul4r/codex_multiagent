---
name: ouroboros-interview
description: Spec-first requirement clarification for Codex app workflows. Use when the user invokes `ooo interview` or asks to clarify scope, constraints, acceptance criteria, verification expectations, or out-of-scope boundaries before implementation.
---

# `ooo interview`

Turn a vague implementation request into seed-ready requirements without writing code.

## Usage

```text
ooo interview <topic>
```

## Workflow

1. Stay read-only for the whole interview.
2. Read the current `STATE.md` task and detect whether this is a new task or a clarification pass on the active task.
3. If useful, scan a small set of repository files to ground questions in existing code and contracts.
4. Identify the main ambiguity tracks and keep them separate:
   - scope
   - constraints
   - outputs
   - verification
   - non-goals
5. Ask short, concrete questions that reduce the biggest remaining ambiguity first.
6. Prefer breadth over drilling too deep into one subtopic.
7. Stop once the request is specific enough to freeze into a seed.

## Required Outcomes

Before ending the interview, make sure these are explicit:

- `goal`
- `constraints`
- `acceptance criteria`
- `verification`
- `out of scope`

If one of these is still fuzzy, ask about it directly instead of opening a new side topic.

## Guardrails

- Do not edit files.
- Do not write code.
- Do not start implementation.
- Do not spawn long-running orchestration loops.
- Do not bypass repository Route A/B rules.
- Do not keep interviewing once the request is already seed-ready.

## Handoff

When the interview is complete, summarize the frozen inputs in a compact checklist and direct the workflow to `ooo seed`.
