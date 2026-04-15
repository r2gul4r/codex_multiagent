# Feature Gap Areas

이 문서는 저장소에서 판별된 기능 공백과 그 근거를 바탕으로 뽑은 작은 기능 후보 목록이다.
각 항목은 근거, 현재 상태, 사용자 가치, 구현 범위, 선정 근거를 함께 남겨 다음 계획 단계의 직접 입력으로 쓴다.

- schema_version: `3`
- scanned_file_count: `14`
- documented_feature_gap_count: `4`
- small_feature_candidate_count: `4`

## Small Feature Candidates

### 설치기와 작업공간 스캐폴딩 / New-DefaultState

- 결정: `defer` / 등급 `hold` / 점수 `33`
- 사용자 가치: 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
- 구현 범위:
  - 영향 경로가 넓어 작은 기능치고 검증 부담이 큰 편
  - 우선 수정 후보 코드 위치: installer/CodexMultiAgent.ps1:757
  - 주요 정의 지점: installer/CodexMultiAgent.ps1:757
  - 관련 테스트가 없어 기능 보강과 함께 회귀 방어 경로 확인이 필요함
- 선정 근거:
  - 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
  - 저장소의 자가 탐지·제안·검증 루프를 직접 강화하는 영역이라 목표 정합성이 높음
  - 인접한 검증 또는 호출 흐름에 긍정 효과가 있지만 범위는 제한적임
  - 관련 테스트 흔적이 없음
  - 공통 축 판정: goal_alignment=pass, gap_relevance=medium, safety=guarded, reversibility=partial, structural_impact=medium, leverage=medium

### 설치기와 작업공간 스캐폴딩 / New-WorkspaceStateFromContext

- 결정: `defer` / 등급 `hold` / 점수 `33`
- 사용자 가치: 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
- 구현 범위:
  - 영향 경로가 넓어 작은 기능치고 검증 부담이 큰 편
  - 우선 수정 후보 코드 위치: installer/CodexMultiAgent.ps1:926
  - 주요 정의 지점: installer/CodexMultiAgent.ps1:926
  - 관련 테스트가 없어 기능 보강과 함께 회귀 방어 경로 확인이 필요함
- 선정 근거:
  - 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
  - 저장소의 자가 탐지·제안·검증 루프를 직접 강화하는 영역이라 목표 정합성이 높음
  - 인접한 검증 또는 호출 흐름에 긍정 효과가 있지만 범위는 제한적임
  - 관련 테스트 흔적이 없음
  - 공통 축 판정: goal_alignment=pass, gap_relevance=medium, safety=guarded, reversibility=partial, structural_impact=medium, leverage=medium

### 설치기와 작업공간 스캐폴딩 / generate_default_state

- 결정: `defer` / 등급 `hold` / 점수 `33`
- 사용자 가치: 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
- 구현 범위:
  - 영향 경로가 넓어 작은 기능치고 검증 부담이 큰 편
  - 우선 수정 후보 코드 위치: installer/CodexMultiAgent.sh:377
  - 주요 정의 지점: installer/CodexMultiAgent.sh:377
  - 관련 테스트가 없어 기능 보강과 함께 회귀 방어 경로 확인이 필요함
- 선정 근거:
  - 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
  - 저장소의 자가 탐지·제안·검증 루프를 직접 강화하는 영역이라 목표 정합성이 높음
  - 인접한 검증 또는 호출 흐름에 긍정 효과가 있지만 범위는 제한적임
  - 관련 테스트 흔적이 없음
  - 공통 축 판정: goal_alignment=pass, gap_relevance=medium, safety=guarded, reversibility=partial, structural_impact=medium, leverage=medium

### 설치기와 작업공간 스캐폴딩 / generate_workspace_state_from_context

- 결정: `defer` / 등급 `hold` / 점수 `33`
- 사용자 가치: 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
- 구현 범위:
  - 영향 경로가 넓어 작은 기능치고 검증 부담이 큰 편
  - 우선 수정 후보 코드 위치: installer/CodexMultiAgent.sh:866
  - 주요 정의 지점: installer/CodexMultiAgent.sh:866
  - 관련 테스트가 없어 기능 보강과 함께 회귀 방어 경로 확인이 필요함
- 선정 근거:
  - 보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼
  - 저장소의 자가 탐지·제안·검증 루프를 직접 강화하는 영역이라 목표 정합성이 높음
  - 인접한 검증 또는 호출 흐름에 긍정 효과가 있지만 범위는 제한적임
  - 관련 테스트 흔적이 없음
  - 공통 축 판정: goal_alignment=pass, gap_relevance=medium, safety=guarded, reversibility=partial, structural_impact=medium, leverage=medium

## 설치기와 작업공간 스캐폴딩

