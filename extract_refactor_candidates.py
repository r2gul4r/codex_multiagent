#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
DEFAULT_LIMIT = 5

CODE_LANGUAGES = {"python", "shell", "powershell", "makefile", "rules", "toml"}

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

PYTHON_DEF_PATTERN = re.compile(r"^\s*(def|class)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b")
SHELL_DEF_PATTERN = re.compile(
    r"^\s*(?:function\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\))?\s*\{"
)
POWERSHELL_DEF_PATTERN = re.compile(r"^\s*function\s+(?P<name>[A-Za-z_][A-Za-z0-9_-]*)\b", re.IGNORECASE)


@dataclass(frozen=True)
class SymbolLocation:
    name: str
    line: int
    symbol_kind: str


@dataclass(frozen=True)
class FileRecord:
    path: str
    language: str
    lines: list[str]
    definitions: list[SymbolLocation]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract goal-aligned refactor candidates from repository analysis signals."
    )
    parser.add_argument("--root", default=".", help="Repository root to inspect.")
    parser.add_argument(
        "--metrics-input",
        help="Optional JSON file produced by collect_repo_metrics.py. Defaults to collecting fresh metrics.",
    )
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="json",
        help="Output format. Defaults to json.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=DEFAULT_LIMIT,
        help=f"Maximum number of ranked candidates to emit. Defaults to {DEFAULT_LIMIT}.",
    )
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output.")
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


def load_metrics(root: Path, metrics_input: str | None) -> dict[str, Any]:
    if metrics_input:
        with open(metrics_input, "r", encoding="utf-8") as handle:
            return json.load(handle)

    command = [sys.executable, str(root / "collect_repo_metrics.py"), "--root", str(root), "--pretty"]
    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(
            "collect_repo_metrics.py failed while building refactor candidates:\n"
            + completed.stderr.strip()
        )
    return json.loads(completed.stdout)


def read_text_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace").splitlines()


def extract_definitions(language: str, lines: list[str]) -> list[SymbolLocation]:
    definitions: list[SymbolLocation] = []
    if language == "python":
        for index, line in enumerate(lines, start=1):
            match = PYTHON_DEF_PATTERN.match(line)
            if not match:
                continue
            definitions.append(
                SymbolLocation(
                    name=match.group("name"),
                    line=index,
                    symbol_kind="class" if match.group(1) == "class" else "function",
                )
            )
        return definitions

    if language == "shell":
        for index, line in enumerate(lines, start=1):
            match = SHELL_DEF_PATTERN.match(line)
            if not match:
                continue
            definitions.append(SymbolLocation(name=match.group("name"), line=index, symbol_kind="function"))
        return definitions

    if language == "powershell":
        for index, line in enumerate(lines, start=1):
            match = POWERSHELL_DEF_PATTERN.match(line)
            if not match:
                continue
            definitions.append(SymbolLocation(name=match.group("name"), line=index, symbol_kind="function"))
        return definitions

    return definitions


def build_file_records(root: Path, metrics: dict[str, Any]) -> dict[str, FileRecord]:
    records: dict[str, FileRecord] = {}
    for item in metrics.get("files", []):
        path = item["path"]
        language = item["language"]
        if language not in CODE_LANGUAGES:
            continue
        lines = read_text_lines(root / path)
        records[path] = FileRecord(
            path=path,
            language=language,
            lines=lines,
            definitions=extract_definitions(language, lines),
        )
    return records


def find_enclosing_symbol(record: FileRecord, line_number: int) -> SymbolLocation | None:
    active: SymbolLocation | None = None
    for definition in record.definitions:
        if definition.line > line_number:
            break
        active = definition
    return active


