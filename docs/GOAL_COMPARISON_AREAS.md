# Goal Comparison Areas

이 문서는 현재 저장소를 프로젝트 목표와 비교할 때 기준으로 삼아야 하는 핵심 기능 영역과 각 영역의 범위를 고정한다.

프로젝트 목표는 다음 한 줄로 압축한다.

- 저장소가 자기 부족한 코드 품질과 기능 공백을 스스로 찾고, 기존 프로젝트 방향성 안에서 개선안을 제안·구현·검증하며 재귀적으로 더 나아지게 만든다

이 기준 문서는 이후 개선 제안이나 구현이 "프로젝트 목표 부합"인지 먼저 거르는 1차 필터로 사용한다.

## 사용 원칙

- 어떤 개선안이든 먼저 아래 기능 영역 중 어디를 강화하는지 연결돼야 한다
- 어느 영역에도 직접 연결되지 않으면 우선순위를 낮추거나 제외한다
- 구조 변경은 어느 영역에서도 기본 해법이 아니다
- 각 영역 평가는 `존재 여부`, `명확성`, `실행 가능성`, `회귀 방지력`, `복구 가능성`으로 본다
- 실제 판정할 때는 `docs/AREA_EVALUATION_METRICS.md` 의 영역별 측정 항목과 최소 합격선을 같이 쓴다

## 영역별 갭 검토 워크시트

프로젝트 목표 대비 코드베이스 갭을 실제로 검토할 때는 아래 한 줄 구조를 기본 레코드로 쓴다.
핵심은 `기능 영역 -> 기대 동작 -> 평가 기준 -> 현재 관찰 -> 갭 판단 -> 다음 액션` 순서를 한 레코드에 묶는 것이다.

```text
area=<name> | expected=<expected behavior> | criteria=<metric keys> | minimum_gate=<must-pass rules> | current=<observed docs/code/tests/state> | decision=pass|partial|fail | gap=<missing or weak point> | next_action=<follow-up candidate>
```

아래 표는 각 기능 영역을 이 레코드 형식으로 바로 옮길 수 있게 고정한 매핑이다.

| 기능 영역 | 기대 동작 요약 | 평가 기준 키 | 최소 게이트 |
| --- | --- | --- | --- |
| 목표 고정과 방향성 게이트 | 구현 전에 목표 부합과 승인 필요 여부를 먼저 판정한다 | `goal_gate_rule_present`, `task_reclassification_logged`, `non_goal_or_approval_paths_explicit` | `goal_gate_rule_present=pass`, 나머지 2개 중 1개 이상 `pass`, 현재 작업 기록에 목표 대조 흔적 필수 |
| 부족한 점 탐지와 근거 수집 | 품질 부족과 기능 공백을 근거 기반으로 분리해 기록한다 | `evidence_sources_defined`, `quality_vs_feature_split`, `evidence_linkability` | 셋 다 `partial` 이상, `quality_vs_feature_split` 또는 `evidence_linkability` 가 `fail` 이면 실패 |
| 개선 후보 제안과 우선순위화 | 후보를 목표 기여와 위험 기준으로 정렬하고 승인 경계를 분리한다 | `shared_axes_defined`, `ranking_rule_defined`, `approval_boundary_defined` | `shared_axes_defined=pass`, `ranking_rule_defined=pass`, `approval_boundary_defined` 가 `partial` 이하면 최대 `partial` |
| 계약 고정과 안전한 실행 | 계약과 쓰기 범위를 먼저 고정한 뒤 작은 단위로 실행한다 | `contract_freeze_fields_present`, `spec_first_path_defined`, `reclassification_on_scope_shift` | 셋 다 `partial` 이상, `contract_freeze_fields_present=fail` 이면 실패 |
| 검증과 회귀 방지 | 완료 전에 검증 엔트리포인트와 회귀 확인을 거친다 | `verification_entrypoints_present`, `verification_plan_logged`, `goal_plus_verification_completion_gate` | `verification_entrypoints_present=pass`, 나머지 둘은 `partial` 이상 |
| 기록, 커밋, 복구 가능성 | 모든 변경을 기록과 커밋 단위로 추적하고 복구 가능하게 남긴다 | `state_and_log_paths_present`, `append_only_or_history_safe`, `commit_reversibility_rule_present` | 셋 다 `partial` 이상, `commit_reversibility_rule_present=fail` 이면 실패 |

빠른 사용 순서는 이렇다.

