# Ouroboros-Lite For This Repository

Use Ouroboros-lite workflow commands when the user is trying to:

- clarify requirements before implementation
- freeze a spec before writing code
- enter implementation through the repository route system
- evaluate results against a frozen spec

## Critical Command Routing

When the user types `ooo <command>`, treat it as a workflow command, not casual natural language.

Check the current task context in `STATE.md` before acting, and keep repository Route A/B/C rules as the top-level orchestration layer.

| User input | Meaning |
|-----------|---------|
| `ooo interview ...` | enter requirement-clarification phase in read-only mode |
| `ooo seed` | freeze the current requirement set into a seed snapshot |
| `ooo run` | enter implementation using the current Route A/B/C rules |
| `ooo evaluate` | run verification against the frozen seed |

## Natural Language Mapping

For natural-language requests that clearly match the workflow, prefer the corresponding phase:

- "clarify requirements", "interview me", "what are we actually building?" -> `ooo interview`
- "freeze the plan", "lock the spec", "turn this into a contract" -> `ooo seed`
- "build it from the spec", "start implementation from the plan" -> `ooo run`
- "verify against the plan", "did we satisfy the spec?" -> `ooo evaluate`

## Guardrails

- Do not auto-install or auto-update global assets from the rule itself
- Do not start long polling loops or background orchestration from the rule itself
- Do not bypass `STATE.md`
- Do not override repository Route A/B/C behavior
- Do not invent parallel execution ownership outside the current multi-agent rules
- If the request is clearly unrelated to the workflow, handle it normally
