# Goal Alignment Framework

이 문서는 현재 저장소가 스스로 코드 품질 부족과 기능 공백을 찾고, 프로젝트 방향성 안에서 개선안을 제안·구현·검증하도록 만들기 위한 상위 판단 기준을 고정한다.

아래 원칙과 평가 축은 둘 다 같은 기준으로 쓴다.

- 새 기능 후보 평가
- 리팩터링 후보 평가
- 자가 개선 루프의 계획 단계 1차 필터

## 1. 저장소 방향성에서 추출한 고정 목표

현재 저장소의 목표는 "아무 개선이나 많이 하는 것"이 아니다.
고정해야 하는 목표는 아래 다섯 개다.

1. 프로젝트의 기존 방향성과 목표를 먼저 읽고 그 범위 안에서만 개선한다.
2. 저장소가 스스로 부족한 코드 품질과 기능 공백을 식별할 수 있어야 한다.
3. 식별된 공백은 실제 제안과 구현으로 연결돼야 한다.
4. 모든 변경은 테스트, 기록, 커밋으로 복구 가능해야 한다.
5. 구조 변경은 기본 금지이며, 꼭 필요할 때만 예외로 다룬다.

즉 이 저장소의 "자율성"은 무제한 생성이 아니라, 방향성 고정 + 안전한 개선 실행 쪽에 있다.

## 2. 상위 원칙

### 원칙 A. Goal-locked autonomy

자가 개선은 항상 프로젝트 목표에 묶여 있어야 한다.
후보가 흥미롭더라도 현재 프로젝트 목표와 직접 연결되지 않으면 잘라낸다.

### 원칙 B. Gap-first prioritization

우선순위는 "멋져 보이는 기능"이 아니라 실제 부족함에 둔다.
코드 품질 부족, 검증 공백, 사용자 흐름 결손, 운영상 반복 마찰처럼 현재 결핍이 먼저다.

### 원칙 C. Minimal structural disruption

구조를 갈아엎는 방식으로 문제를 푸는 걸 기본값으로 두지 않는다.
기존 구조 안에서 해결 가능한 후보를 우선하고, 구조 변경은 마지막 수단으로 취급한다.

### 원칙 D. Verification before victory

개선 제안은 구현 가능성보다 먼저 검증 가능성이 있어야 한다.
완료 판정은 "좋아 보임"이 아니라 테스트, 리뷰, 회귀 확인으로 닫힌다.

### 원칙 E. Reversible change units

모든 개선은 기록과 커밋 단위로 되돌릴 수 있어야 한다.
후보 자체가 복구 불가능한 큰 덩어리를 요구하면 우선순위를 낮추거나 쪼갠다.

### 원칙 F. Plan-stage goal gate

계획 단계에서 프로젝트 목표 부합 여부를 먼저 거른다.
이 게이트를 통과하지 못한 후보는 구현 난이도나 기대 효율이 높아도 진행하지 않는다.

## 3. 공통 평가 축

후보가 기능 추가든 리팩터링이든 아래 여섯 축으로 같은 방식으로 본다.

### 3.1 Goal alignment

질문:

- 이 후보가 현재 프로젝트 목표를 더 직접적으로 달성하게 만드나
- 기존 방향성을 강화하나, 아니면 옆길로 새게 만드나

판정:

- `pass`: 프로젝트 목표와 직접 연결된다
- `borderline`: 간접 효과는 있으나 직접 연결은 약하다
- `fail`: 목표와 직접 관계없거나 방향성을 흐린다

### 3.2 Gap relevance

질문:

- 이 후보가 현재 드러난 품질 부족이나 기능 공백을 실제로 메우나
- 문제의 원인에 닿나, 아니면 표면 증상만 만지나

판정:

- `high`: 현재 공백을 직접 메운다
- `medium`: 보조 효과는 있으나 핵심 공백과 거리가 있다
- `low`: 공백 식별 결과와 연결이 약하다

### 3.3 Safety and regression control

질문:

