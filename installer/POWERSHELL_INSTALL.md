# PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령은

- 최신 킷 다운로드
- `%USERPROFILE%\.codex\multiagent-kit` 에 전역 설치

까지 한 번에 처리

## 2. 특정 작업공간 설치

아래에서 작업공간 경로만 바꿔서 복붙

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령은

- 최신 킷 다운로드
- 지정한 작업공간에 `AGENTS.md` 설치
- `docs/codex-multiagent/` 참고 문서 복사

까지 한 번에 처리

## 참고

- 두 명령 모두 최신 `main` 브랜치 기준
- 작업공간 설치 명령은 기존 `AGENTS.md` 가 있으면 덮어씀
- 템플릿을 바꾸고 싶으면 끝에 `-Template minimal` 추가하면 됨
