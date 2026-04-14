#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


FAILURE_WORDS = ("error", "failed", "failure", "fatal", "exception")
WARNING_WORDS = ("warning", "warn", "deprecated", "caution")
ANALYSIS_SCHEMA_VERSION = 1
HISTORY_SCHEMA_VERSION = 1
REPO_METRICS_SCHEMA_VERSION = 1
QUALITY_SIGNAL_PROFILE_VERSION = 1
PRIORITY_SCORE_MAX = 48

REPO_METRIC_CAPS = {
    "code_lines": 400,
    "bytes": 20000,
    "max_line_length": 120,
    "max_indent_level": 6,
    "cyclomatic_estimate": 25,
    "decision_points": 40,
    "function_like_blocks": 20,
    "group_count": 3,
    "duplicated_line_instances": 30,
    "max_duplicate_block_lines": 10,
    "commit_count": 8,
    "commits_per_30_days": 4,
    "author_count": 3,
}

REPO_SIGNAL_AXIS_WEIGHTS = {
    "size_pressure": {
        "code_lines": 0.45,
        "bytes": 0.2,
        "max_line_length": 0.2,
        "max_indent_level": 0.15,
    },
    "complexity_pressure": {
        "cyclomatic_estimate": 0.55,
        "decision_points": 0.3,
        "function_like_blocks": 0.15,
    },
    "duplication_pressure": {
        "duplicated_line_instances": 0.5,
        "group_count": 0.3,
        "max_duplicate_block_lines": 0.2,
    },
    "change_pressure": {
        "commit_count": 0.4,
        "commits_per_30_days": 0.4,
        "author_count": 0.2,
    },
}

REPO_SIGNAL_WEIGHTS = {
    "size_pressure": 0.15,
    "complexity_pressure": 0.35,
    "duplication_pressure": 0.3,
    "change_pressure": 0.2,
}

MARKDOWNLINT_PATTERN = re.compile(
    r"^(?P<path>.+?):(?P<line>\d+)(?::(?P<column>\d+))?\s+"
    r"(?P<code>MD\d{3}(?:/[^\s]+)?)\s+(?P<message>.+)$"
)
GENERIC_PATH_PATTERN = re.compile(
    r"^(?P<path>[^:\n]+):(?P<line>\d+)(?::(?P<column>\d+))?:\s+(?P<message>.+)$"
)
SHELLCHECK_PATTERN = re.compile(
    r"^In\s+(?P<path>.+?)\s+line\s+(?P<line>\d+):\s*$", re.MULTILINE
)
SHELLCHECK_CODE_PATTERN = re.compile(r"https://www\.shellcheck\.net/wiki/(?P<code>SC\d+)")
PYTEST_WARNING_PATTERN = re.compile(r"(?P<message>.+?)\s+warning[s]?$", re.IGNORECASE)
PERCENTAGE_PATTERN = re.compile(r"(?P<value>\d+(?:\.\d+)?)%")
LINES_COVERAGE_PATTERN = re.compile(
    r"Lines:\s*(?P<percent>\d+(?:\.\d+)?)%\s*\((?P<covered>\d+)/(?P<total>\d+)\)",
    re.IGNORECASE,
)
BRANCHES_COVERAGE_PATTERN = re.compile(
    r"Branches:\s*(?P<percent>\d+(?:\.\d+)?)%\s*\((?P<covered>\d+)/(?P<total>\d+)\)",
    re.IGNORECASE,
)
TOTAL_COVERAGE_PATTERN = re.compile(
    r"^TOTAL\s+(?P<stmts>\d+)\s+(?P<miss>\d+)\s+(?P<percent>\d+(?:\.\d+)?)%\s*$",
    re.IGNORECASE | re.MULTILINE,
)
TABLE_COVERAGE_PATTERN = re.compile(
    r"^All files\s+\|(?P<body>.+?)\|\s*(?P<percent>\d+(?:\.\d+)?)\s*$",
    re.IGNORECASE | re.MULTILINE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize quality-tool execution results into one shared JSON schema."
    )
    parser.add_argument(
        "--input",
        help="JSON file containing either a result object or {\"results\": [...]} payload.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print the normalized JSON output.",
    )
    parser.add_argument(
        "--history",
        help="JSON file path used to append or query normalized analysis history.",
    )
    parser.add_argument(
        "--store",
        action="store_true",
        help="Append the normalized analysis to the history file given by --history.",
    )
    parser.add_argument(
        "--query",
        choices=("all", "latest", "summary"),
        help="Read stored analysis history from --history instead of normalizing fresh input.",
    )
    args = parser.parse_args()

    if args.store and not args.history:
        parser.error("--store requires --history")
    if args.query and not args.history:
        parser.error("--query requires --history")
    if args.query and args.store:
        parser.error("--query cannot be combined with --store")
    if args.query and args.input:
        parser.error("--query cannot be combined with --input")

    return args


