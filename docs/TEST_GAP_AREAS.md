# Test Gap Areas

이 문서는 저장소의 테스트 부재, 커버리지 공백, flaky 가능성, 검증 누락 영역을 근거 파일과 시나리오 기준으로 정리한다.
모든 항목은 현재 저장소 목표인 자가 탐지 -> 제안 -> 구현 -> 검증 루프에 직접 연결되는 것만 남긴다.

- schema_version: `1`
- scanned_file_count: `47`
- source_file_count: `9`
- test_file_count: `0`
- finding_count: `6`

## Findings

### 설치기 핵심 소스 테스트 부재

- category: `missing_tests` / severity `high`
- area: `설치기와 작업공간 스캐폴딩`
- 요약: 설치기와 작업공간 스캐폴딩 영역의 핵심 소스 파일 2개가 테스트 파일과 연결되지 않는다 (저장소 테스트 파일 수: 0).
- 근거 판단: 설치기는 전역/작업공간 상태 생성의 핵심인데, 관련 테스트 파일이나 호출형 검증이 저장소에 없다.
- 시나리오: 설치기 상태 생성이나 config patch 로직이 깨져도 현재 기본 검증은 Bash help 출력만 보므로 실사용 회귀를 막지 못한다.
- 근거:
  - `installer/CodexMultiAgent.ps1:35` :: 정의 58개, 연관 테스트 파일 0개
  - `installer/CodexMultiAgent.sh:25` :: 정의 65개, 연관 테스트 파일 0개

### 핵심 Python 분석기 테스트 부재

- category: `missing_tests` / severity `high`
- area: `루트 도구/자동화`
- 요약: 루트 도구/자동화 영역의 핵심 소스 파일 3개가 테스트 파일과 연결되지 않는다 (저장소 테스트 파일 수: 0).
- 근거 판단: 프로젝트 목표상 자가 탐지와 우선순위 판단을 담당하는 핵심 Python 도구들이 전용 테스트 파일 없이 운영된다.
- 시나리오: 정규화, 메트릭 수집, 기능 공백 추출기의 분기 하나가 깨져도 지금은 CLI 스모크와 일부 샘플 assert 에만 걸린다. 함수 단위 회귀나 경계값 케이스를 직접 방어하지 못한다.
- 근거:
  - `collect_repo_metrics.py:62` :: 정의 34개, 연관 테스트 파일 0개
  - `extract_feature_gap_candidates.py:76` :: 정의 50개, 연관 테스트 파일 0개
  - `normalize_quality_signals.py:102` :: 정의 38개, 연관 테스트 파일 0개

### 커버리지 신호 생산 경로 부재

- category: `coverage_gap` / severity `high`
- area: `루트 도구/자동화`
- 요약: 커버리지 파싱 로직은 있지만 저장소 검증 경로가 실제 커버리지를 생산하지 않아 분기 누락을 수치로 감시하지 못한다.
- 근거 판단: 정규화기는 coverage 필드를 처리하지만 실제 `make test`/`make check` 흐름에는 coverage 실행이나 최소 기준이 없다.
- 시나리오: coverage 파서나 우선순위 로직이 깨져도 현재 검증은 스모크 출력만 확인한다. 라인/브랜치 커버리지 하락이나 특정 분기 미실행은 다음 개선 루프에 신호로 남지 않는다.
- 근거:
  - `normalize_quality_signals.py:84` :: coverage 정규화 패턴 정의
  - `normalize_quality_signals.py:813` :: coverage 입력을 실제 요약 필드로 변환
  - `Makefile:55` :: 기본 test 엔트리포인트에 coverage 실행이 없음

### 환경 의존 skip 분기 때문에 검증 강도가 흔들림

- category: `flaky_risk` / severity `medium`
- area: `검증 엔트리포인트`
- 요약: 검증 엔트리포인트가 최소 12개 조건부 skip 분기를 가진다. 호스트 도구 유무에 따라 같은 커밋의 검증 강도가 달라져 환경 의존 flaky 가능성이 남는다.
- 근거 판단: lint/test 단계가 도구 부재를 실패가 아니라 skip 으로 처리하므로, 개발기와 CI 또는 OS 조합마다 실제 검증 범위가 달라질 수 있다.
- 시나리오: `markdownlint`, `shellcheck`, `pwsh`, `python3`, `git` 가 없는 환경에서는 같은 `make check` 가 더 적은 검사를 통과로 처리한다. 특정 플랫폼에서만 드러나는 회귀가 다른 환경에서는 재현되지 않아 flaky 처럼 보일 수 있다.
- 근거:
  - `Makefile:31` :: 도구 부재 시 검사를 skip 처리
  - `Makefile:173` :: 테스트 타깃에서도 동일한 skip 패턴 반복

### 설치기 핵심 경로 검증 누락

- category: `verification_gap` / severity `high`
- area: `설치기와 작업공간 스캐폴딩`
- 요약: 설치기 검증이 Bash help 스모크 한 줄에 치우쳐 있다. 실제 작업공간 적용, PowerShell 경로, bootstrap 다운로드/적용 흐름은 완료 게이트에 들어오지 않는다.
- 근거 판단: 프로젝트 목표상 복구 가능한 작업 단위와 상태 생성이 핵심인데, 이를 담당하는 설치기 주요 경로가 회귀 테스트 없이 비어 있다.
- 시나리오: 작업공간 오버라이드 생성, `STATE.md`/`AGENTS.md` 렌더링, PowerShell 경로 수정이 깨져도 현재 기본 검증은 Bash help 출력만 통과하면 녹색으로 끝난다.
- 근거:
  - `Makefile:59` :: 설치기 검증이 Bash `--help` 호출 한 줄로 끝남
  - `installer/CodexMultiAgent.sh:25` :: 실제 설치/상태 생성 함수 65개
  - `installer/CodexMultiAgent.ps1:35` :: 실제 설치/상태 생성 함수 58개
  - `installer/Bootstrap.sh:1` :: 별도 bootstrap 진입점 존재하지만 기본 test 경로에서 실행되지 않음
  - `installer/Bootstrap.ps1:1` :: 별도 PowerShell bootstrap 진입점 존재하지만 기본 test 경로에서 실행되지 않음

### 자가개선 루프 통합 검증 부재

- category: `verification_gap` / severity `medium`
- area: `프로젝트 목표 루프`
- 요약: 프로젝트 목표는 탐지 -> 제안 -> 구현 -> 검증의 재귀 루프를 요구하지만, 현재 검증은 개별 도구 스모크만 확인하고 루프 전체를 묶는 통합 시나리오가 없다.
- 근거 판단: 목표 문서는 완료 판정을 목표 부합과 검증 통과에 묶는데, 실제 `make test` 는 각 보조 스크립트가 혼자 실행되는지만 본다.
- 시나리오: 갭 탐지 결과가 후보 제안 또는 다음 검증 단계와 끊겨도 개별 스크립트 스모크만 통과하면 놓친다. 프로젝트 방향성 안에서의 재귀 개선이 실제로 이어지는지 확인하는 E2E 시나리오가 없다.
- 근거:
  - `docs/GOAL_COMPARISON_AREAS.md:7` :: 프로젝트 목표가 재귀적 자가개선 루프를 요구
  - `Makefile:55` :: 기본 test 엔트리포인트는 개별 스모크 타깃 집합
