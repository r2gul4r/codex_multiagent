# Antigravity PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 둘 중 하나만 그대로 복붙하면 끝

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/AntigravityBootstrap.ps1' | Invoke-Expression; Install-AntigravityMultiAgent -Mode InstallGlobal
```

이 명령은

- `%USERPROFILE%\.antigravity\AGENTS.md` 생성 또는 덮어쓰기
- Antigravity 공통 기본 규칙 전역 설치
- 참고용 킷은 `%USERPROFILE%\.antigravity\multiagent-kit` 에 같이 복사

## 2. 특정 작업공간 오버라이드 설치

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/AntigravityBootstrap.ps1' | Invoke-Expression; Install-AntigravityMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령은

- 지정한 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- 전역 기본 규칙 위에 저장소 전용 규칙 오버라이드 추가
- `docs/antigravity-multiagent/` 참고 문서 복사

## 참고

- 이 스크립트는 Antigravity 쪽도 Codex와 같은 `AGENTS.md` 레이어를 읽는다는 가정으로 작성
- 더 짧은 템플릿을 원하면 끝에 `-Template minimal` 추가
