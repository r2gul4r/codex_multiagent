# Codex Multi-Agent Kit ✅

Codex의 공식 서브에이전트 기능 위에, 팀과 저장소 단위의 운영 규칙을 전역 기본값 + 프로젝트별 오버라이드 구조로 적용하는 킷

> Global defaults for every workspace, local overrides only where needed

---

## 최근 패치

- `v0.1.11 - 2026-03-21`
- 전역 규칙에 `route/reason` 선기록, `Route A/B` 승격 규칙, `Route C` 최소 worker/reviewer 요구 추가
- `WORKSPACE_CONTEXT.toml` 기반 맞춤형 workspace override 생성 지원
- macOS GitHub Actions에 `WORKSPACE_CONTEXT.toml` 기반 workspace 생성 검증 추가
- `.gitattributes` 추가로 `md`, `toml`, `yml`, `yaml`, `sh`, `ps1` 파일 LF 고정
- 자세한 내용은 [CHANGELOG.md](./CHANGELOG.md) 참고

---

## 설치전 README를 읽어보세요

## 빠른 시작

Windows PowerShell 을 관리자 권한으로 열고 아래 순서대로 실행하면 된다.

### 1. 전역 설치

한 번 설치하면 공통 기본 규칙이 모든 Codex 작업공간에 적용된다.

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령이 하는 일

