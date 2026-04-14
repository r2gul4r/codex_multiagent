# Refactor Candidates

이 문서는 저장소 분석 결과를 바탕으로 코드 품질과 변경 안정성을 높일 리팩터링 후보를 정리한다.
각 항목은 문제 징후, 개선 기대효과, 선정 근거를 함께 남겨 다음 계획 단계의 직접 입력으로 쓴다.

- schema_version: `1`
- scanned_file_count: `52`
- refactor_candidate_count: `5`

## Refactor Candidates

### 루트 도구/자동화 / collect_repo_metrics.py 책임 분리와 경계 정리

- 결정: `pick` / 등급 `A` / 점수 `47`
- 문제 징후:
  - `collect_repo_metrics.py` 가 code_lines=702, cyclomatic_estimate=111, duplication_group_count=19 로 큰 핫스팟임
  - 변경 빈도도 commit_count=1 로 누적돼 수정 안정성 압박이 큼
  - 큰 책임 덩어리 예시: build_summary(74 lines), collect_duplicate_groups(54 lines), analyze_file(52 lines)
- 개선 기대효과:
  - 탐지, 점수화, 렌더링 같은 책임을 더 작은 단위로 쪼개 다음 수정 범위를 좁힘
  - 후속 기능 추가나 규칙 수정 때 회귀 범위를 줄이고 테스트 포인트를 더 선명하게 만듦
  - 자가 개선 루프의 핵심 도구를 더 안정적으로 확장할 수 있게 함
- 선정 근거:
  - 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
  - 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3
  - 복잡도, 파일 크기, 중복 지표가 같이 높아 단일 파일에 책임이 몰린 신호가 분명함
- 근거 위치:
  - `collect_repo_metrics.py`
  - `collect_repo_metrics.py:692`
  - `collect_repo_metrics.py:595`
  - `collect_repo_metrics.py:352`
- 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
- 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3, specific_score=11

### 루트 도구/자동화 / normalize_quality_signals.py 책임 분리와 경계 정리

- 결정: `pick` / 등급 `A` / 점수 `47`
- 문제 징후:
  - `normalize_quality_signals.py` 가 code_lines=859, cyclomatic_estimate=209, duplication_group_count=14 로 큰 핫스팟임
  - 변경 빈도도 commit_count=1 로 누적돼 수정 안정성 압박이 큼
  - 큰 책임 덩어리 예시: normalize_repo_metric_file(89 lines), parse_coverage(68 lines), normalize_repo_metrics_payload(66 lines)
- 개선 기대효과:
  - 탐지, 점수화, 렌더링 같은 책임을 더 작은 단위로 쪼개 다음 수정 범위를 좁힘
  - 후속 기능 추가나 규칙 수정 때 회귀 범위를 줄이고 테스트 포인트를 더 선명하게 만듦
  - 자가 개선 루프의 핵심 도구를 더 안정적으로 확장할 수 있게 함
- 선정 근거:
  - 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
  - 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3
  - 복잡도, 파일 크기, 중복 지표가 같이 높아 단일 파일에 책임이 몰린 신호가 분명함
- 근거 위치:
  - `normalize_quality_signals.py`
  - `normalize_quality_signals.py:658`
  - `normalize_quality_signals.py:813`
  - `normalize_quality_signals.py:747`
- 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
- 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3, specific_score=11

### 루트 도구/자동화 / apply_git_history_metrics + apply_duplication_metrics 중복 정리

