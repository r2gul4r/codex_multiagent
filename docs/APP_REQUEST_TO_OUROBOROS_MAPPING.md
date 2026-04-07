# App Request To Ouroboros Mapping

This note defines the first practical control surface from the Codex desktop app into the external Ouroboros runtime running in WSL.

The goal is simple:

- take a user request in the Codex app
- choose the matching WSL command
- know which artifact to read next
- know what the next decision should be

## Assumptions

- upstream Ouroboros lives at `~/ouroboros` inside WSL
- Codex CLI in WSL is already logged in with ChatGPT OAuth
- Ouroboros state and outputs live under `~/.ouroboros`
- the Codex desktop app controls the runtime through shell/file operations for now

## Common Command Prefix

Most app-side calls should start from the same prefix:

```powershell
wsl bash -lc "cd ~/ouroboros && <command>"
```

Examples below only vary the `<command>` section.

## Mapping Table

| User request in Codex app | When to use it | WSL command | Primary artifact to read next | Next app-side decision |
| --- | --- | --- | --- | --- |
| Start a fresh interview | The user has a vague goal and no usable seed yet | `uv run ouroboros init start '<goal>'` | latest interview file in `~/.ouroboros/data/` and new seed in `~/.ouroboros/seeds/` | If seed exists, ask whether to stop at seed or continue to `run` |
| Resume an interview | An interview already exists and the user wants to continue clarification | `uv run ouroboros init start --resume <interview_id>` | `~/.ouroboros/data/interview_<id>.json` | Check whether ambiguity is low enough to produce or reuse a seed |
| Run a seed | A seed already exists and implementation should begin | `uv run ouroboros run <seed_path>` | workflow outputs, logs, updated workspace files, runtime output | Decide whether to inspect outputs, review implementation, or move to policy-layer execution handling |
| Evaluate latest result | A run finished and the user wants the result assessed | `uv run ouroboros evaluate <target>` if upstream exposes it, otherwise inspect current run outputs and evaluation artifacts | evaluation output, run logs, generated verdict artifacts | If accepted, stop or summarize; if not, feed result back into another `run` or a new clarification step |
| List existing interviews or seeds | The user asks what already exists before choosing the next step | `ls ~/.ouroboros/data` or `ls ~/.ouroboros/seeds` | directory listing | Ask the user which interview or seed to continue, or choose the latest one if that is the obvious next step |
| Inspect latest seed | The user wants to review what the interview produced before running it | `ls -t ~/.ouroboros/seeds | head -n 1` then `cat ~/.ouroboros/seeds/<seed_file>` | latest seed YAML | Decide whether the seed is good enough to run or needs another interview pass |
| Check runtime health | The user reports a runtime failure or auth issue | `codex login status` and, when needed, a lightweight `codex exec` probe | login status and command stderr | If login is missing, re-auth; if exec fails, separate Codex CLI issues from Ouroboros issues first |

## Recommended App-Side Entry Rules

Use these defaults unless the user clearly asks for something else:

1. If the user has only a rough idea, start with `init start`
2. If the user already has a seed path, go straight to `run`
3. If the user references a prior interview or seed, prefer resume/reuse over starting fresh
4. If the runtime seems broken, check `codex login status` before blaming Ouroboros

## Artifact Rules

After each command, the app should know where to look.

### After `init start`

Read:

- latest interview file under `~/.ouroboros/data/`
- latest seed file under `~/.ouroboros/seeds/`

Typical meaning:

- interview file proves the session completed or at least saved progress
- seed file means the app can offer a `run` transition next

### After `run`

Read:

- command output
- generated files in the target workspace
- any runtime logs or evaluation outputs produced by Ouroboros

Typical meaning:

- if code changed, hand control to the policy layer for Route A/B handling
- if the run ended in failure, classify whether it is a runtime problem or a task-quality problem

### After runtime/auth checks

Read:

- `codex login status`
- stderr from a direct `codex exec` probe when needed

Typical meaning:

- if `Not logged in`, fix Codex CLI auth first
- if direct `codex exec` fails, do not treat it as an Ouroboros workflow bug yet

## Minimal Control Loop

For the first version, the Codex app can behave like this:

1. Read the user request
2. Pick one row from the mapping table
3. Run the matching WSL command
4. Read the expected artifact
5. Decide the next transition: stop, resume interview, run seed, or inspect outputs

This keeps the control loop explicit and debuggable.

## Not In Scope Yet

- automatic wrapper MCP commands
- automatic state projection into machine-readable storage
- fully embedded in-app Ouroboros UX
- automatic Route A/B enforcement inside the external runtime itself

## Immediate Follow-Up

After this table, the next useful document is:

- where `Route A/B` hooks into `ouroboros run`
- what the Codex app should own versus what the external engine should own
- how shell-helper control and projection/state-sync should be stabilized before any wrapper MCP work

Current hook note:

- `docs/ROUTE_POLICY_HOOK_IN_RUN.md`

Current ownership note:

- `docs/APP_VS_ENGINE_OWNERSHIP.md`

Current command contract note:

- `docs/APP_CONTROL_COMMAND_CONTRACT.md`

Current shell helper note:

- `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`

Current projection note:

- `docs/PROJECTION_AND_STATE_SYNC.md`

Current roadmap note:

- `docs/DELIVERY_ROADMAP.md`