- `%USERPROFILE%\.codex\AGENTS.md` 생성 또는 덮어쓰기
- `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 설정 설치
- `%USERPROFILE%\.codex\rules\*.rules` 기본 command rules 설치
- `%USERPROFILE%\.codex\multiagent-kit` 에 참고용 킷 복사

#### 서브에이전트 설정 파일

Codex가 공식 서브에이전트 역할을 제공하더라도, 이 킷은 동일한 역할 이름의 로컬 agent 파일을 함께 설치해 역할 정의와 지침을 명시적으로 유지한다.

현재 포함된 설정은 delegated subagent 를 `gpt-5.4-mini` 기준으로 맞추며, 메인 세션 모델은 변경하지 않는다.

#### 파괴적 명령 차단

Codex 전역 설치 시 `~/.codex/rules/default.rules` 도 함께 설치된다.

다음과 같은 파괴적 명령은 기본적으로 차단한다.

- `git reset --hard`
- `git checkout --`
- `git restore`
- `git clean`
- `rm -rf`
- `del /s /q`
- `Remove-Item -Recurse -Force`

이 규칙은 에이전트가 스스로 강제 되돌리기나 대규모 삭제를 수행하는 기본 흐름을 막기 위한 안전장치다.

### 2. 특정 작업공간 오버라이드 설치

전역 설치가 끝났다면, 실제 프로젝트 작업 전에 이 단계까지 이어서 적용하는 것을 기본으로 한다.
설치 전에 대상 작업공간 루트에 `WORKSPACE_CONTEXT.toml` 을 먼저 작성해 두는 것을 권장한다.

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령이 하는 일

- 해당 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- `STATE.md` 가 없으면 템플릿 기반으로 생성
- 전역 기본 규칙 위에 저장소 전용 오버라이드 추가
- `docs/codex-multiagent/` 참고 문서 복사

작업공간 루트에 `WORKSPACE_CONTEXT.toml` 이 있으면 설치기가 그 파일을 먼저 읽고, 그 내용으로 프로젝트에 맞는 `AGENTS.md` 와 초기 `STATE.md` 를 생성한다.
파일이 없으면 기존 오버라이드 템플릿 fallback 으로 동작하므로, 실제 프로젝트에 맞춘 설치를 원하면 먼저 `WORKSPACE_CONTEXT.toml` 을 준비해 두는 편이 좋다.

기본 템플릿은 `standard` 이고, 더 짧은 구성이 필요하면 끝에 `-Template minimal` 을 추가하면 된다.

동시 상한 기본값도 함께 들어간다.

- `explorer 3`
- `reviewer 2`
- `worker 4` 까지

#### 작업 크기 게이트

먼저 하드 트리거를 본다.

- API payload, 상태 이름, 이벤트 이름, 라우트, env key 변경
- 공용 타입, 공용 util, 공용 컴포넌트, import path, schema 변경
- UI + 서버처럼 레이어가 둘 이상 걸린 변경
- write set 을 자연스럽게 둘 이상으로 나눌 수 있는 변경
- 회귀 위험이 중간 이상인 변경

하드 트리거가 없으면 점수제를 쓴다.

- 수정 파일 `3+`
- 디렉터리 `2+`
- 새 파일 `2+`
- 테스트 수정 필요
- 코드 읽기 선행 필요
- 설계 결정 필요
- 검증 단계 `2+`

판정:

- `0~1점` -> `Route A`
- `2~3점` -> `Route B`
- `4점 이상` -> `Route C`

복붙용 명령만 따로 보려면 [POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md) 를 보면 된다.

### 3. macOS 전역 설치

macOS 에서도 `bash` 기준으로 전역 설치 후 작업공간 오버라이드까지 이어서 적용하는 흐름을 기본으로 본다.

```bash
curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh | bash -s -- install-global
```

이 명령이 하는 일

- `~/.codex/AGENTS.md` 생성 또는 덮어쓰기
- `~/.codex/agents/*.toml` 서브에이전트 설정 설치
- `~/.codex/rules/*.rules` 기본 command rules 설치
- `~/.codex/multiagent-kit` 에 참고용 킷 복사

특정 작업공간 오버라이드는 다음과 같이 이어서 설치하면 된다.

```bash
workspace="/path/to/your/workspace"; curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh | bash -s -- apply-workspace --workspace "$workspace" --include-docs
```

참고

- 로컬 저장소에서 직접 실행할 때는 `bash installer/CodexMultiAgent.sh install-global` 형태로 사용할 수 있다
- 테스트 격리를 위해 `CODEX_HOME=/tmp/codex-test-home/.codex` 같이 별도 경로를 지정할 수 있다
- CI나 검증용 브랜치에서는 `CODEX_MULTIAGENT_ZIP_URL` 로 bootstrap 대상 zip 경로를 override 할 수 있다
- GitHub Actions `macos-latest` 러너에서 전역 설치, workspace 오버라이드, `curl | bash` bootstrap 경로까지 실검증을 마쳤다

---

## 이 킷이 하는 일

Codex는 현재 `default`, `worker`, `explorer`, `reviewer` 같은 공식 서브에이전트 역할을 기본 제공한다.

이 저장소는 그 기본 기능을 대체하려는 것이 아니라, 실제 작업에서 덜 꼬이도록 운영 규칙을 덧씌우는 데 초점을 둔다.

이 킷이 추가로 제공하는 것은 다음과 같다.

- 전역 `AGENTS.md` 기본값
- 저장소별 `AGENTS.md` 오버라이드 템플릿
- `STATE.md` 기반 경량 task board
- `route + writer_slot + write_sets` 기반 실행 소유권 흐름
- `contract_freeze` 기반 공유 계약 고정 절차
- `MULTI_AGENT_LOG.md` 기반 역할 참여 기록
- 파괴적 명령 차단 rules
- 저장소별 검증 명령, 보안 규칙, 금지 경로를 넣기 위한 템플릿

---

## Codex 기본 설정과의 차이

Codex 기본 설정은 서브에이전트 역할과 호출 기능 자체를 제공한다.

이 킷은 그 위에 다음 운영 기준을 추가한다.

- 작은 작업은 `main` 단독 진행
- 작업 크기는 `하드 트리거 + 점수제` 로 먼저 분류
- 큰 작업은 `main planner-only` 로 전환
- `explorer`, `reviewer` 는 read-only 유지
- 큰 작업의 쓰기 변경은 `feature worker` 와 `worker_shared` 로 분리
- 공유 계약은 fan-out 전에 `main` 이 먼저 고정
- 멀티스텝 작업은 `STATE.md` 로 `route`, `writer_slot`, `contract_freeze`, `write_sets` 까지 추적
- 작업이 끝날 때 reviewer 확인 절차를 거치도록 유도
- 전역 규칙과 작업공간 예외 규칙을 계층적으로 관리

정리하면, Codex 기본 설정이 "서브에이전트를 사용할 수 있는 기반"이라면 이 킷은 "그 기반을 팀 규칙에 맞게 운영하는 틀"에 가깝다.

---

## 전역 + 작업공간 구조

핵심 구조는 두 층이다.

1. 전역 기본값
2. 작업공간 오버라이드

### 전역 기본값

`%USERPROFILE%\.codex\AGENTS.md` 또는 `~/.codex/AGENTS.md` 에 공통 멀티에이전트 규칙을 설치한다.

한 번 설치해 두면 기존 작업공간과 새 작업공간 모두에서 같은 기본 운영 규칙을 사용할 수 있다.

### 작업공간 오버라이드

특정 프로젝트 루트의 `AGENTS.md` 로 저장소별 예외 규칙을 추가한다.

이 킷은 실제 프로젝트 사용 기준으로 `전역 설치 -> 작업공간 오버라이드 설치` 순서를 기본 흐름으로 본다.
전역 설치만으로도 기본 규칙은 적용되지만, 실제 저장소 작업은 작업공간 오버라이드까지 반영하는 것을 필수 단계로 간주한다.
이때 작업공간 루트에 `WORKSPACE_CONTEXT.toml` 을 먼저 작성해 두어야 installer 가 프로젝트 방향성에 맞는 `AGENTS.md` 와 초기 `STATE.md` 를 생성할 수 있다.

작업공간 오버라이드는 공통 규칙 위에 다음 항목만 덧씌우는 용도로 설계되어 있다.

- worker 이름
- 검증 명령
- 공유 계약
- 금지 경로
- reviewer 확인 포인트
- 보안 또는 승인 규칙

한 줄로 정리하면 다음과 같다.

- 전역 설치 = 모든 작업공간에 공통으로 적용되는 기본값
- 작업공간 설치 = 실제 프로젝트 작업 전에 반드시 얹는 저장소 전용 규칙

---

## 왜 이런 구조를 쓰나

단순히 참고용 폴더를 복사하는 방식만으로는 Codex의 전역 규칙과 프로젝트 규칙이 안정적으로 분리되지 않는다.

실제로 적용되는 것은 `AGENTS.md` 계층이기 때문에, 전역은 전역 위치에, 프로젝트는 프로젝트 루트에 규칙 파일을 두는 편이 관리와 재사용 면에서 더 단순하다.

이 킷이 기본으로 잡는 운영 방향은 다음과 같다.

- 작은 작업은 `main` 단독 진행
- 작업 크기는 `하드 트리거 + 점수제` 로 먼저 분류
- 큰 작업은 `main planner-only` 로 전환
- `explorer`, `reviewer` 는 read-only 역할로 유지
- 큰 작업의 쓰기 변경은 `feature worker` 와 `worker_shared` 로 분리
- `STATE.md` 로 `current_task`, `route`, `writer_slot`, `contract_freeze`, `write_sets` 를 추적

여기서 라우트는 이렇게 본다.

- `Route A` = 작은 작업, `main` 직접 수정
- `Route B` = 경계 작업, `main` 직접 수정 + 필요시 read-only 보조
- `Route C` = 큰 작업, `main` 은 수정 안 하고 계약 고정/분배만 수행

큰 작업에선 `worker_shared` 가 공용 타입, 공용 util, 공용 컴포넌트, import 경로 같은 shared 자산을 전담한다.

---

## 템플릿 종류

### `standard`

일반적인 팀 저장소용 템플릿

- worker 매핑 칸 포함
- 검증 명령 칸 포함
- 공유 계약 칸 포함
- 금지 경로 칸 포함

### `minimal`

작은 저장소용 템플릿

- 꼭 필요한 항목만 남긴 버전
- 병렬화를 거의 사용하지 않는 흐름을 전제

### `WORKSPACE_CONTEXT.toml`

작업공간 오버라이드 설치 전에 프로젝트 방향성을 미리 적어두는 컨텍스트 파일

- 있으면 installer 가 먼저 읽어 맞춤형 `AGENTS.md` 생성
- 초기 `STATE.md` 도 같은 컨텍스트 기준으로 생성
- 없으면 기존 `WORKSPACE_OVERRIDE_TEMPLATE.md` 또는 `minimal` 템플릿 fallback 사용
- 실제 프로젝트에 맞는 오버라이드 설치를 원하면 작업공간 루트에 이 파일을 먼저 작성해 두는 것을 권장
- 예시는 [WORKSPACE_CONTEXT_TEMPLATE.toml](./WORKSPACE_CONTEXT_TEMPLATE.toml) 참고

#### 필수 항목 기준표

웹, 백엔드, 데이터, 인프라처럼 프로젝트 종류가 달라도 아래 항목은 공통으로 중요하다.

| 항목 | 필수 여부 | 의미 | 예시 |
| --- | --- | --- | --- |
| `workspace.name` | 필수 | 작업공간 식별 이름 | `billing-api`, `data-pipeline`, `jejugroup` |
| `workspace.summary` 또는 `brand.summary` | 필수 | 프로젝트 목적 한 줄 설명 | `결제 API 서버`, `배치 리포트 생성 파이프라인` |
| `architecture.source_of_truth` | 필수 | 실제 수정 기준이 되는 코드/폴더 | `src`, `app`, `services/api`, `infra/terraform` |
| `editing_rules.edit_in` | 필수 | 보통 수정이 허용되는 경로 | `src/**`, `scripts/**`, `jobs/**` |
| `editing_rules.do_not_edit` | 필수 | 직접 수정하면 안 되는 경로 | `dist/**`, `generated/**`, `vendor/**` |
| `verification.commands` 또는 `verification.recommended_commands` | 필수 | 최소 검증 명령 | `pnpm test`, `pytest`, `go test ./...`, `terraform validate` |
| `verification.manual_checks` | 권장 | 명령만으로 안 잡히는 확인 포인트 | `로그인 흐름`, `배치 결과 샘플 확인` |
| `workflow.authoring_model` | 권장 | 수정/배포 흐름 설명 | `src만 수정, dist는 산출물` |
| `triggers.hard` | 권장 | 큰 작업으로 봐야 하는 변경 | `API contract 변경`, `schema 변경`, `shared config 변경` |
| `approval.zones` | 권장 | 승인 필요 작업 | `deploy`, `db migration`, `external writes`, `prod secret 변경` |
| `workers.mapping` | 권장 | 작업 분리 힌트 | `worker_api = src/api/**`, `worker_data = jobs/**` |
| `reviewer.focus` | 권장 | 리뷰 우선 포인트 | `contract drift`, `regression`, `verification gaps` |

최소로 꼭 채우면 좋은 항목은 아래 여섯 개다.

- `workspace.name`
- `workspace.summary` 또는 `brand.summary`
- `architecture.source_of_truth`
- `editing_rules.edit_in`
- `editing_rules.do_not_edit`
- `verification.commands` 또는 `verification.recommended_commands`

#### 에이전트 요청 프롬프트

기존 프로젝트를 읽고 초안을 만들게 할 때는 아래 프롬프트를 그대로 써도 된다.

```text
이 프로젝트 폴더를 읽고 WORKSPACE_CONTEXT.toml 초안을 만들어줘.

반드시 아래 항목은 채워줘.
- workspace.name
- summary
- architecture.source_of_truth
- editing_rules.edit_in
- editing_rules.do_not_edit
- verification.commands or verification.recommended_commands

가능하면 아래도 채워줘.
- workflow.authoring_model
- verification.manual_checks
- triggers.hard
- approval.zones
- workers.mapping
- reviewer.focus
```

새 프로젝트라면 프로젝트 방향을 먼저 자연어로 설명한 뒤 아래처럼 요청하면 된다.

```text
내가 추구하는 프로젝트 방향을 바탕으로 WORKSPACE_CONTEXT.toml 초안 만들어줘.

반드시 아래 항목은 채워줘.
- workspace.name
- summary
- architecture.source_of_truth
- editing_rules.edit_in
- editing_rules.do_not_edit
- verification.commands or verification.recommended_commands

가능하면 아래도 채워줘.
- workflow.authoring_model
- verification.manual_checks
- triggers.hard
- approval.zones
- workers.mapping
- reviewer.focus
```

---

## 운영 장치

기본 규칙 외에도 다음 운영 장치를 함께 제공한다.

### 1. Task Board

무거운 큐 시스템 대신 가벼운 `STATE.md` 보드로 관리한다.

- `current_task`
- `next_tasks`
- `blocked_tasks`
- `route`
- `contract_freeze`

### 2. Route

작업 크기 게이트 결과는 라우트로 남긴다.

- `Route A = 작은 작업, main 직접 수정`
- `Route B = 경계 작업, main 직접 수정 + read-only 보조 가능`
- `Route C = 큰 작업, main planner-only + worker 분배`

### 3. Writer Slot + Write Sets

`Route A/B` 에선 단일 수정 주체를 `writer_slot` 으로 기록한다.

- `writer_slot = free`
- `writer_slot = main`
- `writer_slot = worker_name`

`Route C` 에선 병렬 쓰기를 `writer_slot = parallel` 과 `write_sets` 로 명시한다.

- `worker_feature_ui = [owned file globs]`
- `worker_feature_api = [owned file globs]`
- `worker_shared = [shared asset paths only]`

### 4. Contract Freeze

공유 계약은 `Route C` fan-out 전에, 또는 `Route A/B` handoff 전에 `main` 이 먼저 고정한다.

- API
- props
- schema
- env keys

### 5. Coordination Log

둘 이상 역할이 실제로 참여하면 `MULTI_AGENT_LOG.md` 에 handoff 와 결과를 append-only 로 남긴다.

---

## 포함 파일

- [GLOBAL_AGENTS_TEMPLATE.md](./GLOBAL_AGENTS_TEMPLATE.md)
  전역 기본 규칙 템플릿
- [WORKSPACE_OVERRIDE_TEMPLATE.md](./WORKSPACE_OVERRIDE_TEMPLATE.md)
  작업공간 오버라이드 템플릿
- [WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md](./WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md)
  최소 오버라이드 템플릿
- [AGENTS_TEMPLATE.md](./AGENTS_TEMPLATE.md)
  독립 저장소용 전체 템플릿
- [STATE_TEMPLATE.md](./STATE_TEMPLATE.md)
  `STATE.md` 경량 task board 템플릿
- [WORKSPACE_CONTEXT_TEMPLATE.toml](./WORKSPACE_CONTEXT_TEMPLATE.toml)
  작업공간 컨텍스트 파일 예시
- [MULTI_AGENT_GUIDE.md](./MULTI_AGENT_GUIDE.md)
  운영 가이드
- [CHANGELOG.md](./CHANGELOG.md)
  날짜/버전 기준 패치노트
- [installer/CodexMultiAgent.sh](./installer/CodexMultiAgent.sh)
  Codex macOS/Linux용 shell 설치기
- [installer/Bootstrap.sh](./installer/Bootstrap.sh)
  Codex macOS 원클릭 bootstrap
- [codex_rules/default.rules](./codex_rules/default.rules)
  Codex 기본 파괴적 명령 차단 rules
- [codex_agents/default.toml](./codex_agents/default.toml)
  Codex `default` 서브에이전트 설정 파일
- [codex_agents/worker.toml](./codex_agents/worker.toml)
  Codex `worker` 서브에이전트 설정 파일
- [codex_agents/explorer.toml](./codex_agents/explorer.toml)
  Codex `explorer` 서브에이전트 설정 파일
- [codex_agents/reviewer.toml](./codex_agents/reviewer.toml)
  Codex `reviewer` 서브에이전트 설정 파일
- [profiles/main.md](./profiles/main.md)
  `main` 역할 계약
- [profiles/explorer.md](./profiles/explorer.md)
  `explorer` 역할 계약
- [profiles/worker.md](./profiles/worker.md)
  `worker` 역할 계약
- [profiles/reviewer.md](./profiles/reviewer.md)
  `reviewer` 역할 계약
- [installer/CodexMultiAgent.ps1](./installer/CodexMultiAgent.ps1)
  Codex 설치 본체
- [installer/Bootstrap.ps1](./installer/Bootstrap.ps1)
  Codex 복붙용 부트스트랩
- [installer/POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md)
  Codex 복붙용 요약

---

## 잘 맞는 경우

- 여러 저장소에서 같은 멀티에이전트 운영 기준을 반복해서 사용하고 싶을 때
- 전역 공통 규칙은 유지하고 프로젝트별 차이만 따로 두고 싶을 때
- 새 저장소를 만들더라도 기본 멀티에이전트 규칙을 자동으로 적용하고 싶을 때
- 저장소마다 예외 규칙만 짧게 관리하고 싶을 때

## 과한 경우

- 혼자 쓰는 작은 실험 저장소
- 거의 항상 단일 파일만 수정하는 경우
- 멀티에이전트를 사실상 사용하지 않는 경우

---

## 커스터마이징 포인트

작업공간 오버라이드 설치 후 보통 다음 항목만 채우면 충분하다.

- worker 이름
- 검증 명령
- 공유 계약
- 금지 경로
- reviewer 확인 포인트

---

## 요약

전역 설치는 공통 기본값을 제공하고, 작업공간 설치는 그 위에 프로젝트별 예외 규칙을 얹는다.
실제 프로젝트 작업은 `전역 설치 -> 작업공간 오버라이드 설치` 순서를 기본으로 한다.

Codex의 공식 서브에이전트 기능을 그대로 활용하면서, 실제 팀 작업에 필요한 운영 규칙을 별도로 관리하고 싶다면 이 킷이 맞는다.
