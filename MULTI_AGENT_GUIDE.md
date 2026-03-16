# Multi-Agent Operating Guide

This document explains why the template is shaped the way it is

The core idea is simple
Reduce collisions first
Only then worry about concurrency

## 1. Why The Default Is `main` Alone

- Most confusion comes from splitting too early, not from having too few roles
- Parallel work gets expensive fast while shared contracts are still moving
- On small tasks, handoff cost is often larger than implementation cost
- Single-agent execution can look slower while still producing a shorter total lead time

## 2. What Makes A Safe Slice

A safe slice satisfies all four conditions below

- The goal can be described in one line
- The changed file range is small and closed
- The shared contract is already pinned
- There is a clear way to verify the result

If any part is blurry, shrink the slice or keep it in `main`

## 3. When To Use `explorer`

`explorer` only matters when scouting is cheaper than guessing

- Files are spread across a wide area
- Existing contracts need to be confirmed before editing
- Test scope needs to be narrowed first
- Discovery cost is higher than implementation cost

If the file and the edit are obvious, splitting out an explorer is just ceremony

## 4. When Two Workers Are Actually Safe

Parallel work is reasonable only when all of these are true

- `write scope` does not overlap
- Shared contracts such as API, schema, or payload are already pinned
- Verification can also stay separate
- `main` already knows the integration point

Good example

- Worker A edits `/ui/profile/*`
- Worker B updates `/docs/profile-editing.md`
- The contract is shared conceptually, but the files do not collide

Bad example

- Worker A edits a form UI
- Worker B edits the same form payload and validation
- The files, behavior, and contract are all tangled together

## 5. What Every Handoff Should Include

The more roles you split across, the more the input contract matters

Recommended handoff format

```md
Goal
- One-line acceptance criteria

Edit scope
- Files or directories

Pinned contracts
- APIs, schemas, routes, events, or env keys that must not drift

Verification
- Commands or manual checks

Done means
- What the reviewer should be able to confirm at the end
```

## 6. What `reviewer` Should Actually Look For

`reviewer` is not there to finish the implementation
It is the last risk filter

Recommended priority order

1. Contract violations
2. Regression risk
3. Missing tests or verification
4. Scope pollution
5. Minor style issues

Style comes last
If the structure is broken, formatting comments are noise

## 7. What To Do When A Worker Gets Stuck

- Do not respawn the same worker with the same prompt
- Check whether the problem is an unclear contract or an oversized slice
- If the contract is unclear, let `main` pin it again
- If the slice is too large, cut it in half
- If discovery was too thin, add a short `explorer` pass

## 8. What To Customize Per Repository

- Real verification commands
- Generated folders or risky paths that should not be edited
- Shared contract lists
- Manual approval zones such as deploys, migrations, or external writes
- Domain worker names

## 9. Recommended Adoption Order

1. Start with `main`, `worker`, and `reviewer`
2. Add `explorer` only when discovery cost is consistently high
3. Allow parallel work only in cases with clearly separate file ranges
4. When real collisions appear, add repository-specific forbidden patterns

## 10. One-Line Summary

Multi-agent work is not a free productivity buff
It is distributed coordination with extra failure modes

Keep slices small
Pin contracts early
Use reviewer as the last firewall
