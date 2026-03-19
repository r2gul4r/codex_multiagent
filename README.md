# Codex Multi-Agent Kit ✅

Codex 멀티에이전트 규칙을 전역 기본값 + 프로젝트별 오버라이드 구조로 깔아주는 킷

> Global defaults for every workspace, local overrides only where needed

---

## 최근 패치

- `v0.1.3 - 2026-03-19`
- macOS용 `bash` 설치기 `installer/CodexMultiAgent.sh` 추가
- `curl | bash` 원클릭용 `installer/Bootstrap.sh` 추가
- GitHub Actions `macos-latest` 기반 설치 검증 워크플로우 추가 및 실검증 통과
- 안티그래비티 관련 파일/설치 문서/스크립트 제거, Codex 전용 킷으로 정리
- 자세한 내용은 [CHANGELOG.md](./CHANGELOG.md) 참고

---

## 뭐하는 킷임

핵심은 두 층 구조임

1. 전역 기본값
2. 작업공간 오버라이드

### 전역 기본값

`%USERPROFILE%\.codex\AGENTS.md` 에 공통 멀티에이전트 규칙 설치

전역 설치는 여기 기준임
한 번 깔아두면 기존 작업공간이든 새 작업공간이든 Codex 기본 규칙이 같이 적용되는 구조

### 작업공간 오버라이드

특정 프로젝트 루트의 `AGENTS.md`

작업공간 오버라이드는 공통 규칙 위에
그 저장소만의 worker 이름, 검증 명령, 공유 계약, 금지 경로 같은 것만 덧씌우는 용도

한 줄 요약하면

- 전역 설치 = 모든 작업공간 공통 기본값
- 작업공간 설치 = 특정 저장소 예외 규칙

---

## 왜 이런 구조냐

예전 방식처럼 `전역 킷 폴더만 복사`하면
그건 그냥 보관소지 전역 적용이 아님

실제로 먹는 건 `AGENTS.md` 계층이라서
전역은 전역 위치에 `AGENTS.md`
프로젝트는 프로젝트 위치에 `AGENTS.md`
이렇게 가야 덜 꼬임

이 킷이 잡아주는 기본 방향도 단순함

- 기본은 `main` 단독 진행
- `write scope` 겹치면 병렬화 금지
- `explorer`, `reviewer` 는 read-only
- 쓰기 변경은 reviewer 검수 후 종료
- 동시 상한은 `explorer 3`, `reviewer 2`, `writer 1`
- `STATE.md` 로 `current_task`, `writer_slot`, `contract_freeze` 추적

여기서 `writer` 는 실제로 코드나 파일을 쓰는 역할 전체를 뜻함

- `main` 이 직접 수정하면 `main` 이 writer 슬롯 사용
- `worker` 에 위임하면 그 `worker` 가 writer 슬롯 사용
- 둘이 동시에 쓰는 건 금지

---

## 빠른 시작

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 실행하면 됨

### 1. 전역 설치

한 번 설치하면 공통 기본 규칙이 모든 Codex 작업공간에 적용

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령이 하는 일

