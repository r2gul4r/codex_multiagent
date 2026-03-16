# Codex Multi-Agent Kit

여러 저장소에 Codex 멀티에이전트 워크플로를 적용하기 위한 재사용 문서와 PowerShell 기반 설치 도구 모음

Reusable docs and a PowerShell-based installer for setting up a Codex multi-agent workflow across repositories

에이전트를 많이 돌리는 게 목적이 아님
안전하고 명확하고 쓸만한 분리일 때만 나눠 쓰는 게 목적

The goal is not to run more agents
The goal is to split work only when the split is safe, clear, and worth it

## 해결하려는 문제 / What This Repository Solves

- 저장소마다 `AGENTS.md` 를 처음부터 다시 쓰는 비용
- Rewriting `AGENTS.md` from scratch in every repository
- 오케스트레이터, 구현자, 탐색자, 리뷰어 역할 경계가 흐려지는 문제
- Vague role boundaries between orchestrator, implementer, explorer, and reviewer
- `write scope` 나 공유 계약이 겹쳐서 병렬 작업이 충돌하는 문제
- Parallel work that collides on `write scope` or shared contracts
- 리뷰어가 마지막 리스크 필터가 아니라 뒤늦은 수리 기사처럼 쓰이는 문제
- Reviewers being used as late repair crews instead of final risk filters

## 저장소 구성 / Repository Layout

- `AGENTS_TEMPLATE.md`
  저장소용 `AGENTS.md` 에 바로 복붙하는 표준 템플릿
- `AGENTS_TEMPLATE.md`
  Standard copy-paste template for a repository-level `AGENTS.md`
- `MULTI_AGENT_GUIDE.md`
  언제 나누고 언제 단독으로 가는지 설명하는 운영 가이드
- `MULTI_AGENT_GUIDE.md`
  The operating guide for when to split work and when to stay single-agent
- `profiles/main.md`
  오케스트레이션 역할 계약
- `profiles/main.md`
  Contract for the orchestration role
- `profiles/explorer.md`
  read-only 정찰 역할 계약
- `profiles/explorer.md`
  Contract for the read-only scouting role
- `profiles/worker.md`
  구현 역할 계약
- `profiles/worker.md`
  Contract for the implementation role
- `profiles/reviewer.md`
  마지막 read-only 검수 역할 계약
- `profiles/reviewer.md`
  Contract for the final read-only review role
- `examples/AGENTS.example.md`
  큰 웹 서비스나 일반 서비스 저장소용 예시
- `examples/AGENTS.example.md`
  Example for a larger web or service repository
- `examples/AGENTS.minimal.example.md`
  작은 저장소나 개인 프로젝트용 예시
- `examples/AGENTS.minimal.example.md`
  Example for a small or personal repository
- `installer/CodexMultiAgent.ps1`
  전역 설치와 작업공간 적용을 처리하는 스크립트
- `installer/CodexMultiAgent.ps1`
  Script for global install and workspace apply
- `installer/POWERSHELL_INSTALL.md`
  관리자 PowerShell 복붙용 설치 스니펫
- `installer/POWERSHELL_INSTALL.md`
  Copy-paste snippets for Administrator PowerShell

## 설치 모드 두 가지 / Two Installation Modes

- 전역 킷 설치
  이 저장소를 `%USERPROFILE%\.codex\multiagent-kit` 로 복사
- Global kit install
  Copies this kit to `%USERPROFILE%\.codex\multiagent-kit`
- 작업공간 적용
  원하는 작업공간을 골라 `AGENTS.md` 를 써 넣음
- Workspace apply
  Lets you choose a target workspace and writes `AGENTS.md` there

공용 기본값은 한 곳에 두고
실제 멀티에이전트 설정은 필요한 작업공간에만 적용하는 방식

This split keeps the shared defaults in one place while still letting you decide which workspaces actually get the multi-agent setup

## PowerShell 설치 흐름 / PowerShell Install Flow

1. Windows PowerShell 을 관리자 권한으로 실행
2. `installer/POWERSHELL_INSTALL.md` 열기
3. 원하는 블록 하나를 그대로 붙여 넣기
4. 인터랙티브 스니펫을 썼다면 아래 모드 중 하나 선택
5. 템플릿 선택
6. `docs/codex-multiagent/` 로 보조 문서를 복사할지 결정
7. 작업공간 폴더 선택