def unique_preserve_order(items: list[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for item in items:
        if not item or item in seen:
            continue
        seen.add(item)
        ordered.append(item)
    return ordered


def compute_common_score(common_axes: dict[str, str]) -> int:
    return sum(COMMON_AXIS_POINTS[key][value] for key, value in common_axes.items())


def grade_priority(priority_score: int) -> str:
    if priority_score >= 40:
        return "A"
    if priority_score >= 32:
        return "B"
    if priority_score >= 24:
        return "C"
    return "D"


def determine_refactor_decision(
    common_axes: dict[str, str],
    quality_impact: int,
    risk: int,
    maintainability: int,
    feature_goal_contribution: int,
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
    if feature_goal_contribution < 2:
        return "defer", "hold"
    if quality_impact < 2:
        return "defer", "hold"
    if risk == 0:
        return "needs_approval", "hold"
    if maintainability == 0:
        return "defer", "hold"
    return "pick", grade_priority(priority_score)


def format_location(path: str, start_line: int, end_line: int) -> str:
    return f"{path}:{start_line}-{end_line}"


def build_duplicate_title(paths: list[str], symbols: list[str]) -> str:
    if symbols:
        symbol_label = " + ".join(symbols[:3])
        if len(symbols) > 3:
            symbol_label += " + ..."
        return f"{symbol_label} 중복 정리"
    if len(paths) == 1:
        return f"{paths[0]} 중복 블록 정리"
    first = paths[0]
    return f"{first} 외 {len(paths) - 1}개 경로 중복 정리"


def build_duplicate_common_axes(
    area_id: str,
    group: dict[str, Any],
    file_metrics: list[dict[str, Any]],
) -> dict[str, str]:
    normalized_line_count = int(group["normalized_line_count"])
    occurrence_count = int(group["occurrence_count"])
    max_commit_count = max(item["change_frequency"]["commit_count"] for item in file_metrics)
    distinct_paths = len({item["path"] for item in file_metrics})

    goal_alignment = "pass" if area_id in {"installer", "root_tooling", "agent_profiles", "rules_and_skills"} else "borderline"
    gap_relevance = "high" if normalized_line_count >= 15 or occurrence_count >= 3 else "medium"
    safety = "guarded" if max_commit_count >= 20 or distinct_paths >= 2 else "safe"
    reversibility = "strong" if distinct_paths <= 2 else "partial"
    leverage = "high" if area_id in {"installer", "root_tooling"} or max_commit_count >= 20 else "medium"
    return {
        "goal_alignment": goal_alignment,
        "gap_relevance": gap_relevance,
        "safety": safety,
        "reversibility": reversibility,
        "structural_impact": "low",
        "leverage": leverage,
    }


def build_duplicate_rubric(group: dict[str, Any], area_id: str, file_metrics: list[dict[str, Any]]) -> dict[str, int]:
    normalized_line_count = int(group["normalized_line_count"])
    occurrence_count = int(group["occurrence_count"])
    max_commit_count = max(item["change_frequency"]["commit_count"] for item in file_metrics)
    quality_impact = 3 if normalized_line_count >= 20 or occurrence_count >= 3 else 2
    risk = 2 if max_commit_count >= 20 or len(file_metrics) >= 2 else 3
    maintainability = 3 if len(file_metrics) >= 2 or normalized_line_count >= 12 else 2
    feature_goal_contribution = 3 if area_id in {"installer", "root_tooling"} else 2
    specific_score = quality_impact + risk + maintainability + feature_goal_contribution
    return {
        "quality_impact": quality_impact,
        "risk": risk,
        "maintainability": maintainability,
        "feature_goal_contribution": feature_goal_contribution,
        "specific_score": specific_score,
    }


def build_duplicate_candidate(
    group: dict[str, Any],
    files_by_path: dict[str, dict[str, Any]],
    file_records: dict[str, FileRecord],
) -> dict[str, Any] | None:
    modules = group["modules"]
    if not modules:
        return None

    paths = unique_preserve_order([module["path"] for module in modules])
    file_metrics = [files_by_path[path] for path in paths if path in files_by_path]
    if not file_metrics:
        return None

    primary_path = paths[0]
    area_id = classify_area(Path(primary_path))
    area_label = AREA_LABELS.get(area_id, area_id)

    symbols = []
    for module in modules:
        record = file_records.get(module["path"])
        if record is None:
            continue
        symbol = find_enclosing_symbol(record, int(module["start_line"]))
        if symbol is not None:
            symbols.append(symbol.name)
    symbols = unique_preserve_order(symbols)

    common_axes = build_duplicate_common_axes(area_id, group, file_metrics)
    rubric = build_duplicate_rubric(group, area_id, file_metrics)
    common_score = compute_common_score(common_axes)
    specific_score = rubric["specific_score"]
    priority_score = (common_score * 2) + specific_score
    decision, priority_grade = determine_refactor_decision(
        common_axes,
        rubric["quality_impact"],
        rubric["risk"],
        rubric["maintainability"],
        rubric["feature_goal_contribution"],
        priority_score,
    )

    excerpt = " / ".join(group.get("excerpt", [])[:2])
    evidence_locations = [
        format_location(module["path"], int(module["start_line"]), int(module["end_line"]))
        for module in modules
    ]
    problem_signals = [
        f"정규화 중복 블록 {group['normalized_line_count']}줄이 {group['occurrence_count']}회 반복됨",
        f"영향 파일 중 최대 변경 빈도는 commit_count={max(item['change_frequency']['commit_count'] for item in file_metrics)}",
    ]
    if symbols:
        problem_signals.append(f"중복이 같은 책임 경계({', '.join(symbols[:3])}) 주변에 몰려 있음")
    if excerpt:
        problem_signals.append(f"반복 블록 예시: {excerpt}")

    expected_improvement = [
        f"{area_label}에서 같은 수정 포인트를 여러 블록 대신 한 군데로 모아 drift 가능성을 줄임",
        "후속 규칙 추가나 상태 필드 수정 시 변경 누락 가능성을 낮춤",
    ]
    if len(paths) == 1:
        expected_improvement.append(f"`{paths[0]}` 내부 변경 범위를 줄여 회귀 확인 지점을 단순화함")

    selection_rationale = [
        f"공통 축 판정: {', '.join(f'{key}={value}' for key, value in common_axes.items())}",
        f"리팩터링 루브릭: quality_impact={rubric['quality_impact']}, risk={rubric['risk']}, maintainability={rubric['maintainability']}, feature_goal_contribution={rubric['feature_goal_contribution']}",
        "중복 신호와 변경 빈도 신호가 함께 보여 변경 안정성 개선 효과를 설명하기 쉬움",
    ]

    return {
        "proposal_id": f"refactor:duplicate:{group['fingerprint']}",
        "candidate_kind": "refactor",
        "title": build_duplicate_title(paths, symbols),
        "linked_gap": "quality_gap",
        "functional_area": area_id,
        "functional_area_label": area_label,
        "problem_signals": problem_signals,
        "expected_improvement": expected_improvement,
        "selection_rationale": selection_rationale,
        "evidence_locations": evidence_locations,
        "common_axes": common_axes,
        "refactor_rubric": rubric,
        "common_score": common_score,
        "specific_score": specific_score,
        "priority_score": priority_score,
        "priority_grade": priority_grade,
        "decision": decision,
        "source_signals": {
            "candidate_source": "duplicate_block",
            "paths": paths,
            "normalized_line_count": group["normalized_line_count"],
            "occurrence_count": group["occurrence_count"],
            "max_commit_count": max(item["change_frequency"]["commit_count"] for item in file_metrics),
        },
    }


def symbol_spans(record: FileRecord) -> list[tuple[SymbolLocation, int]]:
    spans: list[tuple[SymbolLocation, int]] = []
    total_lines = len(record.lines)
    for index, definition in enumerate(record.definitions):
        next_line = record.definitions[index + 1].line if index + 1 < len(record.definitions) else total_lines + 1
        spans.append((definition, max(next_line - definition.line, 1)))
    return sorted(spans, key=lambda item: (-item[1], item[0].line, item[0].name))


def build_hotspot_common_axes(area_id: str, metrics: dict[str, Any]) -> dict[str, str]:
    cyclomatic = metrics["complexity"]["cyclomatic_estimate"]
    code_lines = metrics["module_size"]["code_lines"]
    duplication_groups = metrics["duplication"]["group_count"]
    commit_count = metrics["change_frequency"]["commit_count"]

    goal_alignment = "pass" if area_id in {"installer", "root_tooling", "agent_profiles", "rules_and_skills"} else "borderline"
    gap_relevance = "high" if cyclomatic >= 150 or (code_lines >= 700 and duplication_groups >= 5) else "medium"
    safety = "guarded" if code_lines >= 900 or commit_count >= 15 else "safe"
    reversibility = "partial" if code_lines >= 1300 else "strong"
    structural_impact = "medium" if code_lines >= 1000 else "low"
    leverage = "high" if area_id in {"installer", "root_tooling"} else "medium"
    return {
        "goal_alignment": goal_alignment,
        "gap_relevance": gap_relevance,
        "safety": safety,
        "reversibility": reversibility,
        "structural_impact": structural_impact,
        "leverage": leverage,
    }


def build_hotspot_rubric(area_id: str, metrics: dict[str, Any]) -> dict[str, int]:
    cyclomatic = metrics["complexity"]["cyclomatic_estimate"]
    code_lines = metrics["module_size"]["code_lines"]
    duplication_groups = metrics["duplication"]["group_count"]
    quality_impact = 3 if cyclomatic >= 150 or duplication_groups >= 8 else 2
    risk = 1 if code_lines >= 1200 else 2
    maintainability = 3 if code_lines >= 700 else 2
    feature_goal_contribution = 3 if area_id in {"installer", "root_tooling"} else 2
    specific_score = quality_impact + risk + maintainability + feature_goal_contribution
    return {
        "quality_impact": quality_impact,
        "risk": risk,
        "maintainability": maintainability,
        "feature_goal_contribution": feature_goal_contribution,
        "specific_score": specific_score,
    }


def build_hotspot_candidate(
    metrics: dict[str, Any],
    record: FileRecord | None,
) -> dict[str, Any] | None:
    if metrics["language"] not in CODE_LANGUAGES:
        return None

    cyclomatic = metrics["complexity"]["cyclomatic_estimate"]
    code_lines = metrics["module_size"]["code_lines"]
    duplication_groups = metrics["duplication"]["group_count"]
    if cyclomatic < 100 or code_lines < 500:
        return None

    area_id = classify_area(Path(metrics["path"]))
    area_label = AREA_LABELS.get(area_id, area_id)
    common_axes = build_hotspot_common_axes(area_id, metrics)
    rubric = build_hotspot_rubric(area_id, metrics)
    common_score = compute_common_score(common_axes)
    specific_score = rubric["specific_score"]
    priority_score = (common_score * 2) + specific_score
    decision, priority_grade = determine_refactor_decision(
        common_axes,
        rubric["quality_impact"],
        rubric["risk"],
        rubric["maintainability"],
        rubric["feature_goal_contribution"],
        priority_score,
    )

    representative_symbols: list[str] = []
    evidence_locations = [metrics["path"]]
    if record is not None:
        for definition, span in symbol_spans(record)[:3]:
            representative_symbols.append(f"{definition.name}({span} lines)")
            evidence_locations.append(f"{metrics['path']}:{definition.line}")

    problem_signals = [
        f"`{metrics['path']}` 가 code_lines={code_lines}, cyclomatic_estimate={cyclomatic}, duplication_group_count={duplication_groups} 로 큰 핫스팟임",
    ]
    if metrics["change_frequency"]["commit_count"]:
        problem_signals.append(
            f"변경 빈도도 commit_count={metrics['change_frequency']['commit_count']} 로 누적돼 수정 안정성 압박이 큼"
        )
    if representative_symbols:
        problem_signals.append("큰 책임 덩어리 예시: " + ", ".join(representative_symbols))

    expected_improvement = [
        "탐지, 점수화, 렌더링 같은 책임을 더 작은 단위로 쪼개 다음 수정 범위를 좁힘",
        "후속 기능 추가나 규칙 수정 때 회귀 범위를 줄이고 테스트 포인트를 더 선명하게 만듦",
    ]
    if area_id in {"installer", "root_tooling"}:
        expected_improvement.append("자가 개선 루프의 핵심 도구를 더 안정적으로 확장할 수 있게 함")

    selection_rationale = [
        f"공통 축 판정: {', '.join(f'{key}={value}' for key, value in common_axes.items())}",
        f"리팩터링 루브릭: quality_impact={rubric['quality_impact']}, risk={rubric['risk']}, maintainability={rubric['maintainability']}, feature_goal_contribution={rubric['feature_goal_contribution']}",
        "복잡도, 파일 크기, 중복 지표가 같이 높아 단일 파일에 책임이 몰린 신호가 분명함",
    ]

    return {
        "proposal_id": f"refactor:hotspot:{metrics['path']}",
        "candidate_kind": "refactor",
        "title": f"{metrics['path']} 책임 분리와 경계 정리",
        "linked_gap": "quality_gap",
        "functional_area": area_id,
        "functional_area_label": area_label,
        "problem_signals": problem_signals,
        "expected_improvement": expected_improvement,
        "selection_rationale": selection_rationale,
        "evidence_locations": unique_preserve_order(evidence_locations),
        "common_axes": common_axes,
        "refactor_rubric": rubric,
        "common_score": common_score,
        "specific_score": specific_score,
        "priority_score": priority_score,
        "priority_grade": priority_grade,
        "decision": decision,
        "source_signals": {
            "candidate_source": "complexity_hotspot",
            "path": metrics["path"],
            "cyclomatic_estimate": cyclomatic,
            "code_lines": code_lines,
            "duplication_group_count": duplication_groups,
            "commit_count": metrics["change_frequency"]["commit_count"],
        },
    }


def build_refactor_candidates(root: Path, metrics_payload: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    files_by_path = {item["path"]: item for item in metrics_payload.get("files", [])}
    file_records = build_file_records(root, metrics_payload)

    candidates: list[dict[str, Any]] = []
    for group in metrics_payload.get("duplication", {}).get("groups", []):
        if int(group.get("normalized_line_count", 0)) < 10:
            continue
        candidate = build_duplicate_candidate(group, files_by_path, file_records)
        if candidate is not None:
            candidates.append(candidate)

    for item in metrics_payload.get("files", []):
        record = file_records.get(item["path"])
        candidate = build_hotspot_candidate(item, record)
        if candidate is not None:
            candidates.append(candidate)

    deduped: list[dict[str, Any]] = []
    seen_titles: set[str] = set()
    for candidate in sorted(
        candidates,
        key=lambda item: (
            {"pick": 0, "defer": 1, "needs_approval": 2, "reject": 3}.get(item["decision"], 4),
            -item["priority_score"],
            -item["refactor_rubric"]["feature_goal_contribution"],
            -item["refactor_rubric"]["quality_impact"],
            item["title"],
        ),
    ):
        if candidate["title"] in seen_titles:
            continue
        seen_titles.add(candidate["title"])
        deduped.append(candidate)
        if len(deduped) >= limit:
            break

    return deduped


def build_payload(root: Path, metrics_payload: dict[str, Any], candidates: list[dict[str, Any]]) -> dict[str, Any]:
    area_counts: dict[str, int] = {}
    for candidate in candidates:
        area_id = candidate["functional_area"]
        area_counts[area_id] = area_counts.get(area_id, 0) + 1

    return {
        "schema_version": SCHEMA_VERSION,
        "root": str(root.resolve()),
        "scanned_file_count": metrics_payload.get("summary", {}).get("file_count", 0),
        "refactor_candidate_count": len(candidates),
        "area_counts": area_counts,
        "refactor_candidates": candidates,
    }


def render_markdown_report(payload: dict[str, Any]) -> str:
    lines = [
        "# Refactor Candidates",
        "",
        "이 문서는 저장소 분석 결과를 바탕으로 코드 품질과 변경 안정성을 높일 리팩터링 후보를 정리한다.",
        "각 항목은 문제 징후, 개선 기대효과, 선정 근거를 함께 남겨 다음 계획 단계의 직접 입력으로 쓴다.",
        "",
        f"- schema_version: `{payload['schema_version']}`",
        f"- scanned_file_count: `{payload['scanned_file_count']}`",
        f"- refactor_candidate_count: `{payload['refactor_candidate_count']}`",
        "",
        "## Refactor Candidates",
        "",
    ]

    for candidate in payload["refactor_candidates"]:
        lines.extend(
            [
                f"### {candidate['functional_area_label']} / {candidate['title']}",
                "",
                f"- 결정: `{candidate['decision']}` / 등급 `{candidate['priority_grade']}` / 점수 `{candidate['priority_score']}`",
                "- 문제 징후:",
            ]
        )
        for item in candidate["problem_signals"]:
            lines.append(f"  - {item}")
        lines.append("- 개선 기대효과:")
        for item in candidate["expected_improvement"]:
            lines.append(f"  - {item}")
        lines.append("- 선정 근거:")
        for item in candidate["selection_rationale"]:
            lines.append(f"  - {item}")
        lines.append("- 근거 위치:")
        for item in candidate["evidence_locations"]:
            lines.append(f"  - `{item}`")
        lines.append(
            "- 공통 축 판정: "
            + ", ".join(f"{key}={value}" for key, value in candidate["common_axes"].items())
        )
        rubric = candidate["refactor_rubric"]
        lines.append(
            "- 리팩터링 루브릭: "
            + ", ".join(
                [
                    f"quality_impact={rubric['quality_impact']}",
                    f"risk={rubric['risk']}",
                    f"maintainability={rubric['maintainability']}",
                    f"feature_goal_contribution={rubric['feature_goal_contribution']}",
                    f"specific_score={rubric['specific_score']}",
                ]
            )
        )
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    args = parse_args()
    root = Path(args.root).resolve()
    metrics_payload = load_metrics(root, args.metrics_input)
    candidates = build_refactor_candidates(root, metrics_payload, max(args.limit, 1))
    payload = build_payload(root, metrics_payload, candidates)

    if args.format == "markdown":
        print(render_markdown_report(payload), end="")
        return

    if args.pretty:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return

    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
