# Changelog

## v0.1.10 - 2026-03-20

### Changed

- 전역/저장소 AGENTS 템플릿에 `하드 트리거 + 점수제 + Route A/B/C` 작업 크기 게이트 추가
- `main` 직접 수정은 `Route A/B`, 큰 작업은 `Route C planner-only` 로 정리
- 작업공간 오버라이드 템플릿과 `STATE_TEMPLATE.md` 에 `route` 와 `write_sets` 개념 추가
- 운영 가이드와 예시를 route 기반 멀티에이전트 모델로 갱신

## v0.1.3 - 2026-03-19

### Added

- Codex macOS/Linux용 shell 설치기 `installer/CodexMultiAgent.sh` 추가
- `curl | bash` 원클릭 설치용 `installer/Bootstrap.sh` 추가
- GitHub Actions `macos-latest` 기반 설치 검증 워크플로우 추가

### Changed

- macOS 설치 경로를 README 중심으로 정리하고 GitHub Actions `macos-latest` 기준 전역 설치, workspace 오버라이드, bootstrap 경로 실검증 완료
## v0.1.2 - 2026-03-19

### Added

- Codex macOS/Linux용 shell 설치기 `installer/CodexMultiAgent.sh` 추가
- `curl | bash` 원클릭 설치용 `installer/Bootstrap.sh` 추가
- GitHub Actions `macos-latest` 기반 설치 검증 워크플로우 추가

### Changed

- macOS 설치 경로를 README 중심으로 정리하고 GitHub Actions `macos-latest` 기준 전역 설치, workspace 오버라이드, bootstrap 경로 실검증 완료

## v0.1.1 - 2026-03-18

### Added

- Codex 전역 설치 시 `%USERPROFILE%\.codex\rules\default.rules` 기본 command rules도 함께 배포
- `git reset --hard`, `git checkout --`, `git restore`, `git clean`, `rm -rf`, `del /s /q`, `Remove-Item -Recurse -Force` 같은 파괴적 명령 기본 차단 규칙 추가

### Changed

- 에이전트가 스스로 디스크 삭제나 강제 되돌리기 명령을 치는 기본 흐름을 rules 레이어에서 차단

## v0.1.0 - 2026-03-18

### Added

- Codex 전역 설치 시 `%USERPROFILE%\.codex\agents\*.toml` 서브에이전트 오버라이드도 함께 배포
- Codex built-in 서브에이전트 `default`, `worker`, `explorer`, `reviewer` 용 `gpt-5.4-mini` 모델 패치 템플릿 추가
- 전역 Codex 워크스페이스 기본 페르소나로 `gogi` 적용
- 이 워크스페이스 기본 페르소나로 `gogi` 적용

### Changed

- Codex 메인 세션 모델은 기존 사용자 `config.toml` 설정을 그대로 유지
- 서브에이전트만 더 가벼운 `gpt-5.4-mini` 모델을 사용하도록 분리
- 저장소/전역 AGENTS 문서의 기본 응답 언어를 한국어 중심으로 정리
- 저장소/전역 AGENTS 문서의 기본 톤을 간결한 banmal 기반 시니어 엔지니어 톤으로 정리