1. Open Windows PowerShell as Administrator
2. Open `installer/POWERSHELL_INSTALL.md`
3. Paste one of the provided blocks
4. Choose one of these modes if you used the interactive snippet
5. Pick a template
6. Decide whether to also copy supporting docs into `docs/codex-multiagent/`
7. Select the workspace folder

### 모드 선택 / Mode Options

- 전역 킷 설치 또는 업데이트
- Install or update the global kit
- 선택한 작업공간에만 적용
- Apply the kit to a selected workspace
- 전역 설치 후 바로 작업공간에도 적용
- Install globally and then apply to a workspace

### 템플릿 선택 / Template Options

- `standard`
- `standard`
- `minimal`
- `minimal`

## 핵심 규칙 / Core Rules

- 기본은 `main` 단독 진행
- Default to a single `main` agent
- 분리가 단독 진행보다 명확하게 안전할 때만 멀티에이전트 사용
- Use multiple agents only when the split is clearly safer than staying single-agent
- 분해 기준은 `write scope`, 공유 계약 경계, 검증 범위
- Split by `write scope`, shared contract boundaries, and verification scope
- `explorer` 와 `reviewer` 는 read-only 유지
- Keep `explorer` and `reviewer` read-only
- 쓰기 변경 슬라이스는 reviewer 패스로 닫기
- Close every write slice with a reviewer pass
- 진행 확인만 하려고 실행 중인 worker 를 다시 찌르지 않기
- Do not send follow-up status pings to a running worker just to check progress
- 끊긴 worker 를 같은 프롬프트로 재스폰하지 않기
- Do not respawn the same interrupted worker with the same prompt

## 잘 맞는 경우 / When This Kit Is a Good Fit

- 여러 저장소에서 같은 운영 모델을 반복 사용
- Multiple repositories use the same operating model
- 역할 경계와 병렬화 기준을 공용 규칙으로 관리하고 싶음
- The team wants a shared standard for role boundaries and parallelization
- 계약을 먼저 고정하지 않으면 API, UI, 데이터 작업이 자주 충돌함
- API, UI, and data work often collide unless contracts are pinned early
- 새 작업공간에 `AGENTS.md` 를 빠르게 넣고 싶음
- You want a quick way to bootstrap `AGENTS.md` in new workspaces

## 굳이 필요 없는 경우 / When You Probably Do Not Need It

- 혼자 쓰는 작은 실험 저장소
- Small experimental repositories used by one person
- 단일 파일 수정이 대부분인 워크플로
- Workflows dominated by single-file edits
- 질문 답변, 조사, 메모 비중이 큰 작업
- Tasks that are mostly Q and A, investigation, or note-taking
- 공유 계약이 아직 계속 흔들리는 초기 프로토타입
- Early prototypes where shared contracts are still changing every hour

## 커스터마이징 체크리스트 / Customization Checklist

- 실제로 필요한 worker 역할만 남겼는가
- Keep only the worker roles your repository actually needs
- 공유 계약 목록을 명시했는가
- Make the shared contracts explicit
- 검증 명령을 저장소 실정에 맞게 바꿨는가
- Replace the verification commands with repository-specific ones
- 생성물 폴더나 위험 경로를 적어뒀는가
- List any generated folders or risky paths that should not be edited
- reviewer 가 반드시 볼 항목을 정했는가
- Define what the reviewer must always check
- 병렬 상한이 팀 운영 방식과 맞는가
- Tune the concurrency limit to how your team actually works

## 비고 / Notes

- 전역 킷이 있으면 설치 스크립트는 그걸 우선 사용
- The installer prefers the global kit when it is available
- 전역 킷이 없으면 로컬 저장소 복사본을 사용
- If the global kit is not installed, the installer falls back to the local repository copy
- 바이너리 안에 묻는 대신 스크립트 중심으로 둬서 흐름을 직접 수정 가능하게 유지
- The installer is intentionally script-first so the workflow stays editable instead of being buried in a binary blob
- 나중에 인터랙티브 메뉴를 다시 열고 싶으면 `installer/POWERSHELL_INSTALL.md` 의 명령을 다시 붙여 넣으면 됨
- If you want to re-open the interactive menu later, paste the command shown in `installer/POWERSHELL_INSTALL.md`