1. 영역 하나를 고른다.
2. 아래 영역 설명에서 `기대 동작`을 그대로 `expected` 에 넣는다.
3. 표에 적힌 `평가 기준 키`와 `최소 게이트`를 `criteria`, `minimum_gate` 에 넣는다.
4. 실제 문서, 코드, 테스트, 상태 기록을 읽고 `current`, `decision`, `gap`, `next_action` 을 채운다.
5. `partial` 또는 `fail` 은 다음 개선 후보의 직접 근거로 넘긴다.

## 핵심 기능 영역

### 1. 목표 고정과 방향성 게이트

#### 역할

- 작업 시작 전에 저장소의 운영 목표와 비목표를 고정한다
- 제안이나 구현이 기존 방향성에서 벗어나는지 먼저 거른다

#### 범위 포함

- `STATE.md`의 현재 태스크와 프로젝트 목표의 정렬 여부
- 목표 부합 여부를 먼저 판정하는 규칙
- 비목표, 승인 필요 영역, 구조 변경 금지 같은 상위 가드레일

#### 범위 제외

- 실제 기능 구현 세부 내용
- 목표 판정 이후의 상세 작업 분배 최적화

#### 비교 질문

- 이 저장소는 작업 전에 "무엇이 프로젝트 목표에 맞는가"를 명시적으로 판정할 수 있나
- 목표와 어긋나는 제안이 자동 개선 후보에서 걸러지나

#### 기대 동작

- 새 작업이 들어오면 구현 전에 현재 태스크와 프로젝트 목표를 대조하고, 목표 부합 여부를 먼저 판정한다
- 목표에서 벗어난 제안은 구현 후보가 아니라 보류 또는 제외 대상으로 기록된다
- 구조 변경, 승인 필요 영역, 비목표는 초기에 드러나야 한다

#### 현재 구현에서 확인할 증거

- `AGENTS.md`, `STATE.md`, 관련 가이드 문서에 목표 게이트와 재분류 규칙이 명시돼 있는지 본다
- 작업 시작 규칙이 "바로 수정"이 아니라 "목표/현재 태스크 확인 후 분류" 순서를 강제하는지 본다
- 실제 상태 기록에 현재 태스크, selection reason, contract freeze가 남는지 본다

#### 비교 기록 포맷

```text
area=goal_gate | expected=task is goal-checked before implementation | current=<observed rule/doc/state> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=goal_gate | expected=task is goal-checked before implementation | criteria=goal_gate_rule_present,task_reclassification_logged,non_goal_or_approval_paths_explicit | minimum_gate=goal_gate_rule_present=pass; one of the other two=pass; current task trace required | current=STATE.md reclassification + AGENTS.md goal gate rule present | decision=pass | gap=none | next_action=keep using the same gate for later AC review
```

### 2. 부족한 점 탐지와 근거 수집

#### 역할

- 코드 품질 문제와 기능 공백을 감으로 찍지 않고 근거 기반으로 식별한다
- 테스트, 문서, 규칙, 현재 구현 상태를 읽어 부족한 점 목록으로 바꾼다

#### 범위 포함

- 기존 코드/문서/테스트를 읽고 갭을 식별하는 절차
- 품질 문제와 기능 공백을 구분해 기록하는 기준
- 개선 후보에 근거를 붙이는 방식

#### 범위 제외

- 아직 근거 없는 아이디어 브레인스토밍
- 저장소 목표와 무관한 "좋아 보이는" 일반 개선안

#### 비교 질문

- 이 저장소는 자기 결함을 찾을 때 근거를 남기나
- 품질 이슈와 기능 공백을 같은 바구니에 섞지 않고 분리하나

#### 기대 동작

- 저장소는 코드, 문서, 테스트, 규칙을 읽은 뒤 부족한 점을 근거와 함께 식별해야 한다
- 품질 부족과 기능 공백은 구분된 항목으로 남아야 한다
- 개선 후보는 관찰 근거 없이 생성되지 않아야 한다

#### 현재 구현에서 확인할 증거

- 비교 문서, 정렬 프레임워크, 상태 기록에 "무엇을 읽었고 무엇이 비어 있는지" 남기는 형식이 있는지 본다
- 개선 근거가 특정 파일, 테스트, 규칙, 문서와 연결되는지 본다
- "좋아 보이는 아이디어"가 아니라 "현재 구현에서 확인된 결손"으로 설명되는지 본다

#### 비교 기록 포맷