def load_payload(path: str | None) -> Any:
    if path:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)

    return json.load(sys.stdin)


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def build_history_store(entries: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    normalized_entries = entries or []
    latest = normalized_entries[-1] if normalized_entries else None
    latest_entry_id = latest.get("entry_id") if latest else None
    latest_recorded_at = latest.get("recorded_at") if latest else None
    failed_entry_count = sum(
        1 for entry in normalized_entries if entry.get("analysis", {}).get("failed_tool_count", 0) > 0
    )
    warning_entry_count = sum(
        1 for entry in normalized_entries if entry.get("analysis", {}).get("warning_tool_count", 0) > 0
    )

    analysis_kind_occurrences: dict[str, int] = {}
    tool_occurrences: dict[str, int] = {}
    for entry in normalized_entries:
        analysis_kind = as_text(entry.get("analysis", {}).get("analysis_kind") or "tool_results").strip()
        if analysis_kind:
            analysis_kind_occurrences[analysis_kind] = analysis_kind_occurrences.get(analysis_kind, 0) + 1
        for result in entry.get("analysis", {}).get("results", []) or []:
            tool = as_text(result.get("tool")).strip()
            if not tool:
                continue
            tool_occurrences[tool] = tool_occurrences.get(tool, 0) + 1

    return {
        "history_schema_version": HISTORY_SCHEMA_VERSION,
        "analysis_schema_version": ANALYSIS_SCHEMA_VERSION,
        "entry_count": len(normalized_entries),
        "failed_entry_count": failed_entry_count,
        "warning_entry_count": warning_entry_count,
        "latest_entry_id": latest_entry_id,
        "latest_recorded_at": latest_recorded_at,
        "analysis_kind_occurrences": analysis_kind_occurrences,
        "tool_occurrences": tool_occurrences,
        "entries": normalized_entries,
    }


def load_history(path: str) -> dict[str, Any]:
    history_path = Path(path)
    if not history_path.exists():
        return build_history_store()
    if history_path.stat().st_size == 0:
        return build_history_store()

    with history_path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    if not isinstance(payload, dict) or not isinstance(payload.get("entries"), list):
        raise ValueError("History file must be a JSON object with an 'entries' array.")

    if payload.get("history_schema_version") != HISTORY_SCHEMA_VERSION:
        raise ValueError(
            f"Unsupported history schema version: {payload.get('history_schema_version')!r}"
        )

    entries = [entry for entry in payload.get("entries", []) if isinstance(entry, dict)]
    return build_history_store(entries)


def write_json_atomic(path: str, payload: dict[str, Any]) -> None:
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    fd, temp_path = tempfile.mkstemp(prefix=f".{output_path.name}.", dir=str(output_path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(temp_path, output_path)
    except Exception:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass
        raise


def build_history_entry(normalized: dict[str, Any], input_path: str | None, sequence: int) -> dict[str, Any]:
    return {
        "entry_id": f"analysis-{sequence:04d}",
        "recorded_at": utc_timestamp(),
        "source": {
            "input_kind": "file" if input_path else "stdin",
            "input_path": input_path,
        },
        "analysis": normalized,
    }


def append_history(path: str, normalized: dict[str, Any], input_path: str | None) -> dict[str, Any]:
    history = load_history(path)
    entries = list(history.get("entries", []))
    entry = build_history_entry(normalized, input_path, len(entries) + 1)
    entries.append(entry)
    stored = build_history_store(entries)
    write_json_atomic(path, stored)
    return entry


def query_history(path: str, mode: str) -> dict[str, Any]:
    history = load_history(path)
    if mode == "all":
        return history
    if mode == "latest":
        latest = history.get("entries", [])[-1] if history.get("entries") else None
        return {
            "history_schema_version": history["history_schema_version"],
            "analysis_schema_version": history["analysis_schema_version"],
            "entry_count": history["entry_count"],
            "latest": latest,
        }
    return {
        "history_schema_version": history["history_schema_version"],
        "analysis_schema_version": history["analysis_schema_version"],
        "entry_count": history["entry_count"],
        "failed_entry_count": history["failed_entry_count"],
        "warning_entry_count": history["warning_entry_count"],
        "latest_entry_id": history["latest_entry_id"],
        "latest_recorded_at": history["latest_recorded_at"],
        "analysis_kind_occurrences": history["analysis_kind_occurrences"],
        "tool_occurrences": history["tool_occurrences"],
    }


def as_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(as_text(item) for item in value if item is not None)
    return str(value)


def normalize_tool_name(result: dict[str, Any]) -> str:
    explicit = as_text(result.get("tool") or result.get("name")).strip().lower()
    if explicit:
        return explicit

    command = as_text(result.get("command")).lower()
    if "markdownlint" in command:
        return "markdownlint"
    if "shellcheck" in command:
        return "shellcheck"
    if "psscriptanalyzer" in command:
        return "psscriptanalyzer"
    if "pytest" in command:
        return "pytest"
    if "coverage" in command:
        return "coverage"
    if "bash -n" in command:
        return "bash-parse"
    if "powershell" in command or "pwsh" in command:
        return "powershell"
    return "unknown"


def stream_text(result: dict[str, Any]) -> str:
    parts = [
        as_text(result.get("stdout")),
        as_text(result.get("stderr")),
        as_text(result.get("output")),
    ]
    return "\n".join(part for part in parts if part).strip()


def infer_severity(message: str, default: str = "warning") -> str:
    lowered = message.lower()
    if any(word in lowered for word in FAILURE_WORDS):
        return "failure"
    if any(word in lowered for word in WARNING_WORDS):
        return "warning"
    return default


def make_issue(
    *,
    severity: str,
    message: str,
    path: str | None = None,
    line: int | None = None,
    column: int | None = None,
    code: str | None = None,
    raw: str | None = None,
) -> dict[str, Any]:
    issue = {
        "severity": severity,
        "message": message.strip(),
        "path": path,
        "line": line,
        "column": column,
        "code": code,
        "raw": raw.strip() if raw else None,
    }
    return issue


def parse_structured_issues(result: dict[str, Any]) -> list[dict[str, Any]]:
    parsed: list[dict[str, Any]] = []
    for issue in result.get("issues", []) or []:
        if not isinstance(issue, dict):
            continue
        severity = infer_severity(as_text(issue.get("severity")), default="warning")
        if as_text(issue.get("severity")).strip().lower() in {"error", "failure", "fatal"}:
            severity = "failure"
        elif as_text(issue.get("severity")).strip().lower() in {"warning", "warn", "information"}:
            severity = "warning"

        path = as_text(issue.get("path") or issue.get("file")) or None
        line = coerce_int(issue.get("line"))
        column = coerce_int(issue.get("column"))
        code = as_text(issue.get("code") or issue.get("rule")) or None
        message = as_text(issue.get("message") or issue.get("text") or issue.get("detail"))
        if not message:
            continue
        parsed.append(
            make_issue(
                severity=severity,
                message=message,
                path=path,
                line=line,
                column=column,
                code=code,
                raw=as_text(issue.get("raw")),
            )
        )
    return parsed


def parse_markdownlint(text: str) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = MARKDOWNLINT_PATTERN.match(line.strip())
        if not match:
            continue
        issues.append(
            make_issue(
                severity="failure",
                path=match.group("path"),
                line=coerce_int(match.group("line")),
                column=coerce_int(match.group("column")),
                code=match.group("code"),
                message=match.group("message"),
                raw=line,
            )
        )
    return issues


def parse_shellcheck(text: str) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        header = SHELLCHECK_PATTERN.match(lines[index])
        if not header:
            index += 1
            continue
        path = header.group("path")
        line = coerce_int(header.group("line"))
        message = "ShellCheck issue"
        if index + 2 < len(lines):
            caret_line = lines[index + 2].strip()
            marker = re.search(r"\((?:warning|error)\):\s*(?P<message>.+)$", caret_line, re.IGNORECASE)
            if marker:
                message = marker.group("message")
        elif index + 1 < len(lines):
            message = lines[index + 1].strip()
        code = None
        window = "\n".join(lines[index : min(index + 6, len(lines))])
        code_match = SHELLCHECK_CODE_PATTERN.search(window)
        if code_match:
            code = code_match.group("code")
        issues.append(
            make_issue(
                severity="warning",
                path=path,
                line=line,
                code=code,
                message=message,
                raw=window,
            )
        )
        index += 1
    return issues


def parse_generic_path_issues(text: str) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for line in text.splitlines():
        match = GENERIC_PATH_PATTERN.match(line.strip())
        if not match:
            continue
        message = match.group("message")
        issues.append(
            make_issue(
                severity=infer_severity(message),
                path=match.group("path"),
                line=coerce_int(match.group("line")),
                column=coerce_int(match.group("column")),
                message=message,
                raw=line,
            )
        )
    return issues


def parse_pytest_summary(text: str) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for line in text.splitlines():
        lowered = line.lower().strip()
        if not lowered:
            continue
        if " failed" in lowered or lowered.startswith("failed "):
            issues.append(make_issue(severity="failure", message=line.strip(), raw=line))
        elif "warnings summary" in lowered:
            continue
        elif " warning" in lowered:
            severity = "warning"
            warning_match = PYTEST_WARNING_PATTERN.search(line.strip())
            message = warning_match.group("message") if warning_match else line.strip()
            issues.append(make_issue(severity=severity, message=message, raw=line))
    return issues


def dedupe_issues(issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
    deduped: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for issue in issues:
        key = (
            issue.get("severity"),
            issue.get("path"),
            issue.get("line"),
            issue.get("column"),
            issue.get("code"),
            issue.get("message"),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(issue)
    return deduped


def coerce_int(value: Any) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(str(value))
    except ValueError:
        return None


def coerce_float(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(str(value))
    except ValueError:
        return None


def round_score(value: float) -> float:
    return round(value, 4)


def clamp_score(value: float) -> float:
    return max(0.0, min(1.0, value))


def detect_repo_metrics_payload(payload: Any) -> bool:
    return (
        isinstance(payload, dict)
        and payload.get("schema_version") == REPO_METRICS_SCHEMA_VERSION
        and isinstance(payload.get("files"), list)
        and isinstance(payload.get("summary"), dict)
    )


def repo_metric_observed_maxima(files: list[dict[str, Any]]) -> dict[str, float]:
    maxima = {key: 0.0 for key in REPO_METRIC_CAPS}
    for item in files:
        module_size = item.get("module_size", {}) if isinstance(item.get("module_size"), dict) else {}
        complexity = item.get("complexity", {}) if isinstance(item.get("complexity"), dict) else {}
        duplication = item.get("duplication", {}) if isinstance(item.get("duplication"), dict) else {}
        change_frequency = (
            item.get("change_frequency", {}) if isinstance(item.get("change_frequency"), dict) else {}
        )

        maxima["code_lines"] = max(maxima["code_lines"], float(coerce_int(module_size.get("code_lines")) or 0))
        maxima["bytes"] = max(maxima["bytes"], float(coerce_int(module_size.get("bytes")) or 0))
        maxima["max_line_length"] = max(
            maxima["max_line_length"],
            float(coerce_int(module_size.get("max_line_length")) or 0),
        )
        maxima["max_indent_level"] = max(
            maxima["max_indent_level"],
            float(coerce_int(complexity.get("max_indent_level")) or 0),
        )
        maxima["cyclomatic_estimate"] = max(
            maxima["cyclomatic_estimate"],
            float(coerce_int(complexity.get("cyclomatic_estimate")) or 0),
        )
        maxima["decision_points"] = max(
            maxima["decision_points"],
            float(coerce_int(complexity.get("decision_points")) or 0),
        )
        maxima["function_like_blocks"] = max(
            maxima["function_like_blocks"],
            float(coerce_int(complexity.get("function_like_blocks")) or 0),
        )
        maxima["group_count"] = max(
            maxima["group_count"],
            float(coerce_int(duplication.get("group_count")) or 0),
        )
        maxima["duplicated_line_instances"] = max(
            maxima["duplicated_line_instances"],
            float(coerce_int(duplication.get("duplicated_line_instances")) or 0),
        )
        maxima["max_duplicate_block_lines"] = max(
            maxima["max_duplicate_block_lines"],
            float(coerce_int(duplication.get("max_duplicate_block_lines")) or 0),
        )
        maxima["commit_count"] = max(
            maxima["commit_count"],
            float(coerce_int(change_frequency.get("commit_count")) or 0),
        )
        maxima["commits_per_30_days"] = max(
            maxima["commits_per_30_days"],
            float(coerce_float(change_frequency.get("commits_per_30_days")) or 0.0),
        )
        maxima["author_count"] = max(
            maxima["author_count"],
            float(coerce_int(change_frequency.get("author_count")) or 0),
        )
    return maxima


def normalize_repo_metric(value: float, observed_max: float, cap: float) -> float:
    if value <= 0:
        return 0.0
    relative_component = value / observed_max if observed_max > 0 else 0.0
    cap_component = min(value / cap, 1.0) if cap > 0 else 0.0
    return round_score(clamp_score((relative_component + cap_component) / 2.0))


def build_repo_metric_inputs(item: dict[str, Any]) -> dict[str, float]:
    module_size = item.get("module_size", {}) if isinstance(item.get("module_size"), dict) else {}
    complexity = item.get("complexity", {}) if isinstance(item.get("complexity"), dict) else {}
    duplication = item.get("duplication", {}) if isinstance(item.get("duplication"), dict) else {}
    change_frequency = (
        item.get("change_frequency", {}) if isinstance(item.get("change_frequency"), dict) else {}
    )
    commit_count = float(coerce_int(change_frequency.get("commit_count")) or 0)
    commits_per_30_days = float(coerce_float(change_frequency.get("commits_per_30_days")) or 0.0)
    if commit_count < 2:
        commits_per_30_days = 0.0

    return {
        "code_lines": float(coerce_int(module_size.get("code_lines")) or 0),
        "bytes": float(coerce_int(module_size.get("bytes")) or 0),
        "max_line_length": float(coerce_int(module_size.get("max_line_length")) or 0),
        "max_indent_level": float(coerce_int(complexity.get("max_indent_level")) or 0),
        "cyclomatic_estimate": float(coerce_int(complexity.get("cyclomatic_estimate")) or 0),
        "decision_points": float(coerce_int(complexity.get("decision_points")) or 0),
        "function_like_blocks": float(coerce_int(complexity.get("function_like_blocks")) or 0),
        "group_count": float(coerce_int(duplication.get("group_count")) or 0),
        "duplicated_line_instances": float(coerce_int(duplication.get("duplicated_line_instances")) or 0),
        "max_duplicate_block_lines": float(coerce_int(duplication.get("max_duplicate_block_lines")) or 0),
        "commit_count": commit_count,
        "commits_per_30_days": commits_per_30_days,
        "author_count": float(coerce_int(change_frequency.get("author_count")) or 0),
    }


def grade_repo_priority(priority_score: float) -> str:
    if priority_score >= 40:
        return "A"
    if priority_score >= 32:
        return "B"
    if priority_score >= 24:
        return "C"
    return "D"


def repo_priority_decision(priority_grade: str) -> str:
    if priority_grade in {"A", "B"}:
        return "prioritize"
    if priority_grade == "C":
        return "monitor"
    return "low"


def summarize_repo_hotspot(entry: dict[str, Any]) -> str:
    top_signal = entry["quality_signal"]["top_signals"][0]
    return (
        f"{entry['path']} | score={entry['quality_signal']['priority_score']:.2f} "
        f"| grade={entry['quality_signal']['priority_grade']} "
        f"| top_signal={top_signal['metric']}"
    )


def normalize_repo_metric_file(
    item: dict[str, Any], observed_maxima: dict[str, float]
) -> dict[str, Any]:
    metric_inputs = build_repo_metric_inputs(item)
    axis_breakdown: dict[str, dict[str, Any]] = {}
    signal_contributions: list[dict[str, Any]] = []

    for axis_name, axis_weights in REPO_SIGNAL_AXIS_WEIGHTS.items():
        axis_score = 0.0
        metrics: list[dict[str, Any]] = []
        for metric_name, metric_weight in axis_weights.items():
            raw_value = metric_inputs[metric_name]
            normalized_value = normalize_repo_metric(
                raw_value,
                observed_maxima.get(metric_name, 0.0),
                float(REPO_METRIC_CAPS[metric_name]),
            )
            contribution = normalized_value * metric_weight
            axis_score += contribution
            metrics.append(
                {
                    "metric": metric_name,
                    "raw": raw_value,
                    "normalized": normalized_value,
                    "weight": metric_weight,
                    "axis_contribution": round_score(contribution),
                }
            )
            signal_contributions.append(
                {
                    "axis": axis_name,
                    "metric": metric_name,
                    "raw": raw_value,
                    "normalized": normalized_value,
                    "weight": metric_weight,
                    "axis_contribution": round_score(contribution),
                }
            )

        axis_breakdown[axis_name] = {
            "weight": REPO_SIGNAL_WEIGHTS[axis_name],
            "score": round_score(axis_score),
            "weighted_contribution": round_score(axis_score * REPO_SIGNAL_WEIGHTS[axis_name]),
            "metrics": metrics,
        }

    weighted_score = sum(
        axis_info["weighted_contribution"] for axis_info in axis_breakdown.values()
    )
    priority_score = round(weighted_score * PRIORITY_SCORE_MAX, 2)
    priority_grade = grade_repo_priority(priority_score)
    top_signals = sorted(
        signal_contributions,
        key=lambda signal: (
            -signal["axis_contribution"],
            -signal["normalized"],
            signal["metric"],
        ),
    )[:3]

    return {
        "path": as_text(item.get("path")),
        "language": as_text(item.get("language")),
        "module_size": item.get("module_size"),
        "complexity": item.get("complexity"),
        "duplication": item.get("duplication"),
        "change_frequency": item.get("change_frequency"),
        "quality_signal": {
            "profile_version": QUALITY_SIGNAL_PROFILE_VERSION,
            "weighted_score": round_score(weighted_score),
            "priority_score": priority_score,
            "priority_grade": priority_grade,
            "priority_decision": repo_priority_decision(priority_grade),
            "axis_breakdown": axis_breakdown,
            "top_signals": top_signals,
            "summary": summarize_repo_hotspot(
                {
                    "path": as_text(item.get("path")),
                    "quality_signal": {
                        "priority_score": priority_score,
                        "priority_grade": priority_grade,
                        "top_signals": top_signals or [{"metric": "none"}],
                    },
                }
            ),
        },
    }


def normalize_repo_metrics_payload(payload: dict[str, Any]) -> dict[str, Any]:
    files = [item for item in payload.get("files", []) if isinstance(item, dict)]
    observed_maxima = repo_metric_observed_maxima(files)
    normalized_files = [normalize_repo_metric_file(item, observed_maxima) for item in files]
    ranked_files = sorted(
        normalized_files,
        key=lambda item: (
            -item["quality_signal"]["priority_score"],
            -item["quality_signal"]["weighted_score"],
            item["path"],
        ),
    )

    for index, item in enumerate(ranked_files, start=1):
        item["quality_signal"]["priority_rank"] = index

    grade_distribution = {grade: 0 for grade in ("A", "B", "C", "D")}
    decision_distribution = {"prioritize": 0, "monitor": 0, "low": 0}
    total_weighted_score = 0.0
    for item in ranked_files:
        grade_distribution[item["quality_signal"]["priority_grade"]] += 1
        decision_distribution[item["quality_signal"]["priority_decision"]] += 1
        total_weighted_score += item["quality_signal"]["weighted_score"]

    hotspot_count = min(5, len(ranked_files))
    return {
        "schema_version": ANALYSIS_SCHEMA_VERSION,
        "analysis_kind": "repo_metrics",
        "source_schema_version": payload.get("schema_version"),
        "result_count": len(ranked_files),
        "priority_count": len(ranked_files),
        "weights": {
            "priority_score_max": PRIORITY_SCORE_MAX,
            "axis_weights": REPO_SIGNAL_WEIGHTS,
            "metric_caps": REPO_METRIC_CAPS,
            "axis_metric_weights": REPO_SIGNAL_AXIS_WEIGHTS,
        },
        "summary": {
            "file_count": len(ranked_files),
            "average_weighted_score": round_score(
                total_weighted_score / len(ranked_files) if ranked_files else 0.0
            ),
            "max_priority_score": max(
                (item["quality_signal"]["priority_score"] for item in ranked_files),
                default=0.0,
            ),
            "priority_grade_distribution": grade_distribution,
            "priority_decision_distribution": decision_distribution,
        },
        "hotspots": [
            {
                "path": item["path"],
                "language": item["language"],
                "priority_rank": item["quality_signal"]["priority_rank"],
                "priority_score": item["quality_signal"]["priority_score"],
                "priority_grade": item["quality_signal"]["priority_grade"],
                "priority_decision": item["quality_signal"]["priority_decision"],
                "top_signal": item["quality_signal"]["top_signals"][0]["metric"],
                "summary": item["quality_signal"]["summary"],
            }
            for item in ranked_files[:hotspot_count]
        ],
        "results": ranked_files,
    }


def parse_coverage(result: dict[str, Any], text: str) -> dict[str, Any] | None:
    if isinstance(result.get("coverage"), dict):
        coverage = result["coverage"].copy()
        percent = coerce_float(coverage.get("percent"))
        if percent is not None:
            coverage["percent"] = percent
        for key in ("lines_covered", "lines_total", "branches_covered", "branches_total"):
            coverage[key] = coerce_int(coverage.get(key))
        coverage["raw"] = coverage.get("raw") or None
        return coverage

    lines_match = LINES_COVERAGE_PATTERN.search(text)
    branches_match = BRANCHES_COVERAGE_PATTERN.search(text)
    total_match = TOTAL_COVERAGE_PATTERN.search(text)
    table_match = TABLE_COVERAGE_PATTERN.search(text)

    percent = None
    lines_covered = None
    lines_total = None
    branches_covered = None
    branches_total = None
    raw = None

    if lines_match:
        percent = coerce_float(lines_match.group("percent"))
        lines_covered = coerce_int(lines_match.group("covered"))
        lines_total = coerce_int(lines_match.group("total"))
        raw = lines_match.group(0)
    elif total_match:
        percent = coerce_float(total_match.group("percent"))
        statements = coerce_int(total_match.group("stmts"))
        missed = coerce_int(total_match.group("miss"))
        if statements is not None and missed is not None:
            lines_total = statements
            lines_covered = max(statements - missed, 0)
        raw = total_match.group(0)
    elif table_match:
        percent = coerce_float(table_match.group("percent"))
        raw = table_match.group(0)
    else:
        percent_hint = coerce_float(result.get("coverage_percent"))
        if percent_hint is not None:
            percent = percent_hint
            raw = f"coverage_percent={percent_hint}"

    if branches_match:
        branches_covered = coerce_int(branches_match.group("covered"))
        branches_total = coerce_int(branches_match.group("total"))
        raw = "\n".join(part for part in (raw, branches_match.group(0)) if part)

    if percent is None and not any(
        value is not None
        for value in (lines_covered, lines_total, branches_covered, branches_total)
    ):
        return None

    status = "covered" if percent is not None else "partial"
    return {
        "status": status,
        "percent": percent,
        "lines_covered": lines_covered,
        "lines_total": lines_total,
        "branches_covered": branches_covered,
        "branches_total": branches_total,
        "raw": raw,
    }


def build_summary(tool: str, status: str, failure_count: int, warning_count: int, coverage: dict[str, Any] | None) -> str:
    parts = [tool, status]
    parts.append(f"failures={failure_count}")
    parts.append(f"warnings={warning_count}")
    if coverage and coverage.get("percent") is not None:
        parts.append(f"coverage={coverage['percent']:.2f}%")
    return " | ".join(parts)


def normalize_result(result: dict[str, Any]) -> dict[str, Any]:
    tool = normalize_tool_name(result)
    text = stream_text(result)
    issues = parse_structured_issues(result)

    if tool == "markdownlint":
        issues.extend(parse_markdownlint(text))
    elif tool == "shellcheck":
        issues.extend(parse_shellcheck(text))
    elif tool in {"pytest", "coverage"}:
        issues.extend(parse_pytest_summary(text))

    issues.extend(parse_generic_path_issues(text))
    issues = dedupe_issues(issues)

    failures = [issue for issue in issues if issue["severity"] == "failure"]
    warnings = [issue for issue in issues if issue["severity"] == "warning"]
    coverage = parse_coverage(result, text)

    exit_code = coerce_int(result.get("exit_code"))
    status = "ok"
    if exit_code not in (None, 0) or failures:
        status = "failed"
    elif warnings:
        status = "warning"

    return {
        "tool": tool,
        "command": as_text(result.get("command")) or None,
        "status": status,
        "exit_code": exit_code,
        "failure_count": len(failures),
        "warning_count": len(warnings),
        "failures": failures,
        "warnings": warnings,
        "coverage": coverage,
        "summary": build_summary(tool, status, len(failures), len(warnings), coverage),
        "raw_excerpt": text[:500] if text else None,
    }


def normalize_payload(payload: Any) -> dict[str, Any]:
    if detect_repo_metrics_payload(payload):
        return normalize_repo_metrics_payload(payload)

    if isinstance(payload, dict) and isinstance(payload.get("results"), list):
        items = payload["results"]
    elif isinstance(payload, list):
        items = payload
    elif isinstance(payload, dict):
        items = [payload]
    else:
        raise ValueError("Input must be a JSON object, a list, or an object with a 'results' array.")

    normalized = [normalize_result(item) for item in items if isinstance(item, dict)]
    failed_tools = [item["tool"] for item in normalized if item["status"] == "failed"]
    warning_tools = [item["tool"] for item in normalized if item["status"] == "warning"]
    coverage_tools = [
        item["tool"]
        for item in normalized
        if item.get("coverage") and item["coverage"].get("percent") is not None
    ]

    return {
        "schema_version": ANALYSIS_SCHEMA_VERSION,
        "analysis_kind": "tool_results",
        "result_count": len(normalized),
        "failed_tool_count": len(failed_tools),
        "warning_tool_count": len(warning_tools),
        "coverage_tool_count": len(coverage_tools),
        "failed_tools": failed_tools,
        "warning_tools": warning_tools,
        "coverage_tools": coverage_tools,
        "results": normalized,
    }


def main() -> int:
    args = parse_args()
    if args.query:
        output = query_history(args.history, args.query)
    else:
        payload = load_payload(args.input)
        normalized = normalize_payload(payload)
        output = append_history(args.history, normalized, args.input) if args.store else normalized

    json.dump(output, sys.stdout, ensure_ascii=False, indent=2 if args.pretty else None)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
