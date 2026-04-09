# Codex Multi-Agent Kit ✅

Codex의 공식 서브에이전트 기능 위에, 팀과 저장소 단위의 운영 규칙을 전역 기본값 + 프로젝트별 오버라이드 구조로 적용하는 킷

> Global defaults for every workspace, local overrides only where needed

---

## 최근 패치

- `v0.4.0 - 2026-04-09`
- `Route A/B` 대신 점수 기반 `orchestration profile` 흐름으로 전환
- `STATE.md` 와 installer 생성 템플릿에 `score_total`, `hard_triggers`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget` 추적 반영
- 자동 delegation, 자동 skill routing, 자연어 override 우선 규칙을 문서와 예시에 통일
- PowerShell installer 실생성 검증으로 새 `AGENTS.md` / `STATE.md` 출력 확인
- `codex_skills/ouroboros-*` spec-first workflow skeleton 추가
- append-only `ERROR_LOG.md` 템플릿과 workspace `error_log_path` 지원 추가
- 자세한 내용은 [CHANGELOG.md](./CHANGELOG.md) 참고

---

## Acknowledgements

이 저장소는 Ouroboros 전체 런타임을 배포하지 않고 선택한 아이디어만 재구성한다. 이 킷의 spec-first workflow와 일부 skill/rule 설계는 [Q00/ouroboros](https://github.com/Q00/ouroboros)에서 참고하고 포팅했다.
Ouroboros-derived portion에 적용되는 MIT 원문은 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)를 보면 된다.

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

- 기존 `%USERPROFILE%\.codex\AGENTS.md`, `config.toml`, installer 관리 대상 `agents/*.toml` 을 백업 후 새 구조 기준으로 재생성
- `%USERPROFILE%\.codex\config.toml` 의 필요한 키를 patch 해서 `AGENTS.md` 발견 우선순위, `multi_agent` 기본값, 그리고 `AGENTS.md`를 우선 읽고 집행하는 execution requirements 를 맞춤
- `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 설정 설치 및 레거시 추가 agent 정리
- `%USERPROFILE%\.codex\rules\*.rules` 기본 command rules 설치
- `%USERPROFILE%\.codex\skills\ouroboros-*` spec-first workflow skill 설치
- `%USERPROFILE%\.codex\multiagent-kit` 에 참고용 킷 복사

#### 서브에이전트 설정 파일

Codex가 공식 서브에이전트 역할을 제공하더라도, 이 킷은 동일한 역할 이름의 로컬 agent 파일을 함께 설치해 역할 정의와 지침을 명시적으로 유지한다.

현재 포함된 설정은 역할을 고정 캡으로 묶지 않고, 작업 점수와 선택된 규칙에 따라 자동 delegation 되도록 맞춘다. 메인 세션 모델은 변경하지 않는다.

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

- 기존 작업공간의 `AGENTS.md` 와 `STATE.md` 를 백업 후 새 구조 기준으로 재생성
- 전역 기본 규칙 위에 저장소 전용 오버라이드 추가
- `ERROR_LOG.md` 가 없으면 append-only 에러 로그 파일을 생성
- `docs/codex-multiagent/` 참고 문서 복사

작업공간 루트에 `WORKSPACE_CONTEXT.toml` 이 있으면 설치기가 그 파일을 먼저 읽고, 그 내용으로 프로젝트에 맞는 `AGENTS.md` 와 초기 `STATE.md` 를 생성한다.
파일이 없으면 installer 내장 fallback 규칙으로 동작하므로, 실제 프로젝트에 맞춘 설치를 원하면 먼저 `WORKSPACE_CONTEXT.toml` 을 준비해 두는 편이 좋다.
`WORKSPACE_CONTEXT.toml` 작성 기준표와 프롬프트는 [WORKSPACE_CONTEXT_GUIDE.md](./docs/WORKSPACE_CONTEXT_GUIDE.md) 참고.

기본 생성 모드는 `standard` 이고, 더 짧은 구성이 필요하면 끝에 `-Template minimal` 을 추가하면 된다.

동시 상한 기본값도 함께 들어간다.

- 역할별 고정 상한 대신 작업별 `agent_budget` 를 계산한다
- 예산은 `score_total`, `write_set` 분리 가능성, `execution_topology`, `hard_triggers` 로 산정한다
- `bounded_repair_loop` 안에서는 남은 예산만 재사용하고, 필요 시에만 추가 배정을 허용한다

#### 작업 크기 게이트

먼저 하드 트리거를 본다.

- API payload, 상태 이름, 이벤트 이름, 라우트, env key 변경
- API payload, 상태 이름, 이벤트 이름, orchestration profile, env key 변경
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

- `0~3점` -> `single-session`
- `4~6점` -> `delegated-serial`
- `7점 이상`, 또는 하드 트리거 -> `delegated-parallel` 또는 `mixed`

실제 worker/reviewer/explorer 수는 이 판정 뒤에 `agent_budget` 으로 정한다.

복붙용 명령만 따로 보려면 [POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md) 를 보면 된다.

### 3. macOS 전역 설치

macOS 에서도 `bash` 기준으로 전역 설치 후 작업공간 오버라이드까지 이어서 적용하는 흐름을 기본으로 본다.

```bash
curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh | bash -s -- install-global
```

이 명령이 하는 일

- `~/.codex/AGENTS.md` 생성 또는 덮어쓰기
- `~/.codex/config.toml` 의 필요한 키를 patch 해서 `AGENTS.md` 발견 우선순위, `multi_agent` 기본값, 그리고 `AGENTS.md`를 우선 읽고 집행하는 execution requirements 를 맞춤
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
- 전역 설치 백업은 `~/.codex/backups/<timestamp>/global`, 작업공간 오버라이드 백업은 `<workspace>/.codex-backups/<timestamp>/workspace` 아래에 남긴다

---

## 이 킷이 하는 일

Codex는 현재 `default`, `worker`, `explorer`, `reviewer` 같은 공식 서브에이전트 역할을 기본 제공한다.

이 저장소는 그 기본 기능을 대체하려는 것이 아니라, 실제 작업에서 덜 꼬이도록 운영 규칙을 덧씌우는 데 초점을 둔다.

이 킷이 추가로 제공하는 것은 다음과 같다.

- 전역 `AGENTS.md` 기본값
- 전역 `config.toml` patch
- 전역 `codex_skills/ouroboros-*` spec-first workflow skill
- 저장소별 `AGENTS.md` 오버라이드 생성
- `STATE.md` 기반 경량 task board
- `score-based orchestration profile + writer_slot + write_sets` 기반 실행 소유권 흐름
- `contract_freeze` 기반 공유 계약 고정 절차
- `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget` 추적
- `MULTI_AGENT_LOG.md` 기반 역할 참여 기록
- `ERROR_LOG.md` 기반 append-only 작업 오류 기록
- 파괴적 명령 차단 rules
- 저장소별 검증 명령, 보안 규칙, 금지 경로를 넣기 위한 템플릿

---

## Codex 기본 설정과의 차이

Codex 기본 설정은 서브에이전트 역할과 호출 기능 자체를 제공한다.

이 킷은 그 위에 다음 운영 기준을 추가한다.

- 작은 작업은 `single-session` profile 로 처리하고 필요할 때만 delegation 을 켠다
- 작업 크기는 `하드 트리거 + 점수제` 로 먼저 분류
- `selected_rules` 가 `review_required` 를 켤 때만 reviewer 를 필수로 만든다
- `selected_skills` 는 사용자 명령이 아니라 작업 상태에 따라 자동 선택한다
- 큰 작업의 쓰기 변경은 필요할 때 `feature worker` 와 `worker_shared` 로 분리한다
- 공유 계약은 fan-out 전에 `main` 이 먼저 고정
- 멀티스텝 작업은 `STATE.md` 로 `writer_slot`, `contract_freeze`, `write_sets`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget` 까지 추적
- 큰 작업이 끝날 때 reviewer 확인 절차를 거치도록 유도한다
- 사용자 자연어 override 는 자동 skill routing 과 delegation 판단보다 우선한다
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

- 작은 작업은 `single-session` profile 로 처리
- 작업 크기는 `하드 트리거 + 점수제` 로 먼저 분류
- 큰 작업은 `delegated-serial`, `delegated-parallel`, `mixed` 중 하나로 전환
- `explorer`, `reviewer` 는 필요할 때만 활성화되는 역할로 유지
- 큰 작업의 쓰기 변경은 필요할 때 `feature worker` 와 `worker_shared` 로 분리
- `STATE.md` 로 `current_task`, `writer_slot`, `contract_freeze`, `write_sets`, `selected_rules`, `selected_skills`, `execution_topology`, `agent_budget` 를 추적

여기서 실행 프로필은 이렇게 본다.

- `single-session` = 작은 작업, `main`만 직접 수정하는 경로
- `delegated-serial` = 큰 작업이지만 순차 위임이 더 안전한 경로
- `delegated-parallel` = 계약이 고정된 뒤 병렬 위임이 가능한 경로
- `mixed` = 순차와 병렬을 섞어 쓰는 경로

shared 자산이 실제로 걸릴 때만 `worker_shared` 가 공용 타입, 공용 util, 공용 컴포넌트, import 경로 같은 자산을 전담한다.

---

## 템플릿 종류

### `standard`

일반적인 팀 저장소용 기본 생성 모드

- 저장소 사실값, 검증, 승인 구역, worker ownership 을 더 많이 적는 쪽
- `WORKSPACE_CONTEXT.toml` 이 있으면 그 값을 기반으로 풍부하게 생성
- 없으면 installer 내장 fallback 규칙으로 생성

### `minimal`

작은 저장소용 축약 생성 모드

- 꼭 필요한 항목만 남긴 버전
- 병렬화를 거의 사용하지 않는 흐름을 전제
- `WORKSPACE_CONTEXT.toml` 이 없을 때도 더 짧은 fallback 을 원하면 사용

### `WORKSPACE_CONTEXT.toml`

작업공간 오버라이드 설치 전에 프로젝트 방향성을 미리 적어두는 컨텍스트 파일

- 있으면 installer 가 먼저 읽어 맞춤형 `AGENTS.md` 생성
- 초기 `STATE.md` 도 같은 컨텍스트 기준으로 생성
- 없으면 installer 내장 fallback 생성 규칙 사용
- 실제 프로젝트에 맞는 오버라이드 설치를 원하면 작업공간 루트에 이 파일을 먼저 작성해 두는 것을 권장
- 예시는 [WORKSPACE_CONTEXT_TEMPLATE.toml](./WORKSPACE_CONTEXT_TEMPLATE.toml) 참고
- 작성 기준표와 프롬프트는 [docs/WORKSPACE_CONTEXT_GUIDE.md](./docs/WORKSPACE_CONTEXT_GUIDE.md) 참고

---

## 운영 장치

기본 규칙 외에도 다음 운영 장치를 함께 제공한다.

### 1. Task Board

무거운 큐 시스템 대신 가벼운 `STATE.md` 보드로 관리한다.

- `current_task`
- `next_tasks`
- `blocked_tasks`
- `orchestration_profile`
- `contract_freeze`
- `writer_slot`
- `write_sets`
- `selected_rules`
- `selected_skills`
- `execution_topology`
- `agent_budget`

### 2. Orchestration Profile

작업 크기 게이트 결과는 orchestration profile 로 남긴다.

- `single-session = 작은 작업, main 직접 수정`
- `delegated-serial = 큰 작업, 순차 위임`
- `delegated-parallel = 계약이 고정된 뒤 병렬 위임`
- `mixed = 순차 + 병렬 혼합`

### 3. Writer Slot + Write Sets

`single-session` 에선 단일 수정 주체를 `writer_slot` 으로 기록한다.

- `writer_slot = free`
- `writer_slot = main`
- `writer_slot = worker_name`

delegated profile 에선 병렬 쓰기를 `writer_slot = parallel` 과 `write_sets` 로 명시한다.

- `worker_feature_ui = [owned file globs]`
- `worker_feature_api = [owned file globs]`
- `worker_shared = [shared asset paths only]`

### 4. Contract Freeze

공유 계약은 delegation fan-out 전에, 또는 단일 작업을 worker 에 넘기기 전에 `main` 이 먼저 고정한다.

- API
- props
- schema
- env keys

### 5. Coordination Log

둘 이상 역할이 실제로 참여하면 `MULTI_AGENT_LOG.md` 에 handoff 와 결과를 append-only 로 남긴다.

### 6. Error Log

작업 흐름에 영향을 주는 실행, 설치, 도구, 검증 오류는 `ERROR_LOG.md` 에 append-only 로 남긴다.

- 기본 경로는 작업공간 루트에 생성되는 `ERROR_LOG.md`
- `WORKSPACE_CONTEXT.toml` 에서 `error_log_path` 로 상대 경로 override 가능
- 중단되거나 잠깐 보류된 오류는 `open` 또는 `deferred` 로 유지하고, 나중 append 로 `resolved` 처리

### 7. Spec-First + Subagent Hygiene

이제 기본 운영 규칙에는 다음도 포함된다.

- `interview -> seed -> run -> evaluate` skeleton
- 비작은 작업에서 계약 고정 후 구현 진입
- 끝난 agent 즉시 정리
- reviewer 는 가능하면 마지막에 spawn
- worker 당 write set 하나 유지
- `fork_context` 남발 금지

---

## 포함 파일

- [AGENTS.md](./AGENTS.md)
  전역 기본 규칙의 canonical 원본
- [WORKSPACE_CONTEXT_TEMPLATE.toml](./WORKSPACE_CONTEXT_TEMPLATE.toml)
  작업공간 컨텍스트 파일 예시
- [examples/micro-seed.md](./examples/micro-seed.md): seed 예시만 둔다
- 루트의 `STATE.md`, `SEED.yaml`, `MULTI_AGENT_LOG.md`, `ERROR_LOG.md` 는 런타임에서 생성되거나 무시되는 파일이다
- [docs/WORKSPACE_CONTEXT_GUIDE.md](./docs/WORKSPACE_CONTEXT_GUIDE.md)
  `WORKSPACE_CONTEXT.toml` 기준표와 작성 프롬프트
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
- [codex_skills/ouroboros-interview/SKILL.md](./codex_skills/ouroboros-interview/SKILL.md)
  spec-first 인터뷰 단계 skill
- [codex_skills/ouroboros-seed/SKILL.md](./codex_skills/ouroboros-seed/SKILL.md)
  seed 고정 단계 skill
- [codex_skills/ouroboros-run/SKILL.md](./codex_skills/ouroboros-run/SKILL.md)
  orchestration-aware 실행 진입 skill
- [codex_skills/ouroboros-evaluate/SKILL.md](./codex_skills/ouroboros-evaluate/SKILL.md)
  seed 기준 staged verification skill
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
- 사용자 명령이 아니라 에이전트 내부 판단으로 delegation 을 처리하고 싶을 때

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
전역 설치는 `AGENTS.md`, `config.toml`, installer 관리 대상 `agents/*.toml` 을 백업 후 새 구조로 다시 맞추고, 작업공간 설치는 `AGENTS.md` 와 `STATE.md` 를 백업 후 재생성한다.

Codex의 공식 서브에이전트 기능을 그대로 활용하면서, 실제 팀 작업에 필요한 운영 규칙을 별도로 관리하고 싶다면 이 킷이 맞는다.
