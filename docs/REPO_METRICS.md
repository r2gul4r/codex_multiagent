# Repository Metrics

이 문서는 저장소가 파일·모듈 단위로 복잡도, 모듈 크기, Git 변경 빈도 메트릭을 수집하는 최소 기준을 고정한다.
또한 수집된 메트릭을 정규화·가중치화해서 다음 개선 루프가 바로 우선순위를 잡을 수 있는 품질 신호로 바꾸는 기준도 함께 고정한다.

현재 저장소는 스크립트와 문서가 섞인 구조라서, 기본 단위는 "파일 = 모듈" 로 본다.
즉 파이썬 스크립트 하나, 셸 스크립트 하나, 문서 파일 하나를 각각 독립 모듈로 측정한다.

## 수집기

- 엔트리포인트: `scripts/collect_repo_metrics.py`
- 기본 동작: 저장소 루트를 재귀 스캔해서 UTF-8 텍스트 파일별 메트릭을 JSON으로 출력
- 제외 디렉터리: `.git`, `.codex`, `__pycache__`, `.pytest_cache`
- 선택 스캔: `--paths` 로 특정 파일이나 디렉터리만 제한 가능

예시:

```bash
python3 scripts/collect_repo_metrics.py --pretty
python3 scripts/collect_repo_metrics.py --paths scripts/normalize_quality_signals.py scripts/collect_repo_metrics.py --pretty
```

## 출력 기준

각 파일 레코드는 아래 세 묶음을 포함한다.

- `module_size`
  - `bytes`
  - `total_lines`
  - `blank_lines`
  - `comment_lines`
  - `code_lines`
  - `max_line_length`
- `complexity`
  - `function_like_blocks`
  - `class_like_blocks`
  - `decision_points`
  - `cyclomatic_estimate`
  - `max_indent_level`
- `duplication`
  - `group_count`
  - `duplicated_line_instances`
  - `max_duplicate_block_lines`
- `change_frequency`
  - `commit_count`
  - `author_count`
  - `first_commit_at`
  - `last_commit_at`
  - `active_days`
  - `commits_per_30_days`

루트 payload 는 `summary` 외에도 저장소 수준의 `duplication` 묶음을 제공한다.

- `minimum_block_lines`
- `group_count`
- `files_with_duplicates`
- `groups`
  - 각 그룹은 `fingerprint`, `normalized_line_count`, `token_count`, `occurrence_count`, `modules`, `excerpt` 를 포함한다
  - `modules` 는 파일 경로와 시작/끝 줄 범위를 담아서 실제 중복 구간을 파일·모듈 단위로 역추적할 수 있게 한다

`summary` 안에는 저장소 수준의 `change_frequency` 묶음도 포함된다.

- `files_with_history`
- `max_commit_count`
- `hotspots`
  - 최근까지 누적 변경이 많았던 파일 상위 목록
  - 각 항목은 `path`, `commit_count`, `last_commit_at`, `commits_per_30_days` 를 포함한다

Git 메트릭은 로컬 `.git` 히스토리를 기준으로 계산한다.

- 파일별 집계는 `git log --follow -- <path>` 결과를 기준으로 한다
- Git이 rename/copy lineage 를 추론하면 그 이전 변경도 같은 모듈 계보로 포함될 수 있다
- 추적되지 않은 파일, shallow 상태에서 기록이 없는 파일, Git 바깥 경로는 `0`/`null` 로 떨어진다
- `active_days` 는 첫 커밋과 마지막 커밋 사이의 일수다
- `commits_per_30_days` 는 `commit_count * 30 / max(active_days, 1)` 로 정규화한 거친 변경 빈도다

## 복잡도 해석

이 수집기는 정적 분석기 전체를 대체하려는 게 아니다.
현재 목적은 "어디가 크고 어디가 복잡한지", 그리고 "어디에 같은 코드 덩어리가 반복되는지"를 빠르게 거칠게 잡아내는 것이다.

