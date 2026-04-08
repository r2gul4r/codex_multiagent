# App Default Entrypoint

This note defines the default app-side calling convention for:

- `tools/Invoke-OuroborosRequest.ps1`

The goal is simple:

- treat the request wrapper as the first app entrypoint
- pass natural-language requests first
- let the wrapper resolve the best control-loop action
- reuse latest runtime context from `STATE.md` when explicit inputs are missing

## Why This Exists

The app should not need to think in raw actions first.

Instead, the default app flow should be:

1. take the user's natural-language request
2. call `Invoke-OuroborosRequest.ps1`
3. let the wrapper choose the control-loop action
4. let the existing control loop do the actual runtime work

This keeps the app-side surface small while the external Ouroboros runtime stays unchanged.

## Default Rule

Use `Invoke-OuroborosRequest.ps1` as the normal app entrypoint.

Only call `Invoke-OuroborosControlLoop.ps1` directly when:

- debugging action resolution
- testing one known action in isolation
- bypassing the natural-language wrapper on purpose

## Input Priority

The wrapper resolves inputs in this order:

1. explicit inputs passed by the caller
2. inferred values from `STATE.md` runtime projection
3. request-text fallback

That means:

- explicit `SeedPath` beats `latest_seed_path`
- explicit `InterviewId` beats `interview_id`
- explicit `Goal` beats request-text-as-goal

## Current Inference Rules

When explicit inputs are missing, the wrapper may infer from `STATE.md`.

### Interview continuation

If the request implies interview continuation and `InterviewId` is missing:

- use `interview_id` from `STATE.md`

Typical phrases:

- `continue interview`
- `resume interview`
- `keep the interview going`

### Seed execution

If the request implies seed execution and `SeedPath` is missing:

- use `latest_seed_path` from `STATE.md`

Typical phrases:

- `run the seed`
- `execute the seed`
- `run seed`

### Seed inspection

If the request asks to inspect the seed:

- resolve to `inspect_latest_seed`

Typical phrases:

- `show latest seed`
- `inspect seed`
- `show the latest seed file`

### Runtime health

If the request asks for runtime or login status:

- resolve to `check_runtime_health`

Typical phrases:

- `check runtime health`
- `runtime health`
- `login status`

### Interview start

If the request looks like rough-goal clarification:

- resolve to `start_interview`
- use explicit `Goal` if given, otherwise use the request text

Typical phrases:

- `start interview and clarify the task`
- `start interview`
- `clarify this task`

## Default Call Shape

Typical app-side call:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "run the seed" `
  -PrettyJson
```

This is the preferred default because it lets the wrapper:

- resolve `run_seed`
- infer the latest seed from `STATE.md`
- forward the normalized request into the control loop

## Common Examples

### Start clarification from a rough idea

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "start interview and clarify the task" `
  -PrettyJson
```

### Continue the latest interview without passing an id

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "continue interview" `
  -PrettyJson
```

### Run the latest seed without passing a path

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "run the seed" `
  -PrettyJson
```

### Force a specific seed path

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "run the seed" `
  -SeedPath "/home/leflex/.ouroboros/seeds/seed_d71c3f959713.yaml" `
  -PrettyJson
```

### Resolve only, without running the control loop

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\Invoke-OuroborosRequest.ps1 `
  -Request "check runtime health" `
  -ResolveOnly `
  -PrettyJson
```

## Output Expectation

The wrapper should return:

- `request`
- `resolved_action`
- `resolution_reason`
- `normalized_inputs`
- `status`
- `summary`
- `control_loop` when not in `ResolveOnly`

This makes it easy for the app to:

- show what action was chosen
- show why it was chosen
- inspect the nested control-loop result when needed

## What This Does Not Do

This wrapper does not:

- replace the control loop
- replace the helper
- replace the external Ouroboros runtime
- decide Route A/B policy by itself
- add wrapper MCP behavior

It is only the default request-to-action entrypoint.

## Relationship To Other Docs

- request mapping details: `docs/APP_REQUEST_TO_OUROBOROS_MAPPING.md`
- action contract: `docs/APP_CONTROL_COMMAND_CONTRACT.md`
- route hook note: `docs/ROUTE_POLICY_HOOK_IN_RUN.md`
- shell/helper orchestration: `docs/SHELL_HELPER_AND_CONTROL_LOOP.md`
- external runtime overview: `docs/EXTERNAL_OUROBOROS_PLAN.md`

This note answers one question:

- what should the app call first by default
