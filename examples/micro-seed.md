# Route Contract Example

이 예시는 Route A / Route B 기준으로 작업 범위를 작게 고정하는 방법을 보여준다.
별도 workflow command surface나 철학-only 포장은 쓰지 않는다.

## 목적

- 구현 전에 의도와 제약을 고정한다
- `STATE.md`에 route, writer slot, write set을 남긴다
- 이후 검증이 같은 계약을 기준으로 판단되게 한다

## 규칙

- 짧게 쓴다.
- 검증 가능한 문장만 넣는다.
- 구현과 리뷰가 실제로 필요로 하는 정보만 적는다.
- 범위가 바뀌면 기존 메모를 슬쩍 바꾸지 말고 새 항목으로 다시 적는다.

## 예시

```yaml
current_task: "Refine the Route A / Route B documentation layer"
route: "Route B"
writer_slot: "parallel"
write_sets:
  - "worker_docs: README.md, CHANGELOG.md, THIRD_PARTY_NOTICES.md, docs/**, examples/**"
contract_freeze:
  - "Keep Route A and Route B as the only governance model exposed in repository docs."
  - "Do not reintroduce partial Ouroboros port claims or fake command surfaces."
acceptance_criteria:
  - "README describes the repository as a Route A / Route B governance kit."
  - "Docs and examples no longer present the old packaging layer as active guidance."
verification:
  - "Review the changed docs for residual port-language."
  - "Run the repository's normal documentation review checks if available."
out_of_scope:
  - "Full Ouroboros integration design."
  - "New command surface for workflow automation."
```
