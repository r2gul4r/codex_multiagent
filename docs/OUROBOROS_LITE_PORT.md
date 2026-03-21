# Ouroboros-Lite Port Draft

이 문서는 `Q00/ouroboros`의 spec-first workflow 철학을 현재 저장소의 Codex app + multi-agent 운영 규칙에 맞게 거의 그대로 가져오기 위한 초안이다.

이번 슬라이스의 목적은 실제 글로벌 설치나 installer 배선이 아니라, 나중에 파일 단위 구현으로 쪼갤 수 있는 계약을 먼저 고정하는 것이다.

## 목표

- `interview -> seed -> run -> evaluate`를 하나의 운영 모델로 도입한다
- 현재 저장소의 `AGENTS.md`, `STATE.md`, Route A/B 규칙을 최상위 오케스트레이션 계층으로 유지한다
- Codex app 환경에서 병목이 되는 장기 polling, 중첩 오케스트레이션, 툴 종속 문구를 제거한다
- 이후 `~/.codex/skills` / `~/.codex/rules` 자산으로 포팅할 수 있는 초안을 남긴다

## 비목표

- 이번 문서에서 `installer/` 또는 글로벌 Codex 설정을 수정하지 않는다
- Ouroboros의 MCP 서버, background job loop, event store를 그대로 복제하지 않는다
- `ooo evolve`, `ooo qa`, `ooo status`까지 한 번에 들여오지 않는다

## 핵심 원칙

### 1. Spec-first는 유지한다

- 구현 전에 모호함을 줄인다
- 구현 전에 seed를 고정한다
- 실행은 seed를 기준으로만 진행한다
- 평가는 seed 대비 결과로 판단한다

### 2. 오케스트레이션 계층은 하나만 둔다

- 현재 저장소에서 최상위 조정자는 `STATE.md` + Route A/B 규칙이다
- `ooo run`은 별도 장기 실행 엔진이 아니라, 현재 route 체계로 진입시키는 진입점이다
- Route B에서는 현재 저장소 규칙이 우선이며, Ouroboros-lite가 별도 planner/runtime처럼 행동하면 안 된다

### 3. 병목은 phase 경계로 막는다

- `ooo interview`: read-only
- `ooo seed`: spec freeze only
- `ooo run`: implementation phase 진입
- `ooo evaluate`: verification only

## 우리 환경에 맞춘 해석

원본 Ouroboros는 MCP server, background jobs, polling, lineage/evolution까지 포함한 운영체제에 가깝다.
현재 저장소는 이미 다음 자산을 갖고 있다.

- `AGENTS.md`: 전역 행동 규칙
- `STATE.md`: 현재 task, route, writer slot, contract freeze
- `codex_agents/*.toml`: agent 역할 분리
- `codex_rules/default.rules`: destructive command 방지

따라서 이 저장소에서는 Ouroboros를 "새 오케스트레이터"로 들이는 대신, "phase discipline + seed contract"로 흡수하는 게 맞다.

## 제안하는 미래 파일 레이아웃

실제 구현 단계에서는 아래 레이아웃을 권장한다.

```text
codex_rules/
  default.rules
  ouroboros-lite.md

codex_skills/
  ouroboros-interview/
    SKILL.md
  ouroboros-seed/
    SKILL.md
  ouroboros-run/
    SKILL.md
  ouroboros-evaluate/
    SKILL.md

docs/
  OUROBOROS_LITE_PORT.md
```

중요한 점:

- `default.rules`는 그대로 유지한다
- `ouroboros-lite.md`는 workflow command routing만 담당한다
- skill은 네 개만 먼저 가져온다

## Rule Draft

아래 초안은 원본 `ouroboros.md`의 "command routing"만 남기고, Codex app/현재 저장소에 안 맞는 전역 setup 문구를 제거한 버전이다.

```md
# Ouroboros-Lite For This Repository

Use Ouroboros-lite workflow commands when the user is trying to:
- clarify requirements
- freeze a spec before implementation
- run a spec through the repository route system
- evaluate the result against the frozen spec

## Command Routing

When the user types `ooo <command>`, treat it as a workflow command, not casual natural language.

| User input | Meaning |
|-----------|---------|
| `ooo interview ...` | enter requirement-clarification phase |
| `ooo seed` | freeze the current requirement set into a seed |
| `ooo run` | enter implementation through current Route A/B rules |
| `ooo evaluate` | run verification against the frozen seed |

If the request is unrelated to the workflow, handle it normally.

## Guardrails

- Do not auto-install global assets
- Do not start long polling loops
- Do not replace repository route rules
- Do not bypass `STATE.md`
```

## Skill Drafts

### 1. `ooo interview`

목적:

- 구현 전에 요구사항을 구조화한다
- 모호함이 남은 축만 추려 질문한다

입력:

- 사용자의 작업 목표
- 현재 저장소 문맥

출력:

- seed에 들어갈 재료
- 최소 다섯 항목이 고정되어야 종료
  - goal
  - constraints
  - acceptance criteria
  - verification
  - out of scope

규칙:

- read-only만 허용
- 코드 수정 금지
- scope가 이미 충분히 고정되면 질문을 끊고 `ooo seed`로 넘긴다
- 여러 ambiguity track을 유지한다
  - scope
  - constraints
  - outputs
  - verification
  - non-goals