- 기존 기능 회귀 없이 넣을 수 있나
- 테스트, 리뷰, 검증 경로가 이미 있거나 쉽게 붙나

판정:

- `safe`: 기존 검증 체계 안에서 다룰 수 있다
- `guarded`: 추가 검증이 필요하지만 통제 가능하다
- `risky`: 회귀 통제가 약하거나 영향 범위가 불명확하다

### 3.4 Reversibility and traceability

질문:

- 변경 이유, 범위, 결과를 기록으로 남길 수 있나
- 작업 단위 커밋으로 백업 가능하나

판정:

- `strong`: 기록, diff, 커밋 단위가 명확하다
- `partial`: 기록은 가능하지만 변경 단위가 다소 크다
- `weak`: 변경 경계가 흐리거나 즉시 복구가 어렵다

### 3.5 Structural impact

질문:

- 기존 구조를 유지한 채 해결 가능한가
- 구조 변경이 필요하다면 정말 필수불가결한가

판정:

- `low`: 기존 구조 안에서 해결된다
- `medium`: 작은 배선 수정 정도가 필요하다
- `high`: 구조 재편 없이는 추진이 어렵다

### 3.6 Recursive improvement leverage

질문:

- 이 후보가 다음 개선을 더 잘 찾게 만드나
- 저장소가 스스로 부족함을 식별하고 검증하는 능력을 키우나

판정:

- `high`: 이후 자가 진단/제안/검증 루프를 직접 강화한다
- `medium`: 현재 문제는 풀지만 다음 루프 강화는 제한적이다
- `low`: 일회성 수정에 가깝다

## 4. 계획 단계 게이트 순서

후보 평가는 아래 순서로 고정한다.

1. `Goal alignment`가 `pass`인지 먼저 본다.
2. `Gap relevance`가 `medium` 이상인지 본다.
3. `Safety and regression control`이 `risky`면 보완 계획 없이 진행하지 않는다.
4. `Reversibility and traceability`가 `weak`면 작업을 더 작은 단위로 다시 자른다.
5. `Structural impact`가 `high`면 예외 승인 전까지 보류한다.
6. 남은 후보끼리는 `Recursive improvement leverage`가 높은 쪽을 우선한다.

이 순서는 중요하다.
이 저장소는 "쉽게 만들 수 있는 것"보다 "목표에 맞는 것"을 먼저 고른다.

## 5. 공통 후보 카드와 점수/등급 규칙

기능 후보와 리팩터링 후보를 따로 설명만 하면, 실제 계획 단계에서 한 큐로 비교가 안 된다.
이 저장소는 후보 종류와 관계없이 아래 공통 카드 형식으로 먼저 기록한 뒤 우선순위를 정한다.

### 5.1 공통 후보 카드

권장 기록 형식:

```text
candidate_kind=small_feature|refactor | title=<short label> | linked_gap=<quality_gap|feature_gap> | goal_alignment=pass|borderline|fail | gap_relevance=high|medium|low | safety=safe|guarded|risky | reversibility=strong|partial|weak | structural_impact=low|medium|high | leverage=high|medium|low | common_score=<0-18> | specific_score=<0-12> | priority_score=<0-48> | priority_grade=A|B|C|D|hold | decision=pick|defer|needs_approval|reject
```

필수 원칙:

- 기능 후보와 리팩터링 후보 모두 `candidate_kind`, 공통 축, `common_score`, `specific_score`, `priority_score`, `priority_grade`, `decision` 필드를 같은 이름으로 남긴다
- `linked_gap` 은 반드시 현재 관찰된 부족함과 연결돼야 한다
- `priority_score` 계산 전에 계획 단계 goal gate 와 승인 경계를 먼저 통과해야 한다
- `priority_grade` 는 후보 종류가 아니라 프로젝트 목표 기여도와 실행 안전성 기준으로 붙인다

### 5.2 공통 축 숫자 변환 규칙

공통 평가 축은 아래처럼 숫자로 바꿔 `common_score` 를 만든다.

- `goal_alignment`
  - `pass=3`
  - `borderline=1`
  - `fail=0`
