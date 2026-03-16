# Antigravity PowerShell Install

Windows PowerShell 을 관리자 권한으로 열고
아래 필요한 항목만 그대로 복붙하면 끝

이 설치기는 새 모델이나 별도 봇을 깔지 않음
Antigravity 런타임이 읽을 수 있는 전역 규칙 파일과 역할 정의 파일을 넣는 구조임

## 1. 전역 설치

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/AntigravityBootstrap.ps1' | Invoke-Expression; Install-AntigravityMultiAgent -Mode InstallGlobal
```

이 명령은

- `%USERPROFILE%\.gemini\antigravity\AGENTS.md` 생성 또는 덮어쓰기
- `%USERPROFILE%\.gemini\antigravity\global_workflows\multiagent-defaults.md` 설치
- `%USERPROFILE%\.gemini\antigravity\skills\multiagent-roles.md` 설치
- 참고용 킷을 `%USERPROFILE%\.gemini\antigravity\multiagent-kit` 에 복사

레거시 워크플로우와 스킬을 같이 격리하려면 끝에 `-CleanLegacy` 추가

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/AntigravityBootstrap.ps1' | Invoke-Expression; Install-AntigravityMultiAgent -Mode InstallGlobal -CleanLegacy
```

## 2. 특정 작업공간 오버라이드 설치

```powershell
$workspace = 'C:\path\to\your\workspace'; Invoke-RestMethod 'https://raw.githubusercontent.com/r2gul4r/codex_multiagent/main/installer/AntigravityBootstrap.ps1' | Invoke-Expression; Install-AntigravityMultiAgent -Mode ApplyWorkspace -TargetWorkspace $workspace -IncludeDocs
```

이 명령은

- 지정한 작업공간 루트에 `AGENTS.md` 생성 또는 덮어쓰기
- `STATE.md` 가 없으면 같이 생성
- 전역 기본 규칙 위에 저장소 전용 규칙 오버라이드 추가
- `docs/antigravity-multiagent/` 참고 문서 복사

## 참고

- 현재 Antigravity 런타임 경로는 `%USERPROFILE%\.gemini\antigravity` 기준
- 더 짧은 템플릿을 원하면 끝에 `-Template minimal` 추가