우리 환경용 차이점:

- ToolSearch, AskUserQuestion, plugin update check 제거
- 현재 대화와 저장소 파일 읽기만 사용
- 종료 시 `STATE.md`의 `phase`는 여전히 `explore` 또는 `planning`

### 2. `ooo seed`

목적:

- 인터뷰 결과를 immutable spec으로 고정한다

권장 산출물:

- 별도 `SEED.md` 또는 `SEED.yaml`
- `STATE.md`에는 active seed id/path만 남긴다

최소 필드:

```yaml
goal: ...
constraints:
  - ...
acceptance_criteria:
  - ...
verification:
  - ...
out_of_scope:
  - ...
```

규칙:

- seed가 만들어지면 implementation 전까지 변경하지 않는다
- scope가 바뀌면 기존 seed를 수정하는 대신 새 seed revision을 만든다
- Route A/B 선택 전, seed가 contract freeze의 입력이 된다

우리 환경용 차이점:

- ontology, lineage, ambiguity score는 초기 버전에서 필수가 아니다
- 핵심은 "구현 전에 계약 고정"이다

### 3. `ooo run`

목적:

- seed를 바탕으로 현재 저장소의 route 체계로 구현 phase에 진입시킨다

실행 규칙:

1. seed 존재 확인
2. `STATE.md` current task와 seed가 맞는지 확인
3. Route A/B 재분류
4. route에 맞는 writer/reviewer 규칙 적용
5. 구현 수행
6. 완료 후 `ooo evaluate` 단계로 넘김

병목 방지 규칙:

- background polling loop 금지
- 장시간 실행 엔진을 메인 스레드에 묶지 않는다
- Route B에서는 repository route rules가 절대 우선이다
- `ooo run`이 별도 planner/runtime로 승격되면 안 된다

즉, `ooo run`은 "오케스트레이터 자체"가 아니라 "현재 multi-agent 체계로 들어가는 전환기"다.

### 4. `ooo evaluate`

목적:

- 결과가 seed를 만족하는지 평가한다

권장 단계:

1. Mechanical verification
   - repo verification commands
   - lint, test, build, targeted reproduction
2. Seed compliance review
   - acceptance criteria 충족 여부
   - out-of-scope 침범 여부
   - frozen contract 위반 여부
3. Optional reviewer escalation
   - Route B reviewer 결과 반영
   - high-risk 변경만 추가 심사

규칙:

- 실행과 평가는 분리한다
- "대충 됨"이 아니라 seed 기준으로 pass/fail을 말한다
- Route B에서는 reviewer 결과를 evaluation에 합친다

## 병목 방지 규칙

### A. 인터뷰는 읽기 전용

- 인터뷰 단계가 구현으로 드리프트하면 안 된다
- read-only에서 implementation으로 넘어갈 때는 seed 또는 명시적 실행 전환이 필요하다

### B. seed 없이는 구현 안 한다

- 작은 핫픽스 제외
- 중간 이상 작업은 seed 없이 route 진입 금지

### C. route 체계가 상위 계층이다

- `ooo run`이 Route B worker 배치를 덮어쓰지 않는다
- Ouroboros-lite는 repository route selection에 복무해야 한다

### D. 평가를 실행 뒤로 분리한다

- run 단계에서 QA, polling, evolve를 한 덩어리로 묶지 않는다
- run은 implementation
- evaluate는 verification

### E. 장기 세션 유지 금지

- 원본 Ouroboros의 polling/job loop는 Codex app 컨텍스트를 오래 묶는다
- 우리 환경에서는 상태를 파일과 짧은 검증 단계로 남긴다

## 그대로 가져오지 않을 것

- GitHub release version check
- plugin update flow
- ToolSearch / AskUserQuestion 전제
- global MCP registration from the skill itself
- `ooo run` inside long-lived background orchestration
- immediate evolve/lineage adoption

## 구현 순서 제안

실제 코드 반영은 다음 순서가 안전하다.

1. `codex_rules/ouroboros-lite.md` 추가
2. `codex_skills/ouroboros-interview` 추가
3. `codex_skills/ouroboros-seed` 추가
4. `codex_skills/ouroboros-run` 추가
5. `codex_skills/ouroboros-evaluate` 추가
6. installer가 새 디렉터리를 복사하도록 확장
7. README/guide 문서화

이 순서를 지키면, workflow 규칙을 먼저 고정하고 나서 글로벌 설치/배선을 뒤에 붙일 수 있다.

## 최종 판단

원본 Ouroboros에서 가장 가치 있는 건 다음 둘이다.

- spec-first phase discipline
- evaluation을 별도 단계로 두는 운영 모델

반대로 현재 저장소에서 바로 가져오면 병목이 생기는 부분은 다음이다.

- background job + polling
- tool/runtime 전제 강제
- 현재 multi-agent route보다 위에서 군림하는 별도 오케스트레이터

따라서 현재 저장소의 정답은:

> "원본의 철학과 command surface는 거의 그대로 가져오되,
> 실행 엔진과 session orchestration은 현재 저장소의 Route A/B 체계에 종속시킨다."