- `gap_relevance`
  - `high=3`
  - `medium=2`
  - `low=0`
- `safety`
  - `safe=3`
  - `guarded=2`
  - `risky=0`
- `reversibility`
  - `strong=3`
  - `partial=2`
  - `weak=0`
- `structural_impact`
  - `low=3`
  - `medium=2`
  - `high=0`
- `recursive_improvement_leverage`
  - `high=3`
  - `medium=2`
  - `low=1`

계산식:

```text
common_score = goal_alignment + gap_relevance + safety + reversibility + structural_impact + leverage
```

이 점수는 최대 `18` 점이다.
공통 축은 프로젝트 목표 고정, 안전성, 복구 가능성 비중이 크기 때문에 개별 후보 루브릭보다 먼저 본다.

### 5.3 공통 게이트와 승인 경계

아래 조건 중 하나라도 걸리면 점수 비교 전에 바로 분기한다.

1. `goal_alignment=fail` 이면 `decision=reject`, `priority_grade=hold`
2. `gap_relevance=low` 이면 `decision=defer`, `priority_grade=hold`
3. `safety=risky` 이면 보완 검증 계획 없이는 `decision=defer`, `priority_grade=hold`
4. `reversibility=weak` 이면 작업을 더 작은 단위로 쪼개기 전까지 `decision=defer`
5. `structural_impact=high` 이면 `decision=needs_approval`, `priority_grade=hold`

즉 공통 점수는 게이트를 통과한 후보끼리만 비교용으로 쓴다.
이 저장소는 점수가 높아도 목표 게이트나 승인 경계를 무시하지 않는다.

### 5.4 공통 우선순위 점수와 등급

후보 종류별 세부 루브릭 점수는 아래 `specific_score` 로 넣고, 최종 우선순위는 공통 가중치 규칙으로 합친다.

```text
priority_score = (common_score * 2) + specific_score
```

`common_score` 를 두 배로 두는 이유는, 후보 종류별 장점보다 프로젝트 목표 부합과 안전한 실행을 더 강하게 반영하기 위해서다.

등급 규칙:

- `A`: `priority_score >= 40`
- `B`: `priority_score >= 32` and `< 40`
- `C`: `priority_score >= 24` and `< 32`
- `D`: `priority_score < 24`
- `hold`: 공통 게이트 또는 승인 경계에 걸린 상태

운영 규칙:

- 같은 등급이면 `common_score` 가 높은 후보를 먼저 잡는다
- `common_score` 도 같으면 기능 후보는 `goal_alignment`, 리팩터링 후보는 `feature_goal_contribution` 높은 쪽을 먼저 잡는다
- 그래도 같으면 기능 후보는 `implementation_cost`, 리팩터링 후보는 `risk` 가 더 높은 쪽을 먼저 잡는다

### 5.5 공통 예시

작은 기능 후보 예시:

```text
candidate_kind=small_feature | title=normalize verifier output | linked_gap=feature_gap | goal_alignment=pass | gap_relevance=high | safety=safe | reversibility=strong | structural_impact=low | leverage=high | common_score=18 | specific_score=10 | priority_score=46 | priority_grade=A | decision=pick
```

리팩터링 후보 예시:

```text
candidate_kind=refactor | title=split duplicated goal-gate parsing | linked_gap=quality_gap | goal_alignment=pass | gap_relevance=high | safety=guarded | reversibility=strong | structural_impact=low | leverage=medium | common_score=16 | specific_score=10 | priority_score=42 | priority_grade=A | decision=pick
```

이 두 후보는 같은 포맷과 같은 등급 체계로 바로 비교할 수 있다.

## 6. 기능 후보와 리팩터링 후보에 공통 적용하는 법

### 기능 후보

다음 질문으로 보면 된다.

- 현재 공백이 실제 사용자 흐름, 운영 흐름, 검증 흐름 중 어디에 있나
- 그 기능이 프로젝트 목표를 더 직접적으로 달성하게 만드나
- 넣은 뒤 다음 개선 루프가 더 똑똑해지나