```text
area=gap_detection | expected=evidence-backed gap list separated by quality vs feature | current=<observed evidence path> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=gap_detection | expected=evidence-backed gap list separated by quality vs feature | criteria=evidence_sources_defined,quality_vs_feature_split,evidence_linkability | minimum_gate=all metrics partial+; split/linkability cannot fail | current=<observed comparison docs, test refs, rule refs> | decision=pass|partial|fail | gap=<missing evidence path or weak split> | next_action=<add source mapping or split format>
```

### 3. 개선 후보 제안과 우선순위화

#### 역할

- 탐지한 부족한 점을 실제 작업 후보로 변환한다
- 프로젝트 목표 기여도, 안정성, 복구 가능성을 기준으로 실행 순서를 정한다

#### 범위 포함

- 개선 후보를 작은 작업 단위로 나누는 방식
- 목표 부합, 회귀 위험, 복구 가능성, 구조 영향도를 함께 평가하는 기준
- 승인 필요 변경과 자동 수행 가능한 변경의 구분

#### 범위 제외

- 구현 그 자체
- 우선순위 근거 없이 한 번에 큰 덩어리로 밀어 넣는 작업 방식

#### 비교 질문

- 후보 작업이 목표 기여도 기준으로 정렬되나
- 구조 변경이 예외 취급되고 승인 조건이 분명한가

#### 기대 동작

- 탐지된 부족한 점은 작은 작업 후보로 바뀌고, 각 후보는 목표 기여도 기준으로 비교돼야 한다
- 기능 후보와 리팩터링 후보는 같은 후보 카드 포맷과 같은 점수/등급 규칙으로 한 큐에서 비교돼야 한다
- 구조 영향, 회귀 위험, 복구 가능성, 목표 부합 여부가 함께 기록돼야 한다
- 승인 필요 변경과 자동 수행 가능한 변경이 구분돼야 한다

#### 현재 구현에서 확인할 증거

- `docs/GOAL_ALIGNMENT_FRAMEWORK.md` 같은 공통 평가 축 문서가 실제 비교 기준으로 존재하는지 본다
- 후보 평가에 `goal_alignment`, `gap_relevance`, `safety`, `reversibility`, `structural_impact`, `common_score`, `specific_score`, `priority_grade` 같은 필드가 남는지 본다
- 구조 변경을 기본 해법으로 밀지 않고 예외 승인 조건으로 다루는지 본다

#### 비교 기록 포맷

```text
area=proposal_prioritization | expected=candidates ranked by goal-aligned evaluation axes | current=<observed rubric or log> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=proposal_prioritization | expected=candidates ranked by goal-aligned evaluation axes | criteria=shared_axes_defined,ranking_rule_defined,approval_boundary_defined | minimum_gate=shared_axes_defined=pass; ranking_rule_defined=pass | current=<observed framework/log rubric> | decision=pass|partial|fail | gap=<missing ranking or approval boundary> | next_action=<define ranking order or approval split>
```

### 4. 계약 고정과 안전한 실행

#### 역할

- 선택된 개선안을 드리프트 없이 구현 가능하도록 계약을 고정한다
- 현재 구조를 유지하면서 작은 단위로 실행한다

#### 범위 포함

- `interview -> seed -> run -> evaluate` 같은 spec-first 흐름
- `STATE.md`, `contract_freeze`, `write_sets`, `execution_topology`를 통한 실행 통제
- 작은 기능 추가와 리팩터링의 안전한 수행

#### 범위 제외

- 구조를 뒤엎는 재설계
- 계약 없이 바로 수정에 들어가는 즉흥 작업

#### 비교 질문

- 구현 전에 변경 계약과 범위가 고정되나
- 실행 방식이 현재 프로젝트 구조를 존중하나

#### 기대 동작

- 구현 전에는 변경 범위, 소유 파일, 검증 방법이 먼저 고정돼야 한다
- 작업은 현재 구조를 유지하는 작은 단위로 잘려야 한다
- 계약이 바뀌면 상태를 다시 분류하고 그 뒤에만 구현이 계속돼야 한다

#### 현재 구현에서 확인할 증거

- `STATE.md`에 `contract_freeze`, `write_sets`, `execution_topology`, `writer_slot`이 남는지 본다
- `interview -> seed -> run -> evaluate` 같은 흐름이 문서화돼 있는지 본다
- 구조 변경 금지와 예외 승인 규칙이 실행 단계 문서와 충돌 없이 이어지는지 본다

