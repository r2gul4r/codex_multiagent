# Area Evaluation Metrics

이 문서는 `docs/GOAL_COMPARISON_AREAS.md` 에서 정의한 핵심 기능 영역별로
"기대 동작이 실제로 충족됐는지" 판정할 수 있는 평가 기준과 측정 항목을 고정한다.

목표는 감상평을 줄이고, 저장소가 각 영역의 성숙도를 같은 기준으로 반복 측정하게 만드는 데 있다.

`docs/GOAL_COMPARISON_AREAS.md` 의 영역 설명과 같이 쓸 때는, 이 문서의 측정 항목을 `criteria` 로 끌어와 한 줄 갭 검토 레코드로 적는다.
즉 실제 검토 단위는 아래처럼 고정한다.

```text
area=<name> | expected=<expected behavior> | criteria=<metric keys> | minimum_gate=<must-pass rules> | current=<observed evidence> | decision=pass|partial|fail | gap=<missing point> | next_action=<follow-up candidate>
```

## 통합 검토 카드 작성 규칙

영역 설명, 기대 동작, 평가 기준이 따로 놀지 않게 아래 순서로 묶어서 적는다.

1. `docs/GOAL_COMPARISON_AREAS.md` 에서 해당 영역의 `기대 동작`을 `expected` 로 복사한다.
2. 이 문서의 `측정 항목` 키를 `criteria` 로 적는다.
3. 이 문서의 `최소 합격선`을 `minimum_gate` 로 축약해 적는다.
4. 실제 문서, 코드, 테스트, 상태 기록에서 찾은 근거를 `current` 로 적는다.
5. 공통 판정 규칙과 최소 합격선 위반 여부를 합쳐 `decision` 을 `pass|partial|fail` 로 고정한다.
6. 부족한 점은 `gap`, 후속 작업 후보는 `next_action` 으로 바로 넘긴다.

이 형식을 쓰면 한 레코드만 봐도 "무슨 영역을 어떤 기대 동작 기준으로 봤고, 어떤 측정 항목에서 갭이 났는지" 바로 추적된다.

## 영역별 빠른 매핑 표

| 영역 키 | `expected` 에 넣을 내용 | `criteria` 에 넣을 키 | `minimum_gate` 요약 |
| --- | --- | --- | --- |
| `goal_gate` | 작업이 구현 전에 프로젝트 목표와 승인 경계를 먼저 통과한다 | `goal_gate_rule_present`, `task_reclassification_logged`, `non_goal_or_approval_paths_explicit` | `goal_gate_rule_present=pass`, 나머지 2개 중 1개 이상 `pass`, 현재 작업 대조 흔적 필수 |
| `gap_detection` | 품질 부족과 기능 공백을 근거 기반으로 분리해 기록한다 | `evidence_sources_defined`, `quality_vs_feature_split`, `evidence_linkability` | 셋 다 `partial` 이상, split/linkability 실패 금지 |
| `proposal_prioritization` | 후보를 공통 축과 승인 경계 기준으로 정렬한다 | `shared_axes_defined`, `ranking_rule_defined`, `approval_boundary_defined` | 축 정의와 정렬 규칙은 `pass` 필수 |
| `contract_execution` | 계약과 쓰기 범위를 고정한 뒤에만 구현한다 | `contract_freeze_fields_present`, `spec_first_path_defined`, `reclassification_on_scope_shift` | 셋 다 `partial` 이상, freeze 필드 실패 금지 |
| `verification_regression` | 완료 전에 검증 엔트리포인트와 회귀 확인을 거친다 | `verification_entrypoints_present`, `verification_plan_logged`, `goal_plus_verification_completion_gate` | 엔트리포인트 `pass`, 나머지 `partial` 이상 |
| `reversibility_traceability` | 기록과 커밋 단위로 복구 가능성을 남긴다 | `state_and_log_paths_present`, `append_only_or_history_safe`, `commit_reversibility_rule_present` | 셋 다 `partial` 이상, commit 규칙 실패 금지 |

## 공통 판정 규칙

모든 영역은 아래 다섯 축으로 같이 본다.

- `coverage`: 해당 영역에 필요한 규칙, 문서, 상태 기록, 검증 엔트리포인트가 실제로 존재하나
- `clarity`: 사람이 다음 행동을 오해 없이 고를 만큼 판정 기준이 명확하나
- `operability`: 현재 저장소 흐름 안에서 실제 실행 가능한가
- `regression_control`: 기존 기능 회귀나 절차 누락을 막는 장치가 있나
- `reversibility`: 변경 이유와 결과를 기록하고 복구 가능한가

