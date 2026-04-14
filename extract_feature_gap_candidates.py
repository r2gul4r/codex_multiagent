#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 3
MAX_FILE_BYTES = 512 * 1024
TEXT_SAMPLE_BYTES = 4096
SKIP_DIRS = {".git", ".codex", "__pycache__"}
SCAN_SUFFIXES = {".py", ".sh", ".ps1", ".toml", ".rules"}
SKIP_FILENAMES = {"STATE.md", "MULTI_AGENT_LOG.md", "ERROR_LOG.md"}
SKIP_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".pdf",
    ".zip",
    ".tar",
    ".gz",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
}
TEST_FILE_PATTERN = re.compile(r"(?i)(^test_|_test\.|tests?/)")
TOKEN_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]{2,}")
PYTHON_DEF_PATTERN = re.compile(r"^\s*(def|class)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b")
SHELL_DEF_PATTERN = re.compile(
    r"^\s*(?:function\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\))?\s*\{"
)
POWERSHELL_DEF_PATTERN = re.compile(r"^\s*function\s+(?P<name>[A-Za-z_][A-Za-z0-9_-]*)\b", re.IGNORECASE)
STOPWORDS = {
    "todo",
    "fixme",
    "stub",
    "stubbed",
    "placeholder",
    "implemented",
    "implementation",
    "missing",
    "handler",
    "callback",
    "screen",
    "button",
    "dialog",
    "view",
    "page",
    "start",
    "resume",
    "submit",
    "click",
    "api",
    "client",
    "endpoint",
    "fetch",
    "request",
    "integration",
    "with",
    "from",
    "this",
    "that",
    "none",
    "soon",
}


@dataclass(frozen=True)
class SignalSpec:
    signal_id: str
    gap_type: str
    label: str
    rationale: str
    pattern: re.Pattern[str]


@dataclass(frozen=True)
class SymbolLocation:
    name: str
    line: int
    symbol_kind: str


@dataclass(frozen=True)
class FileRecord:
    path: Path
    relative_path: str
    lines: list[str]
    content: str
    language: str
    is_test_file: bool
    definitions: list[SymbolLocation]


SIGNAL_SPECS = (
    SignalSpec(
        signal_id="missing_handler",
        gap_type="feature_gap",
        label="미구현 핸들러",
        rationale="핸들러/콜백 맥락에서 미구현 신호가 보여 실제 동작 배선이 빠졌을 가능성이 큼",
        pattern=re.compile(
            r"(?i)(handler|callback|submit|click|resume|start|run).*(todo|stub|placeholder|not implemented|미구현)"
        ),
    ),
    SignalSpec(
        signal_id="missing_api_integration",
        gap_type="feature_gap",
        label="누락된 API 연동",
        rationale="API/연동 맥락에서 미구현 신호가 보여 외부 호출 또는 내부 연동이 비어 있을 가능성이 큼",
        pattern=re.compile(
            r"(?i)(api|client|endpoint|fetch|request|integration|연동).*(todo|stub|placeholder|not implemented|미구현|missing)"
        ),
    ),
    SignalSpec(
        signal_id="unwired_ui",
        gap_type="feature_gap",
        label="미연결 UI/화면",
        rationale="UI/화면 맥락에서 미구현 신호가 보여 사용자 흐름이 끝까지 연결되지 않았을 가능성이 큼",
        pattern=re.compile(
            r"(?i)(ui|screen|page|button|dialog|view).*(todo|stub|placeholder|coming soon|not implemented|미구현|미연결)"
        ),
    ),
    SignalSpec(
        signal_id="not_implemented",
        gap_type="feature_gap",
        label="미구현 로직",
        rationale="명시적인 not-implemented 신호가 있어 실제 기능 로직이 빠져 있음",
        pattern=re.compile(r"(?i)(notimplemented(error)?|not implemented|unimplemented|미구현)"),
    ),
    SignalSpec(
        signal_id="stub",
        gap_type="feature_gap",
        label="stub/임시 구현",
        rationale="stub 표시가 있어 실제 기능 구현이 임시 상태에 머물러 있음",
        pattern=re.compile(r"(?i)\bstub(?:bed)?\b"),
    ),
    SignalSpec(
        signal_id="todo",
        gap_type="feature_gap",
        label="TODO/FIXME",
        rationale="TODO/FIXME 주석이 있어 후속 구현 또는 연결 작업이 남아 있음",
        pattern=re.compile(r"(?i)\b(todo|fixme)\b"),
    ),
    SignalSpec(
        signal_id="placeholder",
        gap_type="feature_gap",
        label="placeholder 출력/템플릿",
        rationale="placeholder 문자열이 실제 값 대신 남아 있어 사용 시점에 필요한 기능 채움이 빠져 있음",
        pattern=re.compile(r"(?i)\bplaceholder\b"),
    ),
)


AREA_LABELS = {
    "installer": "설치기와 작업공간 스캐폴딩",
    "root_tooling": "루트 도구/자동화",
    "documentation": "문서와 평가 기준",
    "agent_profiles": "에이전트 프로필/설정",
    "rules_and_skills": "규칙과 스킬 자산",
    "examples_and_snapshots": "예시와 스냅샷",
    "other": "기타 영역",
}