- area_id: `installer`
- scanned_file_count: `4`
- documented_feature_gap_count: `4`

### 설치기와 작업공간 스캐폴딩 / New-DefaultState

- 근거: placeholder 문자열이 실제 값 대신 남아 있어 사용 시점에 필요한 기능 채움이 빠져 있음
- 근거 위치: `installer/CodexMultiAgent.ps1:781`
- 현재 상태: 검토 필요 / 신호는 있으나 실제 공백으로 단정하기엔 근거가 약함 / 정의와 참조가 둘 다 보여 실제 호출 흐름을 따라갈 수 있음 / 연결된 테스트 파일을 찾지 못해 기능 공백 회귀 방어가 약함
- 예상 영향도: 낮음 / 설치기와 작업공간 스캐폴딩에서 1개 근거가 같은 공백 후보로 묶여 있고 판정 신뢰도는 low라서, 이 항목을 메우면 해당 영역의 누락 상태 기록과 후속 개선 우선순위 정확도가 낮음 수준으로 좋아질 가능성이 있다. 주요 근거: 관련 테스트 흔적이 없음
- 세부 근거:
  - `installer/CodexMultiAgent.ps1:781` placeholder 출력/템플릿 :: $lines.Add('- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`')

### 설치기와 작업공간 스캐폴딩 / New-WorkspaceStateFromContext

- 근거: placeholder 문자열이 실제 값 대신 남아 있어 사용 시점에 필요한 기능 채움이 빠져 있음
- 근거 위치: `installer/CodexMultiAgent.ps1:955`
- 현재 상태: 검토 필요 / 신호는 있으나 실제 공백으로 단정하기엔 근거가 약함 / 정의와 참조가 둘 다 보여 실제 호출 흐름을 따라갈 수 있음 / 연결된 테스트 파일을 찾지 못해 기능 공백 회귀 방어가 약함
- 예상 영향도: 낮음 / 설치기와 작업공간 스캐폴딩에서 1개 근거가 같은 공백 후보로 묶여 있고 판정 신뢰도는 low라서, 이 항목을 메우면 해당 영역의 누락 상태 기록과 후속 개선 우선순위 정확도가 낮음 수준으로 좋아질 가능성이 있다. 주요 근거: 관련 테스트 흔적이 없음
- 세부 근거:
  - `installer/CodexMultiAgent.ps1:955` placeholder 출력/템플릿 :: $lines.Add('- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`')

### 설치기와 작업공간 스캐폴딩 / generate_default_state

- 근거: placeholder 문자열이 실제 값 대신 남아 있어 사용 시점에 필요한 기능 채움이 빠져 있음
- 근거 위치: `installer/CodexMultiAgent.sh:396`
- 현재 상태: 검토 필요 / 신호는 있으나 실제 공백으로 단정하기엔 근거가 약함 / 정의와 참조가 둘 다 보여 실제 호출 흐름을 따라갈 수 있음 / 연결된 테스트 파일을 찾지 못해 기능 공백 회귀 방어가 약함
- 예상 영향도: 낮음 / 설치기와 작업공간 스캐폴딩에서 1개 근거가 같은 공백 후보로 묶여 있고 판정 신뢰도는 low라서, 이 항목을 메우면 해당 영역의 누락 상태 기록과 후속 개선 우선순위 정확도가 낮음 수준으로 좋아질 가능성이 있다. 주요 근거: 관련 테스트 흔적이 없음
- 세부 근거:
  - `installer/CodexMultiAgent.sh:396` placeholder 출력/템플릿 :: printf -- '- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`\n'

### 설치기와 작업공간 스캐폴딩 / generate_workspace_state_from_context

- 근거: placeholder 문자열이 실제 값 대신 남아 있어 사용 시점에 필요한 기능 채움이 빠져 있음
- 근거 위치: `installer/CodexMultiAgent.sh:891`
- 현재 상태: 검토 필요 / 신호는 있으나 실제 공백으로 단정하기엔 근거가 약함 / 정의와 참조가 둘 다 보여 실제 호출 흐름을 따라갈 수 있음 / 연결된 테스트 파일을 찾지 못해 기능 공백 회귀 방어가 약함
- 예상 영향도: 낮음 / 설치기와 작업공간 스캐폴딩에서 1개 근거가 같은 공백 후보로 묶여 있고 판정 신뢰도는 low라서, 이 항목을 메우면 해당 영역의 누락 상태 기록과 후속 개선 우선순위 정확도가 낮음 수준으로 좋아질 가능성이 있다. 주요 근거: 관련 테스트 흔적이 없음
- 세부 근거:
  - `installer/CodexMultiAgent.sh:891` placeholder 출력/템플릿 :: printf -- '- selection_reason: `placeholder - record the score and trigger basis for the chosen orchestration profile`\n'