- `%USERPROFILE%\.codex\AGENTS.md` 생성 또는 덮어쓰기
- `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 설정 설치
- `%USERPROFILE%\.codex\rules\*.rules` 기본 command rules 설치
- `%USERPROFILE%\.codex\multiagent-kit` 에 참고용 킷 복사

#### 기본 서브에이전트 모델 패치

- Codex 전역 설치 시 built-in 서브에이전트 `default`, `worker`, `explorer`, `reviewer` 오버라이드 같이 설치
- 이 오버라이드는 서브에이전트 모델만 `gpt-5.4-mini` 로 고정
- 메인 세션 모델은 안 건드림
- 즉 `main` 은 기존 `config.toml` 설정을 그대로 쓰고, delegated subagent 만 더 가벼운 모델로 내려감

#### 기본 파괴적 명령 차단

- Codex 전역 설치 시 `~/.codex/rules/default.rules` 같이 설치
- `git reset --hard`, `git checkout --`, `git restore`, `git clean`, `rm -rf`, `del /s /q`, `Remove-Item -Recurse -Force` 같은 파괴적 명령은 기본 `forbidden`
- 즉 에이전트가 스스로 디스크 삭제나 강제 되돌리기 명령을 치는 기본 흐름을 막는 용도

### 2. 특정 작업공간 오버라이드 설치

이건 프로젝트별 규칙이 따로 필요할 때만 쓰면 됨

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령이 하는 일

- 해당 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- `STATE.md` 가 없으면 템플릿 기반으로 생성
- 전역 기본 규칙 위에 저장소 전용 오버라이드 추가
- `docs/codex-multiagent/` 참고 문서 복사

기본 템플릿은 `standard`
더 짧은 게 좋으면 끝에 `-Template minimal` 추가하면 됨

동시 상한 기본값도 같이 깔림

- `explorer 3`
- `reviewer 2`
- `writer 1`

복붙용만 따로 보려면 [POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md) 보면 됨

### 3. macOS 전역 설치

macOS 에서는 `bash` 기준으로 한 줄 설치 가능

```bash
curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh | bash -s -- install-global
```

이 명령이 하는 일

- `~/.codex/AGENTS.md` 생성 또는 덮어쓰기
- `~/.codex/agents/*.toml` 서브에이전트 설정 설치
- `~/.codex/rules/*.rules` 기본 command rules 설치
- `~/.codex/multiagent-kit` 에 참고용 킷 복사

특정 작업공간 오버라이드는 이렇게 설치하면 됨

```bash
workspace="/path/to/your/workspace"; curl -fsSL https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.sh | bash -s -- apply-workspace --workspace "$workspace" --include-docs
```

참고

- 로컬 저장소에서 직접 실행할 때는 `bash installer/CodexMultiAgent.sh install-global` 형태로 사용 가능
- 테스트 격리를 위해 `CODEX_HOME=/tmp/codex-test-home/.codex` 같이 별도 경로 지정 가능
- CI나 검증용 브랜치에서는 `CODEX_MULTIAGENT_ZIP_URL` 로 bootstrap 대상 zip 경로 override 가능
- GitHub Actions `macos-latest` 러너에서 전역 설치, workspace 오버라이드, `curl | bash` bootstrap 경로까지 실검증 완료

---

## 템플릿 종류

### `standard`

일반적인 팀 저장소용

- worker 매핑 칸 포함
- 검증 명령 칸 포함
- 공유 계약 칸 포함
- 금지 경로 칸 포함

### `minimal`

작은 저장소용

- 정말 필요한 칸만 남긴 버전
- 병렬화 거의 안 하는 흐름 전제

---

## 운영 장치 3개

기본 규칙 말고 운영 장치도 같이 들어감

### 1. Task Board

무거운 큐 시스템까지는 안 가고
가벼운 `STATE.md` 보드로 관리

- `current_task`
- `next_tasks`
- `blocked_tasks`

### 2. Writer Slot

실제로 코드나 파일을 쓰는 역할은 항상 하나만

- `writer_slot = free`
- `writer_slot = main`
- `writer_slot = worker_name`

### 3. Contract Freeze

공유 계약은 writer 슬롯 넘기기 전에 `main` 이 먼저 고정

- API
- props
- schema
- env keys

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
  Codex 기본 서브에이전트 모델 오버라이드
- [codex_agents/worker.toml](./codex_agents/worker.toml)
  Codex `worker` 서브에이전트 모델 오버라이드
- [codex_agents/explorer.toml](./codex_agents/explorer.toml)
  Codex `explorer` 서브에이전트 모델 오버라이드
- [codex_agents/reviewer.toml](./codex_agents/reviewer.toml)
  Codex `reviewer` 서브에이전트 모델 오버라이드
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

## 언제 잘 맞냐

- 여러 저장소에서 같은 멀티에이전트 기준을 반복 쓰고 싶을 때
- 전역 공통 규칙은 유지하고 프로젝트별 차이만 따로 두고 싶을 때
- 새 저장소를 만들어도 기본 멀티에이전트 규칙이 자동 적용되길 원할 때
- 저장소마다 예외 규칙만 짧게 관리하고 싶을 때

## 언제 굳이 필요 없냐

- 혼자 쓰는 작은 실험 저장소
- 거의 항상 단일 파일 수정만 하는 경우
- 멀티에이전트를 사실상 안 쓰는 경우

---

## 커스터마이징 포인트

오버라이드 설치 후 보통 이것만 채우면 충분함

- worker 이름
- 검증 명령
- 공유 계약
- 금지 경로
- reviewer 확인 포인트

---

## 한 줄 요약

전역 설치는 진짜 글로벌 기본값이고
작업공간 설치는 그 위에 얹는 프로젝트별 예외 규칙임