#### 비교 기록 포맷

```text
area=contract_execution | expected=implementation starts only after contract freeze and bounded write scope | current=<observed state fields/rules> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=contract_execution | expected=implementation starts only after contract freeze and bounded write scope | criteria=contract_freeze_fields_present,spec_first_path_defined,reclassification_on_scope_shift | minimum_gate=all metrics partial+; contract_freeze_fields_present cannot fail | current=<observed STATE fields and workflow docs> | decision=pass|partial|fail | gap=<missing freeze field or reclassification rule> | next_action=<add missing state field or workflow step>
```

### 5. 검증과 회귀 방지

#### 역할

- 변경이 기존 기능을 깨지 않았는지 확인한다
- 완료 판정을 "목표 부합 + 검증 통과" 기준으로 묶는다

#### 범위 포함

- 기존 테스트 스위트, lint/check, 리뷰 절차
- acceptance criteria 기준의 완료 판정
- 회귀 위험 확인과 검증 누락 보고

#### 범위 제외

- 검증 없는 자기 선언식 완료
- 프로젝트 목표와 무관한 과도한 테스트 확장

#### 비교 질문

- 이 저장소는 완료 전에 회귀를 확인할 수단이 있나
- 완료 판정이 단순 구현 여부가 아니라 목표 부합까지 보나

#### 기대 동작

- 변경 후에는 기존 테스트/체크와 문서 리뷰를 통해 회귀 여부를 확인해야 한다
- 완료 판정은 구현 완료가 아니라 목표 부합과 검증 통과를 함께 본다
- 검증 누락이나 미실행 항목은 숨기지 않고 기록해야 한다

#### 현재 구현에서 확인할 증거

- `Makefile`, 테스트 스위트, 문서 규칙에 `lint`, `test`, `check` 같은 검증 엔트리포인트가 있는지 본다
- 완료 직전 검증 계획과 실제 실행 결과가 상태나 작업 기록에 남는지 본다
- 평가 문서가 "좋아 보임"이 아니라 "검증 가능성"을 우선하는지 본다

#### 비교 기록 포맷

```text
area=verification_regression | expected=completion requires explicit verification and regression check | current=<observed commands/results> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=verification_regression | expected=completion requires explicit verification and regression check | criteria=verification_entrypoints_present,verification_plan_logged,goal_plus_verification_completion_gate | minimum_gate=verification_entrypoints_present=pass; other metrics partial+ | current=<observed Makefile targets and task logs> | decision=pass|partial|fail | gap=<missing completion gate or execution trace> | next_action=<wire logs to verification gate>
```

### 6. 기록, 커밋, 복구 가능성

#### 역할

- 모든 변경을 추적 가능하고 되돌릴 수 있게 남긴다
- 자동 개선 루프가 사고를 내도 복구 가능한 상태를 유지한다

#### 범위 포함

- 작업 단위 기록
- append-only 로그와 상태 기록
- 작업 단위 커밋과 변경 이력 추적

#### 범위 제외

- 기록 없이 바로 덮어쓰기
- 복구 불가능한 일괄 수정

#### 비교 질문

- 변경 이유와 결과가 나중에 추적 가능한가
- 각 작업이 독립적으로 복구 가능한 단위로 남나

#### 기대 동작

- 모든 작업은 상태 기록, 변경 로그, 커밋 단위로 추적 가능해야 한다
- 변경은 작은 복구 단위로 남아야 하고, 이유와 결과가 이어져야 한다
- 오류나 검증 문제도 append-only 형태로 남겨야 한다

#### 현재 구현에서 확인할 증거

- `CHANGELOG.md`, `ERROR_LOG.md`, `STATE.md`에 작업 흔적과 상태 변화가 누적되는지 본다
- Git 워크플로우 규칙이 작업 단위 커밋을 요구하는지 본다
- 복구 가능성을 위해 변경 범위와 이유가 최소한 문서나 커밋 메시지 수준에서 분리되는지 본다

#### 비교 기록 포맷

```text
area=reversibility_traceability | expected=every change is traceable and recoverable via logs and commit units | current=<observed logs/commit rules> | status=match|partial|missing
```

#### 통합 검토 카드 예시