각 축은 아래 셋 중 하나로 기록한다.

- `pass`: 기대 동작을 안정적으로 충족한다
- `partial`: 뼈대는 있으나 누락이나 모호성이 남아 있다
- `fail`: 핵심 근거나 실행 경로가 없다

권장 기록 형식:

```text
area=<name> | coverage=pass|partial|fail | clarity=pass|partial|fail | operability=pass|partial|fail | regression_control=pass|partial|fail | reversibility=pass|partial|fail | decision=pass|partial|fail
```

최종 판정은 아래 순서로 한다.

1. `coverage`, `clarity`, `operability` 중 하나라도 `fail` 이면 영역 전체 판정은 `fail`
2. `regression_control`, `reversibility` 중 하나라도 `fail` 이면 영역 전체 판정은 최소 `partial`
3. `partial` 이 2개 이상이면 영역 전체 판정은 `partial`
4. 전 항목이 `pass` 일 때만 영역 전체 판정을 `pass`

## 1. 목표 고정과 방향성 게이트

### 판정 질문

- 새 작업이 시작될 때 프로젝트 목표와 현재 태스크 비교가 먼저 일어나나
- 목표에서 벗어난 제안, 구조 변경, 승인 필요 항목이 초기에 드러나나

### 측정 항목

- `goal_gate_rule_present`
  - `AGENTS.md`, `STATE.md`, 관련 가이드에 목표 확인 후 실행 규칙이 있는지
- `task_reclassification_logged`
  - `STATE.md` 에 현재 태스크, selection reason, contract freeze 재분류 흔적이 남는지
- `non_goal_or_approval_paths_explicit`
  - 비목표, 승인 필요 영역, 구조 변경 예외 규칙이 명시돼 있는지

### 최소 합격선

- 세 항목 중 `goal_gate_rule_present` 는 반드시 `pass`
- 나머지 두 항목 중 최소 하나 이상 `pass`
- 현재 작업 기록에서 목표 대조 흔적이 없으면 전체 판정은 `fail`

### 기록 예시

```text
area=goal_gate | coverage=pass | clarity=pass | operability=pass | regression_control=partial | reversibility=pass | decision=pass
```

## 2. 부족한 점 탐지와 근거 수집

### 판정 질문

- 저장소가 품질 부족과 기능 공백을 근거 기반으로 분리해 적을 수 있나
- 개선 후보가 관찰 결과와 직접 연결되나

### 측정 항목

- `evidence_sources_defined`
  - 코드, 문서, 테스트, 규칙 중 무엇을 읽어 갭을 찾는지 명시돼 있는지
- `quality_vs_feature_split`
  - 품질 이슈와 기능 공백을 다른 바구니로 기록하는 형식이 있는지
- `evidence_linkability`
  - 갭 기록이 파일, 테스트, 문서, 규칙 같은 구체 근거에 연결되는지

### 최소 합격선

- 세 항목 모두 `partial` 이상
- `quality_vs_feature_split` 또는 `evidence_linkability` 가 `fail` 이면 전체 판정은 `fail`
- 근거 없는 아이디어만 있고 관찰 경로가 없으면 `coverage=fail`

### 기록 예시

```text
area=gap_detection | coverage=pass | clarity=partial | operability=pass | regression_control=partial | reversibility=pass | decision=partial
```

## 3. 개선 후보 제안과 우선순위화

### 판정 질문

- 후보가 목표 부합, 위험, 구조 영향, 복구 가능성 기준으로 비교되나
- 기능 후보와 리팩터링 후보가 같은 후보 카드와 같은 점수/등급 규칙으로 정렬되나
- 자동 수행 가능한 변경과 승인 필요한 변경이 분리되나

### 측정 항목

- `shared_axes_defined`
  - `goal_alignment`, `gap_relevance`, `safety`, `reversibility`, `structural_impact`, `leverage` 같은 공통 축이 있는지
- `ranking_rule_defined`
  - 기능 후보와 리팩터링 후보를 같은 포맷으로 비교할 `common_score`, `specific_score`, `priority_score`, `priority_grade` 같은 점수화 또는 등급화 규칙이 있는지
- `approval_boundary_defined`
  - 구조 변경/승인 필요 항목을 자동 수행 후보에서 분리하는 기준이 있는지

### 최소 합격선