- `decision_points` 는 언어별 분기 키워드 개수 기반 휴리스틱이다
- `cyclomatic_estimate` 는 `decision_points + 1` 로 계산한다
- `function_like_blocks` 와 `class_like_blocks` 는 언어별 선언 패턴 기반 개수다
- 중복 탐지는 빈 줄/주석을 제거한 뒤 정규화된 코드 줄 window 를 비교하는 휴리스틱이다
- 기본 최소 블록 길이는 `3` 줄이며 `--min-duplicate-lines` 로 조정할 수 있다
- 너무 짧은 토큰만 반복되는 보일러플레이트는 제외해서 노이즈를 줄인다

즉 이 숫자는 우선순위화용 1차 신호로 쓰고, 정밀 리팩터링 판단은 코드 리뷰와 기존 테스트로 보완한다.

Git 변경 빈도도 같은 맥락이다.

- `commit_count` 는 누적 터치 횟수를 보여준다
- `last_commit_at` 은 최근에 다시 흔들린 파일인지 확인하는 기준이다
- `commits_per_30_days` 는 오래된 대형 파일과 최근 자주 흔들리는 파일을 대략 분리하는 데 쓴다

## 품질 신호 정규화

수집한 메트릭은 그대로 보면 단위가 제각각이라 우선순위 비교가 거칠어진다.
그래서 이 저장소는 `scripts/normalize_quality_signals.py` 로 `scripts/collect_repo_metrics.py` 결과를 다시 읽어서 파일별 품질 신호를 만든다.

예시:

```bash
python3 scripts/collect_repo_metrics.py --paths scripts/normalize_quality_signals.py scripts/collect_repo_metrics.py --pretty > /tmp/repo-metrics.json
python3 scripts/normalize_quality_signals.py --input /tmp/repo-metrics.json --pretty
```

출력은 `analysis_kind=repo_metrics` 형태로 나가고, 파일별로 아래 필드를 담는다.

- `quality_signal.weighted_score`
  - `0.0..1.0` 범위의 정규화된 품질 압력 총합
- `quality_signal.priority_score`
  - `weighted_score * 48` 로 변환한 비교용 점수
- `quality_signal.priority_grade`
  - `A|B|C|D` 등급
- `quality_signal.priority_rank`
  - 현재 입력 안에서의 우선순위 순번
- `quality_signal.priority_decision`
  - `prioritize|monitor|low`
- `quality_signal.axis_breakdown`
  - `size_pressure`, `complexity_pressure`, `duplication_pressure`, `change_pressure`
- `quality_signal.top_signals`
  - 점수에 가장 크게 기여한 세부 메트릭 상위 항목

정규화 방식은 두 층을 섞는다.

1. 현재 입력 집합 안에서의 상대 크기
2. 저장소 기준으로 과하다고 볼 수 있는 절대 cap

각 세부 메트릭은 `relative_component` 와 `cap_component` 를 반반 섞어서 `0.0..1.0` 로 맞춘다.
이렇게 하면 작은 저장소에서 상대값만 보고 과하게 부풀리는 문제를 줄이면서도,
같은 저장소 안에서는 어떤 파일이 더 문제인지 계속 비교할 수 있다.
또한 churn 축에서는 `commit_count < 2` 인 파일의 `commits_per_30_days` 를 0으로 눌러,
생성 커밋 한 번만 있는 파일이 "최근에 자주 흔들린 핫스팟"처럼 과대평가되지 않게 한다.

가중치 기준은 아래처럼 고정한다.

- axis weights
  - `size_pressure=0.15`
  - `complexity_pressure=0.35`
  - `duplication_pressure=0.30`
  - `change_pressure=0.20`
- grade thresholds
  - `A >= 40`
  - `B >= 32`
  - `C >= 24`
  - `D < 24`

즉 큰 파일이라고 무조건 최상위가 아니라,
복잡도와 중복이 높고 최근까지 자주 흔들린 파일이 더 위로 올라오게 설계한다.

## 검증

재현 가능한 저장소 검증 엔트리포인트:

```bash
make test-quality-normalizer
make test-repo-metrics
```

`make test-quality-normalizer` 는 도구 실행 결과 정규화뿐 아니라,
임시 fixture Git 저장소에서 뽑은 repository metrics 를 다시 품질 신호로 정규화하고
우선순위 랭킹과 history 저장/조회까지 같이 검사한다.

`make test-repo-metrics` 는 임시 fixture Git 저장소를 만든 뒤 메트릭 JSON 형태와 핵심 수치가 예상대로 나오는지 검사한다.