COMMON_AXIS_POINTS = {
    "goal_alignment": {"pass": 3, "borderline": 1, "fail": 0},
    "gap_relevance": {"high": 3, "medium": 2, "low": 0},
    "safety": {"safe": 3, "guarded": 2, "risky": 0},
    "reversibility": {"strong": 3, "partial": 2, "weak": 0},
    "structural_impact": {"low": 3, "medium": 2, "high": 0},
    "leverage": {"high": 3, "medium": 2, "low": 1},
}

GOAL_ALIGNMENT_AREA_SCORES = {
    "installer": 3,
    "root_tooling": 3,
    "documentation": 2,
    "agent_profiles": 3,
    "rules_and_skills": 3,
    "examples_and_snapshots": 1,
    "other": 2,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract evidence-backed unfinished feature candidates from repository files."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root to scan. Defaults to the current directory.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="json",
        help="Output format. Defaults to json.",
    )
    return parser.parse_args()


def classify_area(path: Path) -> str:
    parts = path.parts
    if not parts:
        return "other"
    head = parts[0]
    if head == "installer":
        return "installer"
    if head == "docs":
        return "documentation"
    if head in {"codex_agents", "profiles"}:
        return "agent_profiles"
    if head in {"codex_rules", "codex_skills"}:
        return "rules_and_skills"
    if head == "examples":
        return "examples_and_snapshots"
    if len(parts) == 1:
        return "root_tooling"
    return "other"