### 리팩터링 후보

다음 질문으로 보면 된다.

- 이 리팩터링이 품질 부족의 원인을 줄이나
- 테스트 가능성, 변경 추적성, 회귀 통제를 더 좋게 만드나
- 구조 개선 욕심이 프로젝트 목표보다 앞서고 있지는 않나

## 7. 리팩터링 후보 세부 루브릭

리팩터링 후보도 공통 평가 축만 보는 걸로 끝내면 안 된다.
이 저장소에서 리팩터링은 "코드를 예쁘게 정리"하는 일이 아니라, 코드 품질 부족을 줄이면서도 기능 목표를 더 안정적으로 달성하게 만드는 작업이어야 한다.

계획 단계에서는 아래 네 항목을 같이 남겨서, 그냥 손보고 싶은 리팩터링과 지금 집어야 하는 리팩터링을 구분한다.

### 7.1 Quality impact

이 항목은 리팩터링이 코드 품질 부족을 얼마나 직접 줄이는지 본다.

- `3`: 중복, 복잡도, 테스트 취약점, 오류 가능성 같은 현재 품질 부족의 원인을 직접 줄이고 검증 신뢰도도 같이 좋아진다
- `2`: 품질 개선 효과는 분명하지만 핵심 원인보다 주변 마찰을 줄이는 수준이다
- `1`: 읽기 편해지거나 정리 효과는 있으나 실제 품질 부족 감소는 제한적이다
- `0`: 눈에 띄는 품질 개선 근거가 없거나 미적 정리에 가깝다

질문:

- 현재 확인된 품질 부족의 원인에 직접 닿나
- 이 변경 뒤에 테스트 신뢰도, 오류 방지, 디버깅 용이성이 실제로 좋아지나

### 7.2 Risk

이 항목은 리팩터링이 회귀, 영향 범위, 검증 난이도를 얼마나 키우는지 본다.
점수가 높을수록 더 안전하고 통제 가능하다는 뜻으로 기록한다.

- `3`: 영향 범위가 좁고 현재 테스트/리뷰 체계로 회귀를 쉽게 통제할 수 있다
- `2`: 인접 흐름 영향은 있지만 검증 계획을 붙이면 충분히 통제 가능하다
- `1`: 영향 범위가 넓거나 숨은 결합이 있어 회귀 통제가 빡세다
- `0`: 구조 변경 승인, 큰 계약 재정의, 대규모 수동 검증 없이는 안전하게 진행하기 어렵다

질문:

- 영향 받는 흐름과 파일 경계가 명확한가
- 현재 저장소 검증 체계로 회귀를 잡을 수 있나

### 7.3 Maintainability

이 항목은 리팩터링이 이후 유지보수 비용을 얼마나 줄이는지 본다.

- `3`: 변경 후 책임 경계, 추적성, 테스트 추가 용이성, 수정 난이도가 함께 좋아진다
- `2`: 유지보수성 개선은 분명하지만 일부 영역에만 국한된다
- `1`: 당장 읽기는 쉬워져도 이후 수정/검증 비용 절감 효과는 약하다
- `0`: 새 추상화나 분기만 늘려 오히려 유지보수 비용을 키울 가능성이 높다

질문:

- 다음 수정이나 테스트 추가가 더 쉬워지나
- 숨은 결합, 추상화 과잉, 문맥 의존성을 줄이나

### 7.4 Feature goal contribution

이 항목은 리팩터링이 기능 목표 달성에 얼마나 직접 기여하는지 본다.
리팩터링이라고 해서 기능 목표 기여를 면제하면 안 된다.

- `3`: 현재 또는 다음 기능 작업의 병목을 직접 없애고, 목표 안의 기능 제안·구현·검증 흐름을 분명히 더 잘 돌게 만든다
- `2`: 기능 작업을 보조하거나 안전하게 만들지만 직접 병목 제거까지는 아니다
- `1`: 일반적인 코드 정리에 가까워 기능 목표 기여는 간접적이다
- `0`: 기능 목표와 사실상 무관하거나 방향성을 흐린다

