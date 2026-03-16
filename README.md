# Codex Multi-Agent Kit ✅

Codex 멀티에이전트 규칙을 전역 기본값 + 프로젝트별 오버라이드 구조로 깔아주는 킷

> Global defaults for every workspace, local overrides only where needed

---

## 뭐하는 킷임

이거 핵심은 두 층 구조임

1. 전역 기본값
2. 작업공간 오버라이드

### 전역 기본값

`%USERPROFILE%\.codex\AGENTS.md` 에 공통 멀티에이전트 규칙 설치

이게 진짜 전역 설치임
한 번 깔아두면 기존 작업공간이든 새 작업공간이든 Codex 기본 규칙으로 같이 먹는 구조

### 작업공간 오버라이드

특정 프로젝트 루트의 `AGENTS.md`

이건 공통 규칙 위에
그 저장소만의 worker 이름, 검증 명령, 공유 계약, 금지 경로 같은 것만 덧씌우는 용도

한 줄로 말하면 이거

- 전역 설치 = 모든 작업공간 공통 기본값
- 작업공간 설치 = 특정 저장소 예외 규칙

---

## 왜 이런 구조냐

예전 방식처럼 `전역 킷 폴더만 복사`하면
그건 그냥 보관소지 전역 적용이 아님

실제로 먹는 건 `AGENTS.md` 계층이라서
전역은 전역 위치에 `AGENTS.md`
프로젝트는 프로젝트 위치에 `AGENTS.md`
이렇게 가야 덜 멍청함

이 킷이 잡아주는 기본 방향도 단순함

- 기본은 `main` 단독 진행
- `write scope` 겹치면 병렬화 금지
- `explorer`, `reviewer` 는 read-only
- 쓰기 변경은 reviewer 검수 후 종료

---

## 빠른 시작

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

### 1. 전역 설치

이거 한 번이면 공통 기본 규칙이 모든 Codex 작업공간에 적용

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령이 하는 일

- `%USERPROFILE%\.codex\AGENTS.md` 생성 또는 덮어쓰기
- `%USERPROFILE%\.codex\multiagent-kit` 에 참고용 킷 복사

### 2. 특정 작업공간 오버라이드 설치

이건 그 프로젝트만의 규칙이 필요할 때만 쓰면 됨

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령이 하는 일

- 해당 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- 전역 기본 규칙 위에 저장소 전용 오버라이드 추가
- `docs/codex-multiagent/` 참고 문서 복사

기본 템플릿은 `standard`
더 짧은 게 좋으면 끝에 `-Template minimal` 추가하면 됨

복붙용만 따로 보고 싶으면 [POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md) 보면 됨

---

## Antigravity도 있음

Antigravity 쪽은 Codex처럼 새 모델을 까는 방식 아님
런타임이 읽는 전역 규칙 파일과 역할 정의 파일을 깔아두는 방식

- 전역 기본값은 `%USERPROFILE%\.gemini\antigravity\AGENTS.md`
- 역할 정의는 `%USERPROFILE%\.gemini\antigravity\global_workflows\multiagent-defaults.md`
- 역할 스킬은 `%USERPROFILE%\.gemini\antigravity\skills\multiagent-roles.md`
- 프로젝트별 예외는 작업공간 `AGENTS.md`

명령어는 [ANTIGRAVITY_INSTALL.md](./installer/ANTIGRAVITY_INSTALL.md) 참고

즉 설치 결과는 멀티에이전트 역할과 분할 규칙을 런타임에 주입하는 축

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

## 포함 파일

- [GLOBAL_AGENTS_TEMPLATE.md](./GLOBAL_AGENTS_TEMPLATE.md)
  전역 기본 규칙 템플릿
- [WORKSPACE_OVERRIDE_TEMPLATE.md](./WORKSPACE_OVERRIDE_TEMPLATE.md)
  작업공간 오버라이드 템플릿
- [WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md](./WORKSPACE_OVERRIDE_MINIMAL_TEMPLATE.md)
  최소 오버라이드 템플릿
- [AGENTS_TEMPLATE.md](./AGENTS_TEMPLATE.md)
  독립 저장소용 전체 템플릿
- [MULTI_AGENT_GUIDE.md](./MULTI_AGENT_GUIDE.md)
  운영 가이드
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
- [installer/AntigravityMultiAgent.ps1](./installer/AntigravityMultiAgent.ps1)
  Antigravity 설치 본체
- [installer/AntigravityBootstrap.ps1](./installer/AntigravityBootstrap.ps1)
  Antigravity 복붙용 부트스트랩
- [installer/ANTIGRAVITY_INSTALL.md](./installer/ANTIGRAVITY_INSTALL.md)
  Antigravity 복붙용 요약

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

오버라이드 설치 후 보통 이것만 채우면 충분

- worker 이름
- 검증 명령
- 공유 계약
- 금지 경로
- reviewer 확인 포인트

---

## 한 줄 요약

전역 설치는 진짜 글로벌 기본값이고
작업공간 설치는 그 위에 얹는 프로젝트별 예외 규칙임
