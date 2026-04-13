# Patch Notes

## 2026-04-13

### Summary

- 기본값은 그대로 single `STATE.md`
- same-workspace 동시 작업이 정말 필요할 때만 concurrent registry mode 허용
- 작업 후 회고와 규칙 진화 로그를 남기는 운영 루프 추가

### Included Changes

- PowerShell installer 의 UTF-8 읽기/쓰기를 명시화해서 한글 `WORKSPACE_CONTEXT.toml` 기반 생성물이 깨지지 않도록 수정
- 설치 지원 문서 `WORKSPACE_CONTEXT_GUIDE.md` 의 깨진 한글을 정상 한국어 가이드로 교체
- `AGENTS.md` 에 concurrent registry mode, overlap 충돌 시 중단 규칙, retrospective/metrics 기록 규칙 추가
- `MULTI_AGENT_GUIDE.md` 에 concurrent registry 운영 기준, adoption 순서, rule-evolution 정리 추가
- `docs/CONCURRENT_STATE_MODE.md`, `docs/OPERATIONS_RETROSPECTIVE.md` 신규 추가
- root registry, thread state, task retrospective, rule evolution log 예시 추가
- shell/PowerShell installer 생성 결과에도 같은 규칙이 반영되도록 동기화

### Operator Impact

- 단일 작업은 예전처럼 바로 `STATE.md` 하나로 시작하면 됨
- 동시 작업은 root registry 와 thread별 상태 파일로 분리할 수 있음
- 충돌이나 재분류가 있었던 작업은 회고 한 줄이라도 남겨서 다음 규칙 수정 근거로 삼으면 됨

### Verification

- `bash -n installer/CodexMultiAgent.sh`
- PowerShell parser check for `installer/CodexMultiAgent.ps1`
- `git diff --check`
- shell/PowerShell installer 를 임시 워크스페이스에 적용해 생성물에 새 규칙 문구가 포함되는지 확인
- UTF-8 no BOM 한글 `WORKSPACE_CONTEXT.toml` 을 PowerShell installer 에 통과시켜 생성된 `AGENTS.md` 에 한글이 보존되는지 확인