질문:

- 이 리팩터링이 현재 목표 안의 기능 공백을 더 빨리 혹은 더 안전하게 메우게 하나
- 그냥 코드 취향 정리인데 기능 목표 기여를 과장하고 있지는 않나

### 7.5 판정 규칙

리팩터링 후보는 아래 순서로 본다.

1. 공통 평가 축에서 `goal_alignment=pass`, `gap_relevance=medium` 이상이 아니면 탈락시킨다.
2. `feature_goal_contribution`이 `2` 미만이면 자동 수행 후보에서 뺀다.
3. `quality_impact`가 `2` 미만이면 "나중 정리"로 밀고 현재 개선 루프 우선순위에서 제외한다.
4. `risk`가 `0`이면 구조 변경 승인 후보로 분리하고 자동 수행 목록에서 뺀다.
5. `maintainability`가 `0`이면 보완 설계 없이 진행하지 않는다.
6. 남은 후보는 합계 점수로 정렬하되, 동점이면 `feature_goal_contribution`, 그다음 `quality_impact`가 높은 쪽을 먼저 잡는다.

권장 기록 형식:

```text
candidate_kind=refactor | quality_impact=3 | risk=2 | maintainability=3 | feature_goal_contribution=2 | specific_score=10
```

이 형식은 공통 평가 축 기록과 같이 남긴다.
즉 리팩터링 후보도 "축 기반 판정"과 "루브릭 기반 우선순위"를 둘 다 가져야 한다.

## 8. 작은 기능 후보 세부 루브릭

작은 기능 후보는 공통 평가 축만 보는 걸로 끝내지 않는다.
계획 단계에서는 아래 네 항목을 같이 남겨서, "해볼 만한 기능"과 "지금 해야 하는 기능"을 구분한다.

### 8.1 Value

이 항목은 기능이 실제 공백을 얼마나 메우는지 본다.

- `3`: 현재 드러난 기능 공백이나 반복 마찰을 직접 줄이고, 사용자 흐름이나 검증 흐름이 바로 좋아진다
- `2`: 불편을 줄이거나 보조 기능을 보강하지만 핵심 공백을 직접 닫지는 않는다
- `1`: 있으면 좋지만 현재 목표 달성에는 간접 효과만 있다
- `0`: 현재 저장소의 부족함과 사실상 연결되지 않는다

질문:

- 지금 확인된 기능 공백을 직접 메우나
- 제안만 그럴듯한 게 아니라 실제 사용 흐름을 짧게 만드나

### 8.2 Implementation cost

이 항목은 기능 하나를 넣기 위해 필요한 구현 비용과 검증 비용을 같이 본다.
점수가 높을수록 싸고 작다는 뜻으로 기록한다.

- `3`: 기존 구조 안에서 작은 변경으로 끝나고, 검증 경로도 명확하다
- `2`: 파일/조건 분기가 조금 늘어나지만 현재 구조와 검증 체계 안에서 무난히 처리된다
- `1`: 영향 범위가 넓거나 추가 검증 부담이 커서 작은 기능치고 비싸다
- `0`: 구조 변경, 승인, 큰 계약 재정의 없이는 안전하게 넣기 어렵다

질문:

- 기존 구조를 유지한 채 넣을 수 있나
- 구현 비용보다 검증 비용이 더 커지는 후보는 아닌가

### 8.3 Goal alignment

이 항목은 기능이 프로젝트 방향성에 얼마나 직접 기여하는지 본다.

- `3`: 저장소가 스스로 부족한 점을 찾고, 제안·구현·검증하는 능력을 직접 강화한다
- `2`: 목표 달성 흐름을 보조하지만 핵심 루프를 직접 강화하지는 않는다
- `1`: 프로젝트 목표와 충돌은 없지만 직접 기여도는 약하다
- `0`: 방향성을 흐리거나 옆길 기능에 가깝다

질문:

- 이 기능이 목표 안에서 자가 개선 루프를 더 잘 돌게 만드나
- 단지 일반 편의 기능인데 목표 기여를 과장하고 있지는 않나

### 8.4 Ripple effect

이 항목은 기능 하나가 다른 영역에 주는 연쇄 효과를 본다.
좋은 파급과 나쁜 파급을 같이 적는다.

- `3`: 다음 개선 후보 식별, 테스트 신뢰도, 기록 가능성까지 같이 좋아진다
- `2`: 인접 영역 한두 곳에 긍정 효과가 있지만 범위는 제한적이다
- `1`: 현재 문제만 겨우 해결하고 연쇄 이득은 거의 없다
- `0`: 회귀 위험, 운영 복잡도, 추적 비용을 늘릴 가능성이 더 크다

질문:

- 이 기능이 다음 사이클의 탐지/우선순위화/검증을 쉽게 만드나
- 연쇄 이득보다 숨은 비용이나 회귀 리스크가 더 크지 않나

### 8.5 판정 규칙

작은 기능 후보는 아래 순서로 본다.

1. `goal_alignment`가 `2` 미만이면 탈락시킨다.
2. `value`가 `2` 미만이면 지금 당장 할 일에서 뺀다.
3. `implementation_cost`가 `0`이면 구조 변경 승인 후보로 분리하고 자동 수행 목록에서 뺀다.
4. `ripple_effect`가 `0`이면 보완책 없이 진행하지 않는다.
5. 남은 후보는 합계 점수로 정렬하되, 동점이면 `goal_alignment`, 그다음 `value`가 높은 쪽을 먼저 잡는다.

권장 기록 형식:

```text
candidate_kind=small_feature | value=3 | implementation_cost=2 | goal_alignment=3 | ripple_effect=2 | specific_score=10
```

이 형식은 공통 평가 축 기록과 같이 남긴다.
즉 작은 기능 후보는 "축 기반 판정"과 "루브릭 기반 우선순위"를 둘 다 가져야 한다.

## 9. 빠른 사용 규칙

후보를 평가할 때 최소한 아래 한 줄은 남긴다.

```text
goal_alignment=pass | gap_relevance=high | safety=safe | reversibility=strong | structural_impact=low | leverage=high
```

이 기록이 남아야 다음 작업도 같은 축으로 누적 비교할 수 있다.

작은 기능 후보라면 아래 한 줄을 추가로 붙인다.

```text
candidate_kind=small_feature | value=3 | implementation_cost=2 | goal_alignment=3 | ripple_effect=2 | specific_score=10
```

리팩터링 후보라면 아래 한 줄을 추가로 붙인다.

```text
candidate_kind=refactor | quality_impact=3 | risk=2 | maintainability=3 | feature_goal_contribution=2 | specific_score=10
```

마지막으로 공통 후보 카드 한 줄로 합친다.

```text
candidate_kind=<small_feature|refactor> | title=<short label> | linked_gap=<quality_gap|feature_gap> | goal_alignment=pass | gap_relevance=high | safety=safe | reversibility=strong | structural_impact=low | leverage=high | common_score=18 | specific_score=10 | priority_score=46 | priority_grade=A | decision=pick
```

## 10. 이 AC 기준 완료 정의

이 문서가 있으면 이후 단계는 다음을 할 수 있어야 한다.

- 저장소 방향성에서 벗어나는 후보를 계획 단계에서 바로 걸러냄
- 기능 후보와 리팩터링 후보를 같은 축으로 비교함
- 기능 후보와 리팩터링 후보를 같은 후보 카드 포맷과 같은 점수/등급 규칙으로 한 큐에서 정렬함
- 리팩터링 후보를 코드 품질 개선 효과, 위험도, 유지보수성, 기능 목표 기여도 기준으로 세부 비교함
- 작은 기능 후보를 가치, 구현 비용, 목표 정합성, 파급 효과 기준으로 세부 비교함
- 자가 개선이 "아무거나 자동 생성"이 아니라 "목표 정렬된 개선"이라는 기준을 유지함