```text
area=reversibility_traceability | expected=every change is traceable and recoverable via logs and commit units | criteria=state_and_log_paths_present,append_only_or_history_safe,commit_reversibility_rule_present | minimum_gate=all metrics partial+; commit_reversibility_rule_present cannot fail | current=<observed STATE, ERROR_LOG, CHANGELOG, git rules> | decision=pass|partial|fail | gap=<missing commit or log guard> | next_action=<tighten logging or commit rule>
```

#### 비교 기록 포맷

```text
area=traceability_reversibility | expected=every change is logged and recoverable by work unit | current=<observed logs/commit rule> | status=match|partial|missing
```

### 7. 재귀적 개선 루프

#### 역할

- 한 번의 수정으로 끝내지 않고, 검증 결과를 다음 탐지와 제안으로 되먹임한다
- 저장소가 자기 상태를 읽고 다음 개선 사이클을 이어갈 수 있게 만든다

#### 범위 포함

- `evaluate` 결과를 다음 개선 후보로 연결하는 흐름
- 해결된 문제와 남은 공백을 다음 사이클 입력으로 전환하는 방식
- bounded repair loop 같은 반복 개선 메커니즘

#### 범위 제외

- 무한 루프성 오케스트레이션
- 목표 기준 없이 반복만 하는 자동화

#### 비교 질문

- 검증 결과가 다음 작업 선정으로 이어지나
- 반복 개선이 프로젝트 방향성을 계속 유지하나

#### 기대 동작

- 한 번의 수정 결과는 다음 탐지와 제안 단계의 입력으로 다시 들어가야 한다
- 완료/미완료, 남은 공백, 검증 결과가 다음 사이클 후보 선정 기준으로 이어져야 한다
- 반복 개선은 무한 자동화가 아니라 방향성 게이트 안에서 제한적으로 돌아야 한다

#### 현재 구현에서 확인할 증거

- `evaluate`나 완료 판단 결과를 다음 후보 선정 문서/상태 기록으로 연결하는 규칙이 있는지 본다
- bounded repair loop, next task, remaining gaps 같은 개념이 드러나는지 본다
- 반복 개선 규칙이 목표 부합 게이트보다 앞서지 않는지 본다

#### 비교 기록 포맷

```text
area=recursive_loop | expected=verification output feeds the next scoped improvement cycle | current=<observed loop hook> | status=match|partial|missing
```

## 영역 간 관계

- 1은 진입 게이트다. 목표에서 벗어나면 뒤 단계로 보내면 안 된다
- 2와 3은 탐지와 선택 단계다. 무엇을 고칠지 여기서 결정한다
- 4는 실행 단계다. 선택된 작업만 계약 고정 후 구현한다
- 5와 6은 안전장치다. 깨지지 않았는지 보고, 되돌릴 수 있게 남긴다
- 7은 결과를 다음 사이클로 연결하는 루프다

## 비교 절차

각 영역은 아래 순서로 비교한다.

1. 해당 영역의 `기대 동작`을 읽는다.
2. 저장소의 현재 문서, 규칙, 테스트, 상태 기록에서 실제 증거를 찾는다.
3. `match`, `partial`, `missing` 중 하나로 판정한다.
4. `partial` 또는 `missing`이면 어떤 근거가 비어 있는지 한 줄로 남긴다.

권장 최소 기록은 아래 형태다.

```text
area=<name> | expected=<target behavior> | current=<observed implementation> | status=match|partial|missing | gap=<missing proof or behavior>
```

## 최소 합격선

아래 항목이 모두 충족돼야 이 저장소가 "목표 대비 최소 기반은 있다"고 본다.

- 목표 부합 여부를 먼저 거르는 명시 규칙이 있다
- 부족한 점을 근거 기반으로 찾는 절차가 있다
- 개선 후보를 우선순위화하는 기준이 있다
- 구현 전에 계약을 고정하는 흐름이 있다
- 기존 테스트/검증 체계로 회귀를 확인할 수 있다
- 변경 기록과 복구 단위가 남는다
- 검증 결과가 다음 개선으로 이어지는 루프가 있다

## 이번 AC의 산출물 정의

- Sub-AC 1 완료 기준은 "핵심 기능 영역 목록이 있고, 각 영역에 포함/제외 범위와 비교 질문이 정의되어 있음"이다
- Sub-AC 2 완료 기준은 "각 핵심 기능 영역마다 현재 구현과 직접 대조 가능한 기대 동작과 확인 증거 형식이 정의되어 있음"이다
- 이후 AC는 이 문서를 기준으로 현재 저장소의 공백을 측정하고 우선순위를 정해야 한다
