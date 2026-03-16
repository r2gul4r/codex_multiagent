# Codex Multi-Agent Kit ✅

Codex 멀티에이전트 운영 규칙을 여러 저장소에 빠르게 깔아 넣는 킷

> Reusable multi-agent bootstrap kit for Codex repositories

---

## 뭐하는 킷임

이거 하나로 두 가지를 처리함

1. 전역 기본 킷 설치
2. 원하는 작업공간에만 `AGENTS.md` 적용

즉, 공용 규칙은 한 군데 모아두고
실제 멀티에이전트 설정은 필요한 저장소에만 박는 흐름

AI 에이전트 여러 개 돌린다고 무조건 좋아지는 거 아님
대충 병렬화하면 오히려 더 꼬임

그래서 이 킷은 이런 기준을 강제로 잡아주는 쪽

- 기본은 `main` 단독 진행
- `write scope` 겹치면 병렬화 금지
- `explorer`, `reviewer` 는 read-only
- 쓰기 변경은 reviewer 검수로 닫기

---

## 왜 쓰는 거냐

이런 귀찮은 일 줄이려고 만든 거

- 저장소마다 `AGENTS.md` 처음부터 다시 쓰기
- 역할 이름만 많고 책임이 흐려지는 문서 만들기
- worker 여러 개 던졌다가 파일 범위 겹쳐서 다시 합치기
- reviewer 한테 뒤늦게 구조 수리 맡기기

한마디로

멀티에이전트를 많이 쓰는 게 목적이 아니라
덜 꼬이게 쓰는 게 목적

> The goal is not more agents, but fewer collisions

---

## 설치 방식

문서 기준 빠른 시작은 두 개만 생각하면 됨

1. 전역 설치
2. 특정 작업공간 설치

괜히 모드 많아 보이게 늘어놓지 않고
처음 보는 사람이 바로 따라치게 만드는 쪽

---

## 빠른 시작

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

### 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령 하나로

- 최신 킷 다운로드
- `%USERPROFILE%\.codex\multiagent-kit` 전역 설치

까지 처리

### 2. 특정 작업공간 설치

여기서는 작업공간 경로만 바꾸면 됨

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령 하나로

- 최신 킷 다운로드
- 지정 작업공간에 `AGENTS.md` 설치
- `docs/codex-multiagent/` 참고 문서 복사

까지 처리

더 짧게 보려면 [POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md) 보면 됨

기본 템플릿은 `standard`
더 짧은 걸 원하면 끝에 `-Template minimal` 추가하면 됨

---

## 템플릿 종류

### `standard`

일반적인 팀 저장소용

- `main`, `explorer`, `worker`, `reviewer` 기준 포함
- 병렬화 체크리스트 포함
- 공유 계약 규칙 포함

### `minimal`

작은 저장소나 개인 프로젝트용

- 최대한 짧게 감
- 기본 흐름만 남김
- 병렬화는 거의 안 하는 전제

---

## 적용하면 뭐 생김

기본적으로는

- 작업공간 루트에 `AGENTS.md`

`-IncludeDocs` 옵션까지 켜면 추가로

- `docs/codex-multiagent/README.md`
- `docs/codex-multiagent/MULTI_AGENT_GUIDE.md`
- `docs/codex-multiagent/profiles/*`
- `docs/codex-multiagent/examples/*`

---

## 포함 파일

- [AGENTS_TEMPLATE.md](./AGENTS_TEMPLATE.md)
  표준 `AGENTS.md` 템플릿
- [MULTI_AGENT_GUIDE.md](./MULTI_AGENT_GUIDE.md)
  왜 이런 규칙을 쓰는지 설명하는 운영 가이드
- [profiles/main.md](./profiles/main.md)
  `main` 역할 계약
- [profiles/explorer.md](./profiles/explorer.md)
  `explorer` 역할 계약
- [profiles/worker.md](./profiles/worker.md)
  `worker` 역할 계약
- [profiles/reviewer.md](./profiles/reviewer.md)
  `reviewer` 역할 계약
- [examples/AGENTS.example.md](./examples/AGENTS.example.md)
  큰 저장소 예시
- [examples/AGENTS.minimal.example.md](./examples/AGENTS.minimal.example.md)
  작은 저장소 예시
- [installer/CodexMultiAgent.ps1](./installer/CodexMultiAgent.ps1)
  실제 설치 스크립트
- [installer/Bootstrap.ps1](./installer/Bootstrap.ps1)
  GitHub에서 최신 킷을 내려받아 설치까지 연결하는 부트스트랩 스크립트
- [installer/POWERSHELL_INSTALL.md](./installer/POWERSHELL_INSTALL.md)
  복붙용 요약본

---

## 언제 잘 맞냐

- 여러 저장소에 같은 멀티에이전트 규칙을 반복 적용할 때
- 역할 분리와 병렬화 기준을 문서로 고정하고 싶을 때
- UI, API, 데이터 계약이 자주 엮여서 먼저 가드가 필요할 때
- 새 저장소에 `AGENTS.md` 빨리 넣고 싶은데 매번 새로 쓰기 싫을 때

## 언제 굳이 필요 없냐

- 혼자 쓰는 작은 실험 저장소
- 단일 파일 수정 위주
- 질문 답변, 조사, 메모가 대부분인 작업
- 공유 계약이 아직 계속 흔들리는 초반 프로토타입

---

## 커스터마이징 포인트

적용한 뒤 최소한 이것만 손보면 됨

- worker 이름을 저장소 구조에 맞게 바꾸기
- 검증 명령을 실제 저장소 명령으로 바꾸기
- 공유 계약 목록 적기
- 수정 금지 경로나 위험 경로 적기
- reviewer 가 반드시 볼 항목 적기

---

## 참고 메모

- 전역 킷이 이미 있으면 설치 스크립트는 그걸 우선 사용
- 전역 킷이 없으면 현재 저장소 복사본 기준으로 동작
- 예전 `exe` 방식 흔적이 전역 폴더에 남아 있으면 설치 시 자동 정리
- 바이너리 대신 스크립트 중심이라 나중에 직접 뜯어고치기 쉬움

---

## 한 줄 요약

`AGENTS.md` 템플릿 복붙 도구가 아니라
멀티에이전트 운영 기준을 덜 멍청하게 재사용하려는 킷