- 결정: `pick` / 등급 `A` / 점수 `47`
- 문제 징후:
  - 정규화 중복 블록 15줄이 2회 반복됨
  - 영향 파일 중 최대 변경 빈도는 commit_count=1
  - 중복이 같은 책임 경계(apply_git_history_metrics, apply_duplication_metrics) 주변에 몰려 있음
  - 반복 블록 예시: return [ / FileMetrics(
- 개선 기대효과:
  - 루트 도구/자동화에서 같은 수정 포인트를 여러 블록 대신 한 군데로 모아 drift 가능성을 줄임
  - 후속 규칙 추가나 상태 필드 수정 시 변경 누락 가능성을 낮춤
  - `collect_repo_metrics.py` 내부 변경 범위를 줄여 회귀 확인 지점을 단순화함
- 선정 근거:
  - 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
  - 리팩터링 루브릭: quality_impact=2, risk=3, maintainability=3, feature_goal_contribution=3
  - 중복 신호와 변경 빈도 신호가 함께 보여 변경 안정성 개선 효과를 설명하기 쉬움
- 근거 위치:
  - `collect_repo_metrics.py:486-500`
  - `collect_repo_metrics.py:669-683`
- 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=safe, reversibility=strong, structural_impact=low, leverage=high
- 리팩터링 루브릭: quality_impact=2, risk=3, maintainability=3, feature_goal_contribution=3, specific_score=11

### 설치기와 작업공간 스캐폴딩 / New-DefaultState + New-WorkspaceStateFromContext 중복 정리

- 결정: `pick` / 등급 `A` / 점수 `45`
- 문제 징후:
  - 정규화 중복 블록 50줄이 2회 반복됨
  - 영향 파일 중 최대 변경 빈도는 commit_count=31
  - 중복이 같은 책임 경계(New-DefaultState, New-WorkspaceStateFromContext) 주변에 몰려 있음
  - 반복 블록 예시: $lines.Add('- phase: `explore`') / $lines.Add('- scope: `n/a`')
- 개선 기대효과:
  - 설치기와 작업공간 스캐폴딩에서 같은 수정 포인트를 여러 블록 대신 한 군데로 모아 drift 가능성을 줄임
  - 후속 규칙 추가나 상태 필드 수정 시 변경 누락 가능성을 낮춤
  - `installer/CodexMultiAgent.ps1` 내부 변경 범위를 줄여 회귀 확인 지점을 단순화함
- 선정 근거:
  - 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=guarded, reversibility=strong, structural_impact=low, leverage=high
  - 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3
  - 중복 신호와 변경 빈도 신호가 함께 보여 변경 안정성 개선 효과를 설명하기 쉬움
- 근거 위치:
  - `installer/CodexMultiAgent.ps1:704-753`
  - `installer/CodexMultiAgent.ps1:860-909`
- 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=guarded, reversibility=strong, structural_impact=low, leverage=high
- 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3, specific_score=11

### 설치기와 작업공간 스캐폴딩 / generate_default_state + generate_workspace_state_from_context 중복 정리

- 결정: `pick` / 등급 `A` / 점수 `45`
- 문제 징후:
  - 정규화 중복 블록 38줄이 2회 반복됨
  - 영향 파일 중 최대 변경 빈도는 commit_count=31
  - 중복이 같은 책임 경계(generate_default_state, generate_workspace_state_from_context) 주변에 몰려 있음
  - 반복 블록 예시: printf -- '- phase: `explore`\n' / printf -- '- scope: `n/a`\n'
- 개선 기대효과:
  - 설치기와 작업공간 스캐폴딩에서 같은 수정 포인트를 여러 블록 대신 한 군데로 모아 drift 가능성을 줄임
  - 후속 규칙 추가나 상태 필드 수정 시 변경 누락 가능성을 낮춤
  - `installer/CodexMultiAgent.sh` 내부 변경 범위를 줄여 회귀 확인 지점을 단순화함
- 선정 근거:
  - 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=guarded, reversibility=strong, structural_impact=low, leverage=high
  - 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3
  - 중복 신호와 변경 빈도 신호가 함께 보여 변경 안정성 개선 효과를 설명하기 쉬움
- 근거 위치:
  - `installer/CodexMultiAgent.sh:347-384`
  - `installer/CodexMultiAgent.sh:808-845`
- 공통 축 판정: goal_alignment=pass, gap_relevance=high, safety=guarded, reversibility=strong, structural_impact=low, leverage=high
- 리팩터링 루브릭: quality_impact=3, risk=2, maintainability=3, feature_goal_contribution=3, specific_score=11