- `shared_axes_defined` 와 `ranking_rule_defined` 는 반드시 `pass`
- `approval_boundary_defined` 가 `partial` 이하면 전체 판정은 최대 `partial`
- 후보 종류마다 다른 포맷만 있고 공통 비교 규칙이 없으면 `clarity=fail`
- 우선순위 규칙 없이 후보만 나열되면 `clarity=fail`

### 기록 예시

```text
area=proposal_prioritization | coverage=pass | clarity=pass | operability=pass | regression_control=pass | reversibility=partial | decision=pass
```

## 4. 계약 고정과 안전한 실행

### 판정 질문

- 구현 전에 변경 계약, 쓰기 범위, 검증 계획이 먼저 고정되나
- 계약이 바뀌면 상태 재분류 후에만 실행이 이어지나

### 측정 항목

- `contract_freeze_fields_present`
  - `STATE.md` 에 `contract_freeze`, `write_sets`, `writer_slot`, `execution_topology` 가 남는지
- `spec_first_path_defined`
  - `clarify -> freeze -> implement -> verify` 같은 native STATE.md contract flow가 문서화돼 있는지
- `reclassification_on_scope_shift`
  - 계약 변화나 범위 확장 시 재분류 규칙이 명시돼 있는지

### 최소 합격선

- 세 항목 모두 `partial` 이상
- `contract_freeze_fields_present` 가 `fail` 이면 전체 판정은 `fail`
- 재분류 규칙이 없으면 `operability` 는 최대 `partial`

### 기록 예시

```text
area=contract_execution | coverage=pass | clarity=pass | operability=pass | regression_control=pass | reversibility=pass | decision=pass
```

## 5. 검증과 회귀 방지

### 판정 질문

- 완료 전에 회귀를 확인할 실제 검증 엔트리포인트가 있나
- 완료 판정이 구현 완료가 아니라 목표 부합과 검증 통과를 같이 보나

### 측정 항목

- `verification_entrypoints_present`
  - `make lint`, `make test`, `make check` 같은 엔트리포인트가 존재하는지
- `verification_plan_logged`
  - 상태 기록이나 작업 기록에 검증 계획과 실행 결과가 남는지
- `goal_plus_verification_completion_gate`
  - 완료 기준이 목표 부합과 검증 통과를 함께 요구하는지

### 최소 합격선

- `verification_entrypoints_present` 는 반드시 `pass`
- 나머지 두 항목은 `partial` 이상
- 검증 명령은 있는데 완료 판정과 연결되지 않으면 전체 판정은 최대 `partial`

### 기록 예시

```text
area=verification_regression | coverage=pass | clarity=pass | operability=pass | regression_control=pass | reversibility=partial | decision=pass
```

## 6. 기록, 커밋, 복구 가능성

### 판정 질문

- 모든 변경이 기록, diff, 커밋 단위로 복구 가능하게 남나
- 오류나 검증 누락도 숨기지 않고 추적되나

### 측정 항목

- `state_and_log_paths_present`
  - `STATE.md`, `MULTI_AGENT_LOG.md`, `ERROR_LOG.md` 같은 기록 경로가 정의돼 있는지
- `append_only_or_history_safe`
  - 로그/상태 기록이 append-only 또는 이력 보존 원칙을 따르는지
- `commit_reversibility_rule_present`
  - 작업 단위 커밋, 변경 복구 가능성, 검증 누락 보고 규칙이 명시돼 있는지

### 최소 합격선

- 세 항목 모두 `partial` 이상
- `commit_reversibility_rule_present` 가 `fail` 이면 전체 판정은 `fail`
- 기록 경로는 있지만 작업 단위 복구 규칙이 없으면 `reversibility=partial`

### 기록 예시

```text
area=reversibility_traceability | coverage=pass | clarity=pass | operability=partial | regression_control=pass | reversibility=pass | decision=pass
```

## 빠른 사용 절차

1. 먼저 평가할 영역 하나를 고른다.
2. 해당 영역의 측정 항목을 실제 문서, 상태 기록, 검증 엔트리포인트와 대조한다.
3. 다섯 공통 축을 `pass|partial|fail` 로 적는다.
4. 최소 합격선 위반 여부를 확인해 `decision` 을 고정한다.
5. `partial` 또는 `fail` 항목은 다음 개선 후보의 직접 근거로 넘긴다.

이 문서가 있어야 각 기능 영역의 기대 동작을 "설명"이 아니라 "판정" 기준으로 쓸 수 있다.