def infer_language(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".py":
        return "python"
    if suffix == ".sh":
        return "shell"
    if suffix == ".ps1":
        return "powershell"
    if suffix == ".toml":
        return "toml"
    if suffix == ".rules":
        return "rules"
    return "text"


def iter_repo_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix.lower() in SKIP_SUFFIXES:
            continue
        if path.name in SKIP_FILENAMES:
            continue
        if path.suffix.lower() not in SCAN_SUFFIXES:
            continue
        if path.name == Path(__file__).name:
            continue
        try:
            if path.stat().st_size > MAX_FILE_BYTES:
                continue
        except OSError:
            continue
        if is_text_file(path):
            files.append(path)
    return sorted(files)


def is_text_file(path: Path) -> bool:
    try:
        sample = path.read_bytes()[:TEXT_SAMPLE_BYTES]
    except OSError:
        return False
    if b"\x00" in sample:
        return False
    return True


def read_text_lines(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8", errors="replace")
    return text.splitlines()


def normalize_excerpt(text: str) -> str:
    return " ".join(text.strip().split())


def is_test_file(path: Path) -> bool:
    return bool(TEST_FILE_PATTERN.search(path.as_posix()))


def extract_definitions(language: str, lines: list[str]) -> list[SymbolLocation]:
    definitions: list[SymbolLocation] = []
    if language == "python":
        pattern = PYTHON_DEF_PATTERN
        symbol_map = {"def": "function", "class": "class"}
        for index, line in enumerate(lines, start=1):
            match = pattern.match(line)
            if not match:
                continue
            definitions.append(
                SymbolLocation(
                    name=match.group("name"),
                    line=index,
                    symbol_kind=symbol_map.get(match.group(1), "symbol"),
                )
            )
        return definitions

    if language == "shell":
        for index, line in enumerate(lines, start=1):
            match = SHELL_DEF_PATTERN.match(line)
            if not match:
                continue
            definitions.append(
                SymbolLocation(name=match.group("name"), line=index, symbol_kind="function")
            )
        return definitions

    if language == "powershell":
        for index, line in enumerate(lines, start=1):
            match = POWERSHELL_DEF_PATTERN.match(line)
            if not match:
                continue
            definitions.append(
                SymbolLocation(name=match.group("name"), line=index, symbol_kind="function")
            )
        return definitions

    return definitions


def build_file_record(root: Path, path: Path) -> FileRecord:
    lines = read_text_lines(path)
    language = infer_language(path)
    content = "\n".join(lines)
    relative_path = path.relative_to(root).as_posix()
    return FileRecord(
        path=path,
        relative_path=relative_path,
        lines=lines,
        content=content,
        language=language,
        is_test_file=is_test_file(path.relative_to(root)),
        definitions=extract_definitions(language, lines),
    )


def build_repo_index(root: Path, files: list[Path]) -> dict[str, Any]:
    records = [build_file_record(root, path) for path in files]
    by_relative_path = {record.relative_path: record for record in records}
    return {
        "records": records,
        "by_relative_path": by_relative_path,
        "test_records": [record for record in records if record.is_test_file],
    }


def find_enclosing_symbol(record: FileRecord, line_number: int) -> SymbolLocation | None:
    candidates = [definition for definition in record.definitions if definition.line <= line_number]
    if not candidates:
        return None
    return candidates[-1]


def extract_tokens(*values: str) -> list[str]:
    seen: set[str] = set()
    tokens: list[str] = []
    for value in values:
        for raw in TOKEN_PATTERN.findall(value):
            token = raw.lower()
            if token in STOPWORDS:
                continue
            if token in seen:
                continue
            seen.add(token)
            tokens.append(token)
    return tokens


def infer_feature_key(candidate: dict[str, Any]) -> str:
    symbol_name = candidate.get("code_location", {}).get("symbol_name")
    if isinstance(symbol_name, str) and symbol_name:
        return symbol_name

    evidence = candidate.get("evidence", {})
    path = str(evidence.get("path", ""))
    excerpt = str(evidence.get("excerpt", ""))
    stem = Path(path).stem
    tokens = extract_tokens(stem, excerpt)
    if tokens:
        return tokens[0]
    return f"{stem or 'feature'}-{evidence.get('line', 'unknown')}"


def build_candidate(
    *,
    root: Path,
    record: FileRecord,
    area_id: str,
    spec: SignalSpec,
    line_number: int,
    line_text: str,
) -> dict[str, Any]:
    start = max(0, line_number - 2)
    end = min(len(record.lines), line_number + 1)
    context = [normalize_excerpt(record.lines[index]) for index in range(start, end)]
    symbol = find_enclosing_symbol(record, line_number)
    code_location = {
        "path": record.relative_path,
        "line": symbol.line if symbol else line_number,
        "symbol_name": symbol.name if symbol else None,
        "symbol_kind": symbol.symbol_kind if symbol else None,
        "anchor": f"{record.relative_path}:{symbol.line if symbol else line_number}",
    }
    title_target = symbol.name if symbol else f"{record.relative_path}:{line_number}"
    return {
        "candidate_id": f"{area_id}:{record.relative_path}:{line_number}:{spec.signal_id}",
        "candidate_kind": spec.gap_type,
        "title": f"{spec.label}: {title_target}",
        "signal_id": spec.signal_id,
        "signal_label": spec.label,
        "feature_key": infer_feature_key(
            {
                "code_location": code_location,
                "evidence": {"path": record.relative_path, "line": line_number, "excerpt": line_text},
            }
        ),
        "functional_area": area_id,
        "functional_area_label": AREA_LABELS.get(area_id, area_id),
        "rationale": spec.rationale,
        "code_location": code_location,
        "evidence": {
            "path": record.relative_path,
            "line": line_number,
            "excerpt": normalize_excerpt(line_text),
            "context": context,
        },
    }


def scan_file(root: Path, record: FileRecord) -> list[dict[str, Any]]:
    area_id = classify_area(Path(record.relative_path))
    candidates: list[dict[str, Any]] = []
    seen: set[tuple[int, str]] = set()

    for index, line in enumerate(record.lines, start=1):
        for spec in SIGNAL_SPECS:
            if not spec.pattern.search(line):
                continue
            dedupe_key = (index, spec.signal_id)
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            candidates.append(
                build_candidate(
                    root=root,
                    record=record,
                    area_id=area_id,
                    spec=spec,
                    line_number=index,
                    line_text=line,
                )
            )
            break
    return candidates


def summarize_signals(candidates: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for candidate in candidates:
        signal_id = str(candidate.get("signal_id"))
        counts[signal_id] = counts.get(signal_id, 0) + 1
    return dict(sorted(counts.items()))


def unique_sorted(items: list[str]) -> list[str]:
    return sorted({item for item in items if item})


def summarize_related_paths(paths: list[str], limit: int = 8) -> list[str]:
    return unique_sorted(paths)[:limit]


def map_status_label(decision: str) -> str:
    return {
        "confirmed_gap": "확정 공백",
        "likely_gap": "유력 공백",
        "needs_review": "검토 필요",
    }.get(decision, decision)


def impact_score_to_level(score: int) -> tuple[str, str]:
    if score >= 4:
        return ("high", "높음")
    if score >= 2:
        return ("medium", "중간")
    return ("low", "낮음")


def build_status_summary(call_flow: dict[str, Any], test_evidence: dict[str, Any], assessment: dict[str, Any]) -> str:
    parts = [str(assessment.get("summary", "")).strip()]
    call_flow_summary = str(call_flow.get("summary", "")).strip()
    test_summary = str(test_evidence.get("summary", "")).strip()
    if call_flow_summary:
        parts.append(call_flow_summary)
    if test_summary:
        parts.append(test_summary)
    return " / ".join(part for part in parts if part)


def build_impact_summary(area_label: str, assessment: dict[str, Any], candidate_count: int) -> dict[str, str]:
    level_id, level_label = impact_score_to_level(int(assessment.get("score", 0)))
    confidence = str(assessment.get("confidence", "")).strip()
    reasons = [str(reason).strip() for reason in assessment.get("reasons", []) if str(reason).strip()]
    if reasons:
        reason_text = ", ".join(reasons[:2])
    else:
        reason_text = "현재 신호가 약해 영향도는 제한적으로 본다"
    summary = (
        f"{area_label}에서 {candidate_count}개 근거가 같은 공백 후보로 묶여 있고 "
        f"판정 신뢰도는 {confidence or 'unknown'}라서, 이 항목을 메우면 "
        f"해당 영역의 누락 상태 기록과 후속 개선 우선순위 정확도가 {level_label} 수준으로 좋아질 가능성이 있다. "
        f"주요 근거: {reason_text}"
    )
    return {
        "level": level_id,
        "level_label": level_label,
        "summary": summary,
    }


def build_documentation_evidence(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    evidence_rows: list[dict[str, Any]] = []
    for candidate in candidates[:3]:
        evidence = candidate["evidence"]
        evidence_rows.append(
            {
                "path": evidence["path"],
                "line": evidence["line"],
                "excerpt": evidence["excerpt"],
                "signal_label": candidate["signal_label"],
            }
        )
    return evidence_rows


def build_documentation_entry(
    *,
    area_id: str,
    area_label: str,
    feature_key: str,
    candidates: list[dict[str, Any]],
    call_flow: dict[str, Any],
    test_evidence: dict[str, Any],
    assessment: dict[str, Any],
) -> dict[str, Any]:
    status_label = map_status_label(str(assessment.get("decision", "")))
    evidence_rows = build_documentation_evidence(candidates)
    primary_evidence = evidence_rows[0] if evidence_rows else {}
    impact = build_impact_summary(area_label, assessment, len(candidates))
    return {
        "gap_id": f"{area_id}:{feature_key}",
        "functional_area": area_id,
        "functional_area_label": area_label,
        "title": f"{area_label} / {feature_key}",
        "evidence": {
            "summary": str(candidates[0].get("rationale", "")).strip() if candidates else "",
            "items": evidence_rows,
            "primary_reference": {
                "path": primary_evidence.get("path"),
                "line": primary_evidence.get("line"),
            },
        },
        "current_status": {
            "status": assessment.get("decision"),
            "status_label": status_label,
            "summary": build_status_summary(call_flow, test_evidence, assessment),
        },
        "expected_impact": impact,
    }


def render_markdown_report(payload: dict[str, Any]) -> str:
    lines = [
        "# Feature Gap Areas",
        "",
        "이 문서는 저장소에서 판별된 기능 공백과 그 근거를 바탕으로 뽑은 작은 기능 후보 목록이다.",
        "각 항목은 근거, 현재 상태, 사용자 가치, 구현 범위, 선정 근거를 함께 남겨 다음 계획 단계의 직접 입력으로 쓴다.",
        "",
        f"- schema_version: `{payload['schema_version']}`",
        f"- scanned_file_count: `{payload['scanned_file_count']}`",
        f"- documented_feature_gap_count: `{payload['documented_feature_gap_count']}`",
        f"- small_feature_candidate_count: `{payload['small_feature_candidate_count']}`",
        "",
    ]

    candidates = payload.get("small_feature_candidates", [])
    if candidates:
        lines.extend(
            [
                "## Small Feature Candidates",
                "",
            ]
        )
        for candidate in candidates:
            lines.extend(
                [
                    f"### {candidate['title']}",
                    "",
                    f"- 결정: `{candidate['decision']}` / 등급 `{candidate['priority_grade']}` / 점수 `{candidate['priority_score']}`",
                    f"- 사용자 가치: {candidate['user_value']}",
                ]
            )
            if candidate.get("implementation_scope"):
                lines.append("- 구현 범위:")
                for item in candidate["implementation_scope"]:
                    lines.append(f"  - {item}")
            if candidate.get("selection_rationale"):
                lines.append("- 선정 근거:")
                for item in candidate["selection_rationale"]:
                    lines.append(f"  - {item}")
            lines.append("")

    for area in payload["areas"]:
        entries = area.get("documented_feature_gaps", [])
        if not entries:
            continue
        lines.extend(
            [
                f"## {area['area_label']}",
                "",
                f"- area_id: `{area['area_id']}`",
                f"- scanned_file_count: `{area['scanned_file_count']}`",
                f"- documented_feature_gap_count: `{len(entries)}`",
                "",
            ]
        )
        for entry in entries:
            evidence_items = entry["evidence"]["items"]
            evidence_summary = entry["evidence"]["summary"]
            primary = evidence_items[0] if evidence_items else None
            primary_ref = (
                f"`{primary['path']}:{primary['line']}`"
                if primary and primary.get("path") and primary.get("line")
                else "`n/a`"
            )
            lines.extend(
                [
                    f"### {entry['title']}",
                    "",
                    f"- 근거: {evidence_summary}",
                    f"- 근거 위치: {primary_ref}",
                    f"- 현재 상태: {entry['current_status']['status_label']} / {entry['current_status']['summary']}",
                    (
                        f"- 예상 영향도: {entry['expected_impact']['level_label']} / "
                        f"{entry['expected_impact']['summary']}"
                    ),
                ]
            )
            if evidence_items:
                lines.append("- 세부 근거:")
                for item in evidence_items:
                    lines.append(
                        f"  - `{item['path']}:{item['line']}` {item['signal_label']} :: {item['excerpt']}"
                    )
            lines.append("")

    return "\n".join(lines).strip() + "\n"


def find_related_records(
    repo_index: dict[str, Any], feature_key: str, area_id: str, candidate_paths: list[str]
) -> list[FileRecord]:
    tokens = extract_tokens(feature_key, *[Path(path).stem for path in candidate_paths])
    path_set = set(candidate_paths)
    related: list[FileRecord] = []
    for record in repo_index["records"]:
        same_area = classify_area(Path(record.relative_path)) == area_id
        if record.relative_path in path_set:
            related.append(record)
            continue
        if not same_area:
            continue
        haystack = f"{record.relative_path}\n{record.content}".lower()
        if any(token in haystack for token in tokens):
            related.append(record)
    return related


def build_call_flow(
    repo_index: dict[str, Any], symbol_name: str | None, related_records: list[FileRecord]
) -> dict[str, Any]:
    if not symbol_name:
        return {
            "entrypoint": None,
            "definition": None,
            "callers": [],
            "status": "unknown",
            "summary": "심볼을 특정하지 못해 호출 흐름을 추론하지 못함",
        }

    symbol_pattern = re.compile(rf"\b{re.escape(symbol_name)}\b")
    definition: dict[str, Any] | None = None
    callers: list[dict[str, Any]] = []

    for record in repo_index["records"]:
        for definition_candidate in record.definitions:
            if definition_candidate.name != symbol_name:
                continue
            definition = {
                "path": record.relative_path,
                "line": definition_candidate.line,
                "symbol_kind": definition_candidate.symbol_kind,
            }
            break
        if definition:
            break

    for record in related_records:
        for index, line in enumerate(record.lines, start=1):
            if not symbol_pattern.search(line):
                continue
            if definition and record.relative_path == definition["path"] and index == definition["line"]:
                continue
            callers.append(
                {
                    "path": record.relative_path,
                    "line": index,
                    "excerpt": normalize_excerpt(line),
                }
            )
            if len(callers) >= 6:
                break
        if len(callers) >= 6:
            break

    status = "linked" if definition and callers else "defined_only" if definition else "unresolved"
    if status == "linked":
        summary = "정의와 참조가 둘 다 보여 실제 호출 흐름을 따라갈 수 있음"
    elif status == "defined_only":
        summary = "정의는 보이지만 관련 호출 흔적이 약해 배선 누락 가능성이 남음"
    else:
        summary = "정의나 호출 흐름을 안정적으로 찾지 못해 추가 확인이 필요함"

    return {
        "entrypoint": callers[0] if callers else None,
        "definition": definition,
        "callers": callers,
        "status": status,
        "summary": summary,
    }


def build_test_evidence(
    repo_index: dict[str, Any], feature_key: str, symbol_name: str | None, candidate_paths: list[str]
) -> dict[str, Any]:
    search_terms = unique_sorted(extract_tokens(feature_key, symbol_name or "", *[Path(path).stem for path in candidate_paths]))
    matching_tests: list[dict[str, Any]] = []

    for record in repo_index["test_records"]:
        haystack = f"{record.relative_path}\n{record.content}".lower()
        if not search_terms:
            continue
        if not any(term in haystack for term in search_terms):
            continue
        matching_tests.append(
            {
                "path": record.relative_path,
                "matched_terms": [term for term in search_terms if term in haystack][:5],
            }
        )

    missing_tests = len(matching_tests) == 0
    summary = (
        "연결된 테스트 파일을 찾지 못해 기능 공백 회귀 방어가 약함"
        if missing_tests
        else "관련 테스트 흔적이 있어 기능 공백 여부를 추가 검증할 수 있음"
    )
    return {
        "search_terms": search_terms,
        "matched_test_files": matching_tests,
        "missing_tests": missing_tests,
        "summary": summary,
    }


def assess_gap(
    candidates: list[dict[str, Any]], call_flow: dict[str, Any], test_evidence: dict[str, Any]
) -> dict[str, Any]:
    signal_counts = summarize_signals(candidates)
    explicit_signals = sum(
        signal_counts.get(signal_id, 0)
        for signal_id in ("missing_handler", "missing_api_integration", "unwired_ui", "not_implemented")
    )
    weak_signals = sum(signal_counts.get(signal_id, 0) for signal_id in ("todo", "placeholder", "stub"))

    reasons: list[str] = []
    score = 0

    if explicit_signals > 0:
        score += 2
        reasons.append("명시적인 미구현/누락 신호가 확인됨")
    if weak_signals > 1:
        score += 1
        reasons.append("같은 기능 후보에 반복 신호가 누적됨")
    if call_flow.get("status") in {"defined_only", "unresolved"}:
        score += 1
        reasons.append("호출 흐름이 끝까지 연결되지 않음")
    if test_evidence.get("missing_tests"):
        score += 1
        reasons.append("관련 테스트 흔적이 없음")

    if score >= 4:
        decision = "confirmed_gap"
        confidence = "high"
        summary = "증거가 겹쳐 보여 실제 기능 공백으로 우선 취급해도 되는 후보"
    elif score >= 2:
        decision = "likely_gap"
        confidence = "medium"
        summary = "기능 공백 가능성이 높지만 호출 흐름/테스트 확인이 더 있으면 좋음"
    else:
        decision = "needs_review"
        confidence = "low"
        summary = "신호는 있으나 실제 공백으로 단정하기엔 근거가 약함"

    return {
        "decision": decision,
        "confidence": confidence,
        "summary": summary,
        "reasons": reasons,
        "score": score,
    }


def score_to_common_goal_alignment(score: int) -> str:
    if score >= 2:
        return "pass"
    if score == 1:
        return "borderline"
    return "fail"


def summarize_user_value(feature_group: dict[str, Any]) -> tuple[int, str]:
    assessment = feature_group["gap_assessment"]
    tests = feature_group["evidence_bundle"]["tests"]
    signal_counts = feature_group["signal_counts"]
    explicit_signals = sum(
        signal_counts.get(signal_id, 0)
        for signal_id in ("missing_handler", "missing_api_integration", "unwired_ui", "not_implemented")
    )
    if assessment["decision"] == "confirmed_gap" or (explicit_signals > 0 and tests["missing_tests"]):
        return 3, "현재 확인된 기능 공백을 직접 메워 실제 사용 흐름과 회귀 방어를 바로 개선함"
    if assessment["decision"] == "likely_gap":
        return 2, "반복 마찰을 줄이는 보강 후보지만 핵심 공백을 닫는 증거는 한 단계 더 필요함"
    return 1, "보조적 개선 가치는 있으나 현재 목표 달성에는 간접 효과가 더 큼"


def summarize_implementation_cost(feature_group: dict[str, Any]) -> tuple[int, str]:
    related_paths = feature_group["related_paths"]
    code_locations = feature_group["evidence_bundle"]["code_locations"]
    if len(related_paths) <= 1 and len(code_locations) <= 2:
        return 3, "기존 구조 안에서 한두 지점만 수정하면 되는 작은 변경 범위"
    if len(related_paths) <= 3:
        return 2, "현재 구조를 유지한 채 인접 파일 몇 곳을 함께 손보면 되는 범위"
    if len(related_paths) <= 5:
        return 1, "영향 경로가 넓어 작은 기능치고 검증 부담이 큰 편"
    return 0, "구조 변경 승인 없이는 안전하게 넣기 어려운 범위"


def summarize_small_feature_goal_alignment(area_id: str, feature_group: dict[str, Any]) -> tuple[int, str]:
    base_score = GOAL_ALIGNMENT_AREA_SCORES.get(area_id, 1)
    assessment = feature_group["gap_assessment"]
    if assessment["decision"] == "confirmed_gap" and base_score < 3:
        base_score += 1
    score = min(base_score, 3)
    if score == 3:
        return 3, "저장소의 자가 탐지·제안·검증 루프를 직접 강화하는 영역이라 목표 정합성이 높음"
    if score == 2:
        return 2, "프로젝트 목표 흐름을 보조하지만 핵심 루프 강화 효과는 한 단계 약함"
    if score == 1:
        return 1, "프로젝트 목표와 충돌은 없지만 직접 기여도는 낮음"
    return 0, "현재 프로젝트 방향성과 직접 연결되지 않음"


def summarize_ripple_effect(feature_group: dict[str, Any]) -> tuple[int, str]:
    call_flow = feature_group["evidence_bundle"]["call_flow"]
    tests = feature_group["evidence_bundle"]["tests"]
    related_paths = feature_group["related_paths"]
    if tests["missing_tests"] and call_flow["status"] in {"defined_only", "unresolved"}:
        return 3, "기능 보강과 동시에 다음 사이클의 검증 신뢰도와 추적성이 함께 좋아짐"
    if tests["missing_tests"] or call_flow["status"] in {"defined_only", "unresolved"}:
        return 2, "인접한 검증 또는 호출 흐름에 긍정 효과가 있지만 범위는 제한적임"
    if len(related_paths) <= 2:
        return 1, "현재 공백 해결 중심이라 연쇄 이득은 크지 않음"
    return 0, "연쇄 이득보다 회귀 통제 비용이 더 커질 수 있음"


def assess_common_axes(area_id: str, feature_group: dict[str, Any], implementation_cost: int) -> dict[str, str]:
    tests = feature_group["evidence_bundle"]["tests"]
    call_flow = feature_group["evidence_bundle"]["call_flow"]
    gap_assessment = feature_group["gap_assessment"]
    goal_alignment_score, _ = summarize_small_feature_goal_alignment(area_id, feature_group)

    if gap_assessment["decision"] in {"confirmed_gap", "likely_gap"}:
        gap_relevance = "high"
    elif gap_assessment["score"] > 0:
        gap_relevance = "medium"
    else:
        gap_relevance = "low"

    if implementation_cost == 0:
        structural_impact = "high"
    elif len(feature_group["related_paths"]) > 3:
        structural_impact = "medium"
    else:
        structural_impact = "low"

    if implementation_cost == 0:
        safety = "risky"
    elif tests["missing_tests"] or call_flow["status"] in {"defined_only", "unresolved"}:
        safety = "guarded"
    else:
        safety = "safe"

    if implementation_cost >= 2:
        reversibility = "strong"
    elif implementation_cost == 1:
        reversibility = "partial"
    else:
        reversibility = "weak"

    ripple_effect, _ = summarize_ripple_effect(feature_group)
    if ripple_effect >= 3 or area_id in {"root_tooling", "rules_and_skills", "agent_profiles"}:
        leverage = "high"
    elif ripple_effect >= 2:
        leverage = "medium"
    else:
        leverage = "low"

    return {
        "goal_alignment": score_to_common_goal_alignment(goal_alignment_score),
        "gap_relevance": gap_relevance,
        "safety": safety,
        "reversibility": reversibility,
        "structural_impact": structural_impact,
        "leverage": leverage,
    }


def compute_common_score(common_axes: dict[str, str]) -> int:
    return sum(COMMON_AXIS_POINTS[axis_name][axis_value] for axis_name, axis_value in common_axes.items())


def grade_priority(priority_score: int) -> str:
    if priority_score >= 40:
        return "A"
    if priority_score >= 32:
        return "B"
    if priority_score >= 24:
        return "C"
    return "D"


def determine_small_feature_decision(
    common_axes: dict[str, str],
    value: int,
    implementation_cost: int,
    goal_alignment_score: int,
    ripple_effect: int,
    priority_score: int,
) -> tuple[str, str]:
    if common_axes["goal_alignment"] == "fail":
        return "reject", "hold"
    if common_axes["gap_relevance"] == "low":
        return "defer", "hold"
    if common_axes["safety"] == "risky":
        return "defer", "hold"
    if common_axes["reversibility"] == "weak":
        return "defer", "hold"
    if common_axes["structural_impact"] == "high":
        return "needs_approval", "hold"
    if goal_alignment_score < 2:
        return "reject", "hold"
    if value < 2:
        return "defer", "hold"
    if implementation_cost == 0:
        return "needs_approval", "hold"
    if ripple_effect == 0:
        return "defer", "hold"
    return "pick", grade_priority(priority_score)


def build_implementation_scope(feature_group: dict[str, Any], implementation_cost_summary: str) -> list[str]:
    scope = [implementation_cost_summary]
    code_locations = feature_group["evidence_bundle"]["code_locations"]
    call_flow = feature_group["evidence_bundle"]["call_flow"]
    tests = feature_group["evidence_bundle"]["tests"]
    if code_locations:
        anchors = unique_sorted(
            [
                f"{item['path']}:{item['line']}"
                for item in code_locations
                if item.get("path") and item.get("line")
            ]
        )
        scope.append(f"우선 수정 후보 코드 위치: {', '.join(anchors[:4])}")
    if call_flow["definition"]:
        definition = call_flow["definition"]
        scope.append(f"주요 정의 지점: {definition['path']}:{definition['line']}")
    if tests["matched_test_files"]:
        scope.append(
            "연관 테스트 확인 범위: "
            + ", ".join(item["path"] for item in tests["matched_test_files"][:4])
        )
    elif tests["missing_tests"]:
        scope.append("관련 테스트가 없어 기능 보강과 함께 회귀 방어 경로 확인이 필요함")
    return scope


def build_selection_rationale(
    feature_group: dict[str, Any],
    common_axes: dict[str, str],
    user_value_summary: str,
    goal_alignment_summary: str,
    ripple_effect_summary: str,
) -> list[str]:
    rationale = [user_value_summary, goal_alignment_summary, ripple_effect_summary]
    rationale.extend(feature_group["gap_assessment"]["reasons"])
    rationale.append(
        "공통 축 판정: " + ", ".join(f"{key}={value}" for key, value in common_axes.items())
    )
    return rationale


def build_small_feature_candidate(area_id: str, feature_group: dict[str, Any]) -> dict[str, Any]:
    value, user_value_summary = summarize_user_value(feature_group)
    implementation_cost, implementation_cost_summary = summarize_implementation_cost(feature_group)
    goal_alignment_score, goal_alignment_summary = summarize_small_feature_goal_alignment(
        area_id, feature_group
    )
    ripple_effect, ripple_effect_summary = summarize_ripple_effect(feature_group)
    specific_score = value + implementation_cost + goal_alignment_score + ripple_effect
    common_axes = assess_common_axes(area_id, feature_group, implementation_cost)
    common_score = compute_common_score(common_axes)
    priority_score = (common_score * 2) + specific_score
    decision, priority_grade = determine_small_feature_decision(
        common_axes,
        value,
        implementation_cost,
        goal_alignment_score,
        ripple_effect,
        priority_score,
    )

    return {
        "proposal_id": f"small_feature:{area_id}:{feature_group['feature_key']}",
        "candidate_kind": "small_feature",
        "title": feature_group["title"],
        "linked_gap": "feature_gap",
        "linked_feature_key": feature_group["feature_key"],
        "functional_area": area_id,
        "functional_area_label": AREA_LABELS.get(area_id, area_id),
        "user_value": user_value_summary,
        "implementation_scope": build_implementation_scope(feature_group, implementation_cost_summary),
        "selection_rationale": build_selection_rationale(
            feature_group,
            common_axes,
            user_value_summary,
            goal_alignment_summary,
            ripple_effect_summary,
        ),
        "common_axes": common_axes,
        "small_feature_rubric": {
            "value": value,
            "implementation_cost": implementation_cost,
            "goal_alignment": goal_alignment_score,
            "ripple_effect": ripple_effect,
            "specific_score": specific_score,
        },
        "common_score": common_score,
        "specific_score": specific_score,
        "priority_score": priority_score,
        "priority_grade": priority_grade,
        "decision": decision,
        "source_feature_group": {
            "feature_key": feature_group["feature_key"],
            "candidate_count": feature_group["candidate_count"],
            "signal_counts": feature_group["signal_counts"],
            "related_paths": feature_group["related_paths"],
            "gap_assessment": feature_group["gap_assessment"],
        },
    }


def build_small_feature_candidates(areas: list[dict[str, Any]]) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for area in areas:
        area_id = area["area_id"]
        for feature_group in area["feature_groups"]:
            candidate = build_small_feature_candidate(area_id, feature_group)
            if candidate["common_axes"]["goal_alignment"] != "pass":
                continue
            candidates.append(candidate)

    return sorted(
        candidates,
        key=lambda item: (
            {"pick": 0, "defer": 1, "needs_approval": 2, "reject": 3}.get(item["decision"], 4),
            -item["priority_score"],
            -item["small_feature_rubric"]["goal_alignment"],
            -item["small_feature_rubric"]["value"],
            item["title"],
        ),
    )


def build_feature_group(
    *,
    area_id: str,
    feature_key: str,
    candidates: list[dict[str, Any]],
    repo_index: dict[str, Any],
) -> dict[str, Any]:
    sorted_candidates = sorted(
        candidates,
        key=lambda item: (
            item["evidence"]["path"],
            item["evidence"]["line"],
            item["signal_id"],
        ),
    )
    candidate_paths = [candidate["evidence"]["path"] for candidate in sorted_candidates]
    symbol_name = next(
        (
            str(candidate["code_location"]["symbol_name"])
            for candidate in sorted_candidates
            if candidate.get("code_location", {}).get("symbol_name")
        ),
        None,
    )
    related_records = find_related_records(repo_index, feature_key, area_id, candidate_paths)
    call_flow = build_call_flow(repo_index, symbol_name, related_records)
    test_evidence = build_test_evidence(repo_index, feature_key, symbol_name, candidate_paths)
    assessment = assess_gap(sorted_candidates, call_flow, test_evidence)

    related_paths = summarize_related_paths([record.relative_path for record in related_records])
    code_locations = []
    for candidate in sorted_candidates:
        location = candidate["code_location"]
        code_locations.append(
            {
                "path": location["path"],
                "line": location["line"],
                "symbol_name": location["symbol_name"],
                "symbol_kind": location["symbol_kind"],
            }
        )

    title_source = symbol_name or feature_key
    return {
        "feature_key": feature_key,
        "title": f"{AREA_LABELS.get(area_id, area_id)} / {title_source}",
        "candidate_count": len(sorted_candidates),
        "signal_counts": summarize_signals(sorted_candidates),
        "related_paths": related_paths,
        "evidence_bundle": {
            "related_file_paths": related_paths,
            "code_locations": code_locations,
            "call_flow": call_flow,
            "tests": test_evidence,
        },
        "gap_assessment": assessment,
        "documentation_entry": build_documentation_entry(
            area_id=area_id,
            area_label=AREA_LABELS.get(area_id, area_id),
            feature_key=feature_key,
            candidates=sorted_candidates,
            call_flow=call_flow,
            test_evidence=test_evidence,
            assessment=assessment,
        ),
        "candidates": sorted_candidates,
    }


def build_area_records(files: list[Path], root: Path, repo_index: dict[str, Any]) -> list[dict[str, Any]]:
    by_area: dict[str, dict[str, Any]] = {
        area_id: {
            "area_id": area_id,
            "area_label": label,
            "scanned_files": [],
            "candidates": [],
        }
        for area_id, label in AREA_LABELS.items()
    }

    for record in repo_index["records"]:
        area_id = classify_area(Path(record.relative_path))
        area = by_area.setdefault(
            area_id,
            {
                "area_id": area_id,
                "area_label": AREA_LABELS.get(area_id, area_id),
                "scanned_files": [],
                "candidates": [],
            },
        )
        area["scanned_files"].append(record.relative_path)
        area["candidates"].extend(scan_file(root, record))

    areas: list[dict[str, Any]] = []
    for area_id in sorted(by_area):
        record = by_area[area_id]
        candidates = sorted(
            record["candidates"],
            key=lambda item: (
                item["evidence"]["path"],
                item["evidence"]["line"],
                item["signal_id"],
            ),
        )

        grouped: dict[str, list[dict[str, Any]]] = {}
        for candidate in candidates:
            grouped.setdefault(str(candidate["feature_key"]), []).append(candidate)

        feature_groups = [
            build_feature_group(
                area_id=area_id,
                feature_key=feature_key,
                candidates=grouped_candidates,
                repo_index=repo_index,
            )
            for feature_key, grouped_candidates in sorted(grouped.items())
        ]

        areas.append(
            {
                "area_id": area_id,
                "area_label": record["area_label"],
                "scanned_file_count": len(record["scanned_files"]),
                "candidate_count": len(candidates),
                "feature_group_count": len(feature_groups),
                "documented_feature_gaps": [group["documentation_entry"] for group in feature_groups],
                "small_feature_candidates": [
                    candidate
                    for candidate in (
                        build_small_feature_candidate(area_id, group) for group in feature_groups
                    )
                    if candidate["common_axes"]["goal_alignment"] == "pass"
                ],
                "signal_counts": summarize_signals(candidates),
                "scanned_files": sorted(record["scanned_files"]),
                "feature_groups": feature_groups,
                "candidates": candidates,
            }
        )
    return areas


def extract_feature_gap_candidates(root: Path) -> dict[str, Any]:
    files = iter_repo_files(root)
    repo_index = build_repo_index(root, files)
    areas = build_area_records(files, root, repo_index)
    all_candidates = [candidate for area in areas for candidate in area["candidates"]]
    all_feature_groups = [group for area in areas for group in area["feature_groups"]]
    all_documented_gaps = [entry for area in areas for entry in area["documented_feature_gaps"]]
    small_feature_candidates = build_small_feature_candidates(areas)
    return {
        "schema_version": SCHEMA_VERSION,
        "repository_root": str(root.resolve()),
        "scanned_file_count": len(files),
        "candidate_count": len(all_candidates),
        "feature_group_count": len(all_feature_groups),
        "documented_feature_gap_count": len(all_documented_gaps),
        "small_feature_candidate_count": len(small_feature_candidates),
        "small_feature_candidates": small_feature_candidates,
        "areas": areas,
    }


def main() -> None:
    args = parse_args()
    root = Path(args.root).resolve()
    payload = extract_feature_gap_candidates(root)
    if args.format == "markdown":
        print(render_markdown_report(payload), end="")
        return

    indent = 2 if args.pretty else None
    print(json.dumps(payload, ensure_ascii=False, indent=indent))


if __name__ == "__main__":
    main()
