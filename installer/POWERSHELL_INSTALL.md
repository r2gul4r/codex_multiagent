# Codex PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode InstallGlobal
```

이 명령은

- `%USERPROFILE%\.codex\AGENTS.md` 생성 또는 덮어쓰기
- 그래서 기존 작업공간이든 새 작업공간이든 공통 기본 규칙 자동 적용
- 참고용 킷은 `%USERPROFILE%\.codex\multiagent-kit` 에 같이 복사

## 2. 특정 작업공간 오버라이드 설치

이건 전역 규칙 위에
그 프로젝트만의 규칙을 추가로 얹고 싶을 때만 사용

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/Bootstrap.ps1' | Invoke-Expression; Install-CodexMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령은

- 지정한 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- 전역 기본 규칙 위에 저장소 전용 규칙을 오버라이드로 추가
- `docs/codex-multiagent/` 참고 문서 복사

## 참고

- 전역 설치만 해도 공통 기본값은 모든 Codex 작업공간에 적용
- 작업공간 설치는 예외 규칙이나 저장소 전용 계약이 필요할 때만
- 더 짧은 템플릿을 원하면 끝에 `-Template minimal` 추가
- Antigravity용 명령은 `installer/ANTIGRAVITY_INSTALL.md` 참고
