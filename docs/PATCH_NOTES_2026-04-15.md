# 2026-04-15 패치노트

한국어가 기본이다. 아래 `English`를 열면 영어 버전을 볼 수 있다.

<details>
<summary><strong>English</strong></summary>

# 2026-04-15 Patch Notes

## Summary

- Aligned canonical execution policy text and installer-generated rule text to English/ASCII-first wording.
- Preserved the default `gogi` persona contract: Korean by default unless the user asks otherwise, concise Korean banmal, and dry, confident senior-engineer tone.
- Clarified that generated artifacts follow repository and audience conventions before persona defaults.
- Added a Korean-first README language toggle with an English section.

## Included Changes

- Updated `AGENTS.md` persona bullets to explicitly name the default persona, response language, speech style, and tone.
- Updated shell and PowerShell installer output for generated workspace `AGENTS.md` files.
- Updated config developer instructions emitted by the installers.
- Updated `WORKSPACE_CONTEXT_TEMPLATE.toml`, `docs/WORKSPACE_CONTEXT_GUIDE.md`, and AGENTS examples with the same persona contract.
- Synced matching mirror docs under `docs/codex-multiagent/`.
- Reworked the README introduction and current patch summary so Korean remains the main reading path and English is available from the collapsible section.

## Operator Impact

- Operators still get Korean responses and Korean work reports by default.
- Installer-generated policy text is less vulnerable to encoding drift because the canonical execution surface is English/ASCII-first.
- Workspace persona overrides remain field-level only; missing fields inherit the global `gogi` defaults.
- No score model, `agent_budget`, orchestration semantics, runtime schema, telemetry, background loop, or cross-workspace self-editing behavior changed.

## Verification

- `git diff --check`
- `bash -n installer/CodexMultiAgent.sh`
- PowerShell parser check for `installer/CodexMultiAgent.ps1`
- mirror consistency check
- targeted grep for persona and language contract text
- PowerShell apply-workspace generated `AGENTS.md` smoke check
- shell generation-path smoke check after the installer WSL guard blocked full bash apply-workspace in the Windows environment

</details>

---

## 요약

- canonical 실행 정책 문구와 installer가 생성하는 규칙 문구를 English/ASCII-first로 정리했다.
- 기본 `gogi` persona 계약은 유지했다: 사용자가 달리 요청하지 않으면 한국어, concise Korean banmal, dry confident senior-engineer tone.
- 생성물은 persona보다 저장소와 독자 관례를 먼저 따른다는 점을 더 명시했다.
- README에 한국어 메인 흐름과 접히는 English 섹션을 추가했다.

## 포함 변경

- `AGENTS.md` persona 항목을 default persona name, default response language, default speech style, default tone으로 명확히 쪼갰다.
- shell/PowerShell installer가 생성하는 workspace `AGENTS.md` 문구를 같은 계약으로 맞췄다.
- installer가 `config.toml`에 넣는 developer instructions의 persona 문구를 보강했다.
- `WORKSPACE_CONTEXT_TEMPLATE.toml`, `docs/WORKSPACE_CONTEXT_GUIDE.md`, AGENTS examples에 같은 persona 계약을 반영했다.
- `docs/codex-multiagent/` 아래 mirror 문서를 동기화했다.
- README 상단과 최신 패치 요약을 한국어 메인 + English 토글 구조로 정리했다.

## 운영 영향

- 대화와 작업 보고는 계속 한국어가 기본이다.
- installer 생성 정책 문구는 English/ASCII-first라 encoding drift에 덜 취약하다.
- workspace persona override는 계속 field-level inherit 방식이다.
- score model, `agent_budget`, orchestration semantics, runtime schema, telemetry, background loop, cross-workspace self-editing 동작은 바꾸지 않았다.

## 검증

- `git diff --check`
- `bash -n installer/CodexMultiAgent.sh`
- PowerShell parser check for `installer/CodexMultiAgent.ps1`
- mirror consistency check
- persona/language contract targeted grep
- PowerShell apply-workspace generated `AGENTS.md` smoke check
- Windows 환경에서 full bash apply-workspace는 installer WSL guard로 차단되어, guard 이전 shell generation path를 smoke check로 대체
