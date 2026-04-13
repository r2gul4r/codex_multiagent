# Codex PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode UpdateGlobal
```

이 명령은

- `%USERPROFILE%\.codex\AGENTS.md`, `config.toml`, installer 관리 대상 `agents/*.toml` 을 백업 후 새 구조 기준으로 재생성
- `%USERPROFILE%\.codex\config.toml` 의 필요한 키를 patch 해서 `AGENTS.md` 발견 우선순위, `multi_agent` 기본값, 그리고 `AGENTS.md`를 우선 읽고 집행하는 execution requirements 를 맞춤
- `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 설정 설치 및 레거시 추가 agent 정리
- `%USERPROFILE%\.codex\rules\*.rules` 기본 command rules 설치
- 그래서 기존 작업공간이든 새 작업공간이든 공통 기본 규칙 자동 적용
- 참고용 킷은 `%USERPROFILE%\.codex\multiagent-kit` 에 같이 복사

## 2. 특정 작업공간 오버라이드 설치

이건 전역 규칙 위에
그 프로젝트만의 규칙을 추가로 얹는 단계

실제 프로젝트 작업은 `전역 설치 -> 작업공간 오버라이드 설치` 순서를 기본으로 본다.
설치 전에 대상 작업공간 루트에 `WORKSPACE_CONTEXT.toml` 을 먼저 작성해 두는 것을 권장한다.

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode UpdateWorkspace -TargetWorkspace $workspace
```

이 명령은

- 지정한 작업공간 루트의 `AGENTS.md`, `STATE.md` 를 백업 후 새 구조 기준으로 재생성
- 전역 기본 규칙 위에 저장소 전용 규칙을 오버라이드로 추가
- `docs/codex-multiagent/` 참고 문서 복사
- 작업공간 루트에 `WORKSPACE_CONTEXT.toml` 이 있으면 그 파일을 먼저 읽어 프로젝트에 맞는 `AGENTS.md` 와 초기 `STATE.md` 생성
- `WORKSPACE_CONTEXT.toml` 이 없으면 installer 내장 fallback 규칙으로 생성
- 실제 프로젝트에 맞춘 설치를 원하면 오버라이드 설치 전에 `WORKSPACE_CONTEXT.toml` 을 먼저 준비해 두는 편이 좋음

## 참고

- 전역 설치만 해도 공통 기본값은 모든 Codex 작업공간에 적용
- 실제 프로젝트 작업은 작업공간 오버라이드까지 적용하는 것을 기본으로 권장
- 더 짧은 템플릿을 원하면 끝에 `-Template minimal` 추가
- macOS용 설치 명령은 `README.md` 의 macOS 설치 섹션 참고
- 전역 설치 백업은 `%USERPROFILE%\.codex\backups\<timestamp>\global`, 작업공간 오버라이드 백업은 `<workspace>\.codex-backups\<timestamp>\workspace` 아래에 남음
