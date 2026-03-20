# Codex PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령은

- `%USERPROFILE%\.codex\AGENTS.md` 생성 또는 덮어쓰기
- `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 설정 설치
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

이 명령은

- 지정한 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- `STATE.md` 가 없으면 같이 생성
- 전역 기본 규칙 위에 저장소 전용 규칙을 오버라이드로 추가
- `docs/codex-multiagent/` 참고 문서 복사
- 작업공간 루트에 `WORKSPACE_CONTEXT.toml` 이 있으면 그 파일을 먼저 읽어 프로젝트에 맞는 `AGENTS.md` 와 초기 `STATE.md` 생성
- `WORKSPACE_CONTEXT.toml` 이 없으면 기본 오버라이드 템플릿 fallback 사용
- 실제 프로젝트에 맞춘 설치를 원하면 오버라이드 설치 전에 `WORKSPACE_CONTEXT.toml` 을 먼저 준비해 두는 편이 좋음

## 참고

- 전역 설치만 해도 공통 기본값은 모든 Codex 작업공간에 적용
- 실제 프로젝트 작업은 작업공간 오버라이드까지 적용하는 것을 기본으로 권장
- 더 짧은 템플릿을 원하면 끝에 `-Template minimal` 추가
- macOS용 설치 명령은 `README.md` 의 macOS 설치 섹션 참고
