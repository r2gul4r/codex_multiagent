# WORKSPACE_CONTEXT Guide

`WORKSPACE_CONTEXT.toml` 은 작업공간 오버라이드 설치 전에 프로젝트 방향성을 정리해 두는 파일이다.
installer 는 이 파일을 읽고 프로젝트에 맞는 `AGENTS.md` 와 초기 `STATE.md` 를 생성한다.

## 필수 항목 기준표

| 항목 | 필수 여부 | 의미 | 예시 |
| --- | --- | --- | --- |
| `workspace.name` | 필수 | 작업공간 식별 이름 | `billing-api`, `data-pipeline`, `jejugroup` |
| `workspace.summary` 또는 `brand.summary` | 필수 | 프로젝트 목적 한 줄 설명 | `결제 API 서버`, `배치 리포트 생성 파이프라인` |
| `architecture.source_of_truth` | 필수 | 실제 수정 기준이 되는 코드/폴더 | `src`, `app`, `services/api`, `infra/terraform` |
| `editing_rules.edit_in` | 필수 | 보통 수정이 허용되는 경로 | `src/**`, `scripts/**`, `jobs/**` |
| `editing_rules.do_not_edit` | 필수 | 직접 수정하면 안 되는 경로 | `dist/**`, `generated/**`, `vendor/**` |
| `verification.commands` 또는 `verification.recommended_commands` | 필수 | 최소 검증 명령 | `pnpm test`, `pytest`, `go test ./...`, `terraform validate` |
| `workflow.authoring_model` | 권장 | 수정/배포 흐름 설명 | `src만 수정, dist는 산출물` |
| `triggers.hard` | 권장 | 큰 작업으로 봐야 하는 변경 | `API contract 변경`, `schema 변경`, `shared config 변경` |
| `approval.zones` | 권장 | 승인 필요 작업 | `deploy`, `db migration`, `external writes`, `prod secret 변경` |
| `workers.mapping` | 권장 | 작업 분리 힌트 | `worker_api = src/api/**`, `worker_data = jobs/**` |
| `reviewer.focus` | 권장 | 리뷰 우선 포인트 | `contract drift`, `regression`, `verification gaps` |

최소로 꼭 채우면 좋은 항목은 아래 여섯 개다.

- `workspace.name`
- `workspace.summary` 또는 `brand.summary`
- `architecture.source_of_truth`
- `editing_rules.edit_in`
- `editing_rules.do_not_edit`
- `verification.commands` 또는 `verification.recommended_commands`

## 기존 프로젝트용 프롬프트

기존 프로젝트를 읽고 초안을 만들게 할 때는 아래 프롬프트를 그대로 써도 된다.

```text
이 프로젝트 폴더를 읽고 WORKSPACE_CONTEXT.toml 초안을 만들어줘.

반드시 아래 항목은 채워줘.
- workspace.name
- summary
- architecture.source_of_truth
- editing_rules.edit_in
- editing_rules.do_not_edit
- verification.commands or verification.recommended_commands

가능하면 아래도 채워줘.
- workflow.authoring_model
- triggers.hard
- approval.zones
- workers.mapping
- reviewer.focus
```

## 새 프로젝트용 프롬프트

새 프로젝트라면 프로젝트 방향을 먼저 자연어로 설명한 뒤 아래처럼 요청하면 된다.

```text
내가 추구하는 프로젝트 방향을 바탕으로 WORKSPACE_CONTEXT.toml 초안 만들어줘.

반드시 아래 항목은 채워줘.
- workspace.name
- summary
- architecture.source_of_truth
- editing_rules.edit_in
- editing_rules.do_not_edit
- verification.commands or verification.recommended_commands

가능하면 아래도 채워줘.
- workflow.authoring_model
- triggers.hard
- approval.zones
- workers.mapping
- reviewer.focus
```
