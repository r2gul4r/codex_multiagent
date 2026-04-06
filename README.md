# Codex Multi-Agent Kit

이 저장소는 Route A / Route B 기반 멀티에이전트 거버넌스 키트다.
예전의 철학-only 포장, fake `ooo` command surface, repo-packaged spec-first skill 레이어는 빼고, 작업 분리와 검증 규칙만 또렷하게 남긴다.

## 핵심 원칙

- `Route A`는 `main` 전용, 서브에이전트 없이 바로 고치는 경로다.
- `Route B`는 delegated 경로고, `main planner-only` + worker + reviewer 분리를 전제로 한다.
- `STATE.md`는 `current_task`, `route`, `writer_slot`, `contract_freeze`, `write_sets`를 추적한다.
- `MULTI_AGENT_LOG.md`와 `ERROR_LOG.md`는 append-only로 유지한다.
- 보안 규칙, 검증 규칙, 파일 ownership 규칙은 우선순위가 높다.

## 빠른 시작

일반적으로는 설치기부터 실행한다. 글로벌 설치와 워크스페이스 적용은 각각 해당 설치 스크립트를 따라가면 된다.

- 글로벌 적용: `installer/Bootstrap.ps1` 또는 `installer/Bootstrap.sh`
- 워크스페이스 적용: `WORKSPACE_CONTEXT.toml` 기반 workspace install

이 저장소가 보장하는 건 설치 표면이 아니라, 설치 후에도 유지되는 운영 규칙이다.

## 운영 모델

- `Route A`는 작은 변경에 적합하다.
- `Route B`는 scope가 커지거나 shared contract가 걸릴 때 쓴다.
- `worker_shared`는 공유 자산만 맡는다.
- feature worker는 서로 겹치지 않는 write set만 갖는다.
- reviewer는 구현을 대신하지 않고, 최종 위험과 회귀를 확인한다.

## 꼭 볼 파일

- [AGENTS.md](./AGENTS.md)
- [STATE.md](./STATE.md)
- [MULTI_AGENT_GUIDE.md](./MULTI_AGENT_GUIDE.md)
- [docs/WORKSPACE_CONTEXT_GUIDE.md](./docs/WORKSPACE_CONTEXT_GUIDE.md)
- [examples/micro-seed.md](./examples/micro-seed.md)

## 작업 기준

- route와 writer slot은 `STATE.md`에서 먼저 고정한다.
- shared contract가 흔들리면 `main`이 먼저 멈춘다.
- 검증은 코드 리뷰와 repo verification command를 기준으로 본다.
- 외부 비밀, 사용자 입력, 렌더링, API 경로는 별도 보안 기준을 따른다.

## 상태 정리

이 저장소가 내세우는 건 Route A / Route B 거버넌스뿐이다.
나머지 협업 규칙은 그걸 지탱하는 보조 장치로 보면 된다.
