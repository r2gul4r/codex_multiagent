#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
MAX_FILE_BYTES = 512 * 1024
SKIP_DIRS = {".git", ".codex", "__pycache__"}
TEXT_SUFFIXES = {
    "",
    ".md",
    ".py",
    ".ps1",
    ".rules",
    ".sh",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}
SKIP_REPORT_PATHS = {
    "docs/FEATURE_GAP_AREAS.md",
    "docs/REFACTOR_CANDIDATES.md",
    "docs/TEST_GAP_AREAS.md",
}
TEST_FILE_PATTERN = re.compile(r"(?i)(^test_|_test\.|tests?/)")
PYTHON_DEF_PATTERN = re.compile(r"^\s*(def|class)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b")
SHELL_DEF_PATTERN = re.compile(
    r"^\s*(?:function\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\))?\s*\{"
)
POWERSHELL_DEF_PATTERN = re.compile(r"^\s*function\s+(?P<name>[A-Za-z_][A-Za-z0-9_-]*)\b", re.IGNORECASE)
STOPWORDS = {
    "build",
    "main",
    "parse",
    "args",
    "load",
    "write",
    "query",
    "make",
    "with",
    "from",
    "none",
    "root",
    "path",
    "file",
    "text",
    "data",
    "item",
}


@dataclass(frozen=True)
class SymbolLocation:
    name: str
    line: int
    symbol_kind: str


@dataclass(frozen=True)
class FileRecord:
    path: Path
    relative_path: str
    language: str
    lines: list[str]
    content: str
    is_test_file: bool
    definitions: list[SymbolLocation]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract evidence-backed test and verification gaps from repository files."
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


def infer_language(path: Path) -> str:
    lower_name = path.name.lower()
    suffix = path.suffix.lower()
    if lower_name == "makefile":
        return "makefile"
    if suffix == ".py":
        return "python"
    if suffix == ".sh":
        return "shell"
    if suffix == ".ps1":
        return "powershell"
    if suffix in {".md", ".txt"}:
        return "text"
    return "text"


def should_scan(path: Path) -> bool:
    if any(part in SKIP_DIRS for part in path.parts):
        return False
    if path.is_dir():
        return False
    if path.name == "STATE.md":
        return False
    if path.as_posix().endswith(tuple(SKIP_REPORT_PATHS)):
        return False
    suffix = path.suffix.lower()
    if path.name != "Makefile" and suffix not in TEXT_SUFFIXES:
        return False
    try:
        return path.stat().st_size <= MAX_FILE_BYTES
    except OSError:
        return False


def is_test_file(path: Path) -> bool:
    return bool(TEST_FILE_PATTERN.search(path.as_posix()))


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def extract_definitions(language: str, lines: list[str]) -> list[SymbolLocation]:
    if language == "python":
        pattern = PYTHON_DEF_PATTERN
        symbol_kind = "python"
    elif language == "shell":
        pattern = SHELL_DEF_PATTERN
        symbol_kind = "shell"
    elif language == "powershell":
        pattern = POWERSHELL_DEF_PATTERN
        symbol_kind = "powershell"
    else:
        return []

    definitions: list[SymbolLocation] = []
    for line_number, line in enumerate(lines, start=1):
        match = pattern.search(line)
        if not match:
            continue
        definitions.append(
            SymbolLocation(
                name=match.group("name"),
                line=line_number,
                symbol_kind=symbol_kind,
            )
        )
    return definitions


def build_record(root: Path, path: Path) -> FileRecord:
    lines = read_lines(path)
    language = infer_language(path)
    return FileRecord(
        path=path,
        relative_path=path.relative_to(root).as_posix(),
        language=language,
        lines=lines,
        content="\n".join(lines),
        is_test_file=is_test_file(path),
        definitions=extract_definitions(language, lines),
    )


def build_repo_index(root: Path) -> dict[str, Any]:
    paths = sorted(path for path in root.rglob("*") if should_scan(path))
    records = [build_record(root, path) for path in paths]
    by_path = {record.relative_path: record for record in records}
    return {
        "records": records,
        "by_path": by_path,
        "test_records": [record for record in records if record.is_test_file],
        "source_records": [
            record
            for record in records
            if not record.is_test_file and record.language in {"python", "shell", "powershell"}
        ],
    }


def find_line_number(record: FileRecord | None, pattern: str) -> int | None:
    if record is None:
        return None
    for line_number, line in enumerate(record.lines, start=1):
        if pattern in line:
            return line_number
    return None


def first_definition_line(record: FileRecord) -> int:
    return record.definitions[0].line if record.definitions else 1


def build_search_terms(record: FileRecord) -> list[str]:
    terms = {record.path.stem.lower().replace("-", "_")}
    for definition in record.definitions[:8]:
        name = definition.name.lower().replace("-", "_")
        if len(name) < 4 or name in STOPWORDS:
            continue
        terms.add(name)
    return sorted(term for term in terms if term and term not in STOPWORDS)


def find_matching_tests(record: FileRecord, test_records: list[FileRecord]) -> list[str]:
    search_terms = build_search_terms(record)
    matches: list[str] = []
    for test_record in test_records:
        haystack = f"{test_record.relative_path}\n{test_record.content}".lower()
        if any(term in haystack for term in search_terms):
            matches.append(test_record.relative_path)
    return sorted(set(matches))


def make_evidence(path: str, line: int | None, summary: str) -> dict[str, Any]:
    return {
        "path": path,
        "line": line,
        "summary": summary,
    }


def format_evidence_ref(entry: dict[str, Any]) -> str:
    if entry.get("line"):
        return f"{entry['path']}:{entry['line']}"
    return entry["path"]


def build_missing_module_test_finding(
    title: str,
    area: str,
    severity: str,
    records: list[FileRecord],
    test_records: list[FileRecord],
    scenario: str,
    rationale: str,
    finding_id: str,
) -> dict[str, Any] | None:
    uncovered: list[tuple[FileRecord, list[str]]] = []
    for record in records:
        matches = find_matching_tests(record, test_records)
        if matches:
            continue
        uncovered.append((record, matches))

    if not uncovered:
        return None

    evidence = [
        make_evidence(
            record.relative_path,
            first_definition_line(record),
            f"정의 {len(record.definitions)}개, 연관 테스트 파일 {len(matches)}개",
        )
        for record, matches in uncovered
    ]
    test_file_count = len(test_records)
    summary = (
        f"{area} 영역의 핵심 소스 파일 {len(uncovered)}개가 테스트 파일과 연결되지 않는다 "
        f"(저장소 테스트 파일 수: {test_file_count})."
    )
    return {
        "finding_id": finding_id,
        "category": "missing_tests",
        "severity": severity,
        "area": area,
        "title": title,
        "summary": summary,
        "rationale": rationale,
        "scenario": scenario,
        "evidence": evidence,
    }


def build_coverage_gap_finding(index: dict[str, Any]) -> dict[str, Any] | None:
    makefile = index["by_path"].get("Makefile")
    normalizer = index["by_path"].get("normalize_quality_signals.py")
    if makefile is None or normalizer is None:
        return None

    coverage_line = find_line_number(normalizer, "LINES_COVERAGE_PATTERN")
    parse_coverage_line = find_line_number(normalizer, "def parse_coverage")
    has_coverage_command = bool(re.search(r"(^|[^A-Za-z_])(coverage|--cov)([^A-Za-z_]|$)", makefile.content))
    if has_coverage_command:
        return None

    test_line = find_line_number(makefile, "test: test-installers")
    summary = "커버리지 파싱 로직은 있지만 저장소 검증 경로가 실제 커버리지를 생산하지 않아 분기 누락을 수치로 감시하지 못한다."
    return {
        "finding_id": "coverage-gap-no-producer",
        "category": "coverage_gap",
        "severity": "high",
        "area": "루트 도구/자동화",
        "title": "커버리지 신호 생산 경로 부재",
        "summary": summary,
        "rationale": "정규화기는 coverage 필드를 처리하지만 실제 `make test`/`make check` 흐름에는 coverage 실행이나 최소 기준이 없다.",
        "scenario": (
            "coverage 파서나 우선순위 로직이 깨져도 현재 검증은 스모크 출력만 확인한다. "
            "라인/브랜치 커버리지 하락이나 특정 분기 미실행은 다음 개선 루프에 신호로 남지 않는다."
        ),
        "evidence": [
            make_evidence("normalize_quality_signals.py", coverage_line, "coverage 정규화 패턴 정의"),
            make_evidence("normalize_quality_signals.py", parse_coverage_line, "coverage 입력을 실제 요약 필드로 변환"),
            make_evidence("Makefile", test_line, "기본 test 엔트리포인트에 coverage 실행이 없음"),
        ],
    }


def build_flaky_risk_finding(index: dict[str, Any]) -> dict[str, Any] | None:
    makefile = index["by_path"].get("Makefile")
    if makefile is None:
        return None

    skip_lines = [
        line_number
        for line_number, line in enumerate(makefile.lines, start=1)
        if "skip:" in line
    ]
    if not skip_lines:
        return None

    summary = (
        f"검증 엔트리포인트가 최소 {len(skip_lines)}개 조건부 skip 분기를 가진다. "
        "호스트 도구 유무에 따라 같은 커밋의 검증 강도가 달라져 환경 의존 flaky 가능성이 남는다."
    )
    return {
        "finding_id": "flaky-risk-skip-guards",
        "category": "flaky_risk",
        "severity": "medium",
        "area": "검증 엔트리포인트",
        "title": "환경 의존 skip 분기 때문에 검증 강도가 흔들림",
        "summary": summary,
        "rationale": "lint/test 단계가 도구 부재를 실패가 아니라 skip 으로 처리하므로, 개발기와 CI 또는 OS 조합마다 실제 검증 범위가 달라질 수 있다.",
        "scenario": (
            "`markdownlint`, `shellcheck`, `pwsh`, `python3`, `git` 가 없는 환경에서는 같은 `make check` 가 더 적은 검사를 통과로 처리한다. "
            "특정 플랫폼에서만 드러나는 회귀가 다른 환경에서는 재현되지 않아 flaky 처럼 보일 수 있다."
        ),
        "evidence": [
            make_evidence("Makefile", skip_lines[0], "도구 부재 시 검사를 skip 처리"),
            make_evidence("Makefile", skip_lines[-1], "테스트 타깃에서도 동일한 skip 패턴 반복"),
        ],
    }


def build_installer_verification_gap(index: dict[str, Any]) -> dict[str, Any] | None:
    makefile = index["by_path"].get("Makefile")
    installer_sh = index["by_path"].get("installer/CodexMultiAgent.sh")
    installer_ps1 = index["by_path"].get("installer/CodexMultiAgent.ps1")
    bootstrap_sh = index["by_path"].get("installer/Bootstrap.sh")
    bootstrap_ps1 = index["by_path"].get("installer/Bootstrap.ps1")
    if makefile is None or installer_sh is None or installer_ps1 is None:
        return None

    help_line = find_line_number(makefile, "bash installer/CodexMultiAgent.sh --help >/dev/null")
    if help_line is None:
        return None

    summary = (
        "설치기 검증이 Bash help 스모크 한 줄에 치우쳐 있다. "
        "실제 작업공간 적용, PowerShell 경로, bootstrap 다운로드/적용 흐름은 완료 게이트에 들어오지 않는다."
    )
    evidence = [
        make_evidence("Makefile", help_line, "설치기 검증이 Bash `--help` 호출 한 줄로 끝남"),
        make_evidence(
            "installer/CodexMultiAgent.sh",
            first_definition_line(installer_sh),
            f"실제 설치/상태 생성 함수 {len(installer_sh.definitions)}개",
        ),
        make_evidence(
            "installer/CodexMultiAgent.ps1",
            first_definition_line(installer_ps1),
            f"실제 설치/상태 생성 함수 {len(installer_ps1.definitions)}개",
        ),
    ]
    if bootstrap_sh is not None:
        evidence.append(
            make_evidence(
                "installer/Bootstrap.sh",
                1,
                "별도 bootstrap 진입점 존재하지만 기본 test 경로에서 실행되지 않음",
            )
        )
    if bootstrap_ps1 is not None:
        evidence.append(
            make_evidence(
                "installer/Bootstrap.ps1",
                1,
                "별도 PowerShell bootstrap 진입점 존재하지만 기본 test 경로에서 실행되지 않음",
            )
        )
    return {
        "finding_id": "verification-gap-installer-paths",
        "category": "verification_gap",
        "severity": "high",
        "area": "설치기와 작업공간 스캐폴딩",
        "title": "설치기 핵심 경로 검증 누락",
        "summary": summary,
        "rationale": "프로젝트 목표상 복구 가능한 작업 단위와 상태 생성이 핵심인데, 이를 담당하는 설치기 주요 경로가 회귀 테스트 없이 비어 있다.",
        "scenario": (
            "작업공간 오버라이드 생성, `STATE.md`/`AGENTS.md` 렌더링, PowerShell 경로 수정이 깨져도 "
            "현재 기본 검증은 Bash help 출력만 통과하면 녹색으로 끝난다."
        ),
        "evidence": evidence,
    }


def build_goal_cycle_gap(index: dict[str, Any]) -> dict[str, Any] | None:
    makefile = index["by_path"].get("Makefile")
    goal_doc = index["by_path"].get("docs/GOAL_COMPARISON_AREAS.md")
    if makefile is None or goal_doc is None:
        return None

    goal_line = find_line_number(goal_doc, "저장소가 자기 부족한 코드 품질과 기능 공백을 스스로 찾고")
    test_line = find_line_number(makefile, "test: test-installers")
    summary = (
        "프로젝트 목표는 탐지 -> 제안 -> 구현 -> 검증의 재귀 루프를 요구하지만, "
        "현재 검증은 개별 도구 스모크만 확인하고 루프 전체를 묶는 통합 시나리오가 없다."
    )
    return {
        "finding_id": "verification-gap-goal-cycle",
        "category": "verification_gap",
        "severity": "medium",
        "area": "프로젝트 목표 루프",
        "title": "자가개선 루프 통합 검증 부재",
        "summary": summary,
        "rationale": "목표 문서는 완료 판정을 목표 부합과 검증 통과에 묶는데, 실제 `make test` 는 각 보조 스크립트가 혼자 실행되는지만 본다.",
        "scenario": (
            "갭 탐지 결과가 후보 제안 또는 다음 검증 단계와 끊겨도 개별 스크립트 스모크만 통과하면 놓친다. "
            "프로젝트 방향성 안에서의 재귀 개선이 실제로 이어지는지 확인하는 E2E 시나리오가 없다."
        ),
        "evidence": [
            make_evidence("docs/GOAL_COMPARISON_AREAS.md", goal_line, "프로젝트 목표가 재귀적 자가개선 루프를 요구"),
            make_evidence("Makefile", test_line, "기본 test 엔트리포인트는 개별 스모크 타깃 집합"),
        ],
    }


def build_findings(index: dict[str, Any]) -> list[dict[str, Any]]:
    test_records = index["test_records"]
    source_records = index["source_records"]

    installer_records = [
        record
        for record in source_records
        if record.relative_path in {"installer/CodexMultiAgent.sh", "installer/CodexMultiAgent.ps1"}
    ]
    python_tool_records = [
        record
        for record in source_records
        if record.relative_path
        in {"normalize_quality_signals.py", "collect_repo_metrics.py", "extract_feature_gap_candidates.py"}
    ]

    findings = [
        build_missing_module_test_finding(
            title="설치기 핵심 소스 테스트 부재",
            area="설치기와 작업공간 스캐폴딩",
            severity="high",
            records=installer_records,
            test_records=test_records,
            scenario=(
                "설치기 상태 생성이나 config patch 로직이 깨져도 현재 기본 검증은 Bash help 출력만 보므로 "
                "실사용 회귀를 막지 못한다."
            ),
            rationale="설치기는 전역/작업공간 상태 생성의 핵심인데, 관련 테스트 파일이나 호출형 검증이 저장소에 없다.",
            finding_id="missing-tests-installer-core",
        ),
        build_missing_module_test_finding(
            title="핵심 Python 분석기 테스트 부재",
            area="루트 도구/자동화",
            severity="high",
            records=python_tool_records,
            test_records=test_records,
            scenario=(
                "정규화, 메트릭 수집, 기능 공백 추출기의 분기 하나가 깨져도 지금은 CLI 스모크와 일부 샘플 assert 에만 걸린다. "
                "함수 단위 회귀나 경계값 케이스를 직접 방어하지 못한다."
            ),
            rationale="프로젝트 목표상 자가 탐지와 우선순위 판단을 담당하는 핵심 Python 도구들이 전용 테스트 파일 없이 운영된다.",
            finding_id="missing-tests-python-analysis-tools",
        ),
        build_coverage_gap_finding(index),
        build_flaky_risk_finding(index),
        build_installer_verification_gap(index),
        build_goal_cycle_gap(index),
    ]
    return [finding for finding in findings if finding is not None]


def render_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Test Gap Areas",
        "",
        "이 문서는 저장소의 테스트 부재, 커버리지 공백, flaky 가능성, 검증 누락 영역을 근거 파일과 시나리오 기준으로 정리한다.",
        "모든 항목은 현재 저장소 목표인 자가 탐지 -> 제안 -> 구현 -> 검증 루프에 직접 연결되는 것만 남긴다.",
        "",
        f"- schema_version: `{payload['schema_version']}`",
        f"- scanned_file_count: `{payload['scanned_file_count']}`",
        f"- source_file_count: `{payload['source_file_count']}`",
        f"- test_file_count: `{payload['test_file_count']}`",
        f"- finding_count: `{payload['finding_count']}`",
        "",
        "## Findings",
        "",
    ]

    for finding in payload["findings"]:
        lines.append(f"### {finding['title']}")
        lines.append("")
        lines.append(f"- category: `{finding['category']}` / severity `{finding['severity']}`")
        lines.append(f"- area: `{finding['area']}`")
        lines.append(f"- 요약: {finding['summary']}")
        lines.append(f"- 근거 판단: {finding['rationale']}")
        lines.append(f"- 시나리오: {finding['scenario']}")
        lines.append("- 근거:")
        for entry in finding["evidence"]:
            lines.append(f"  - `{format_evidence_ref(entry)}` :: {entry['summary']}")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def build_payload(root: Path) -> dict[str, Any]:
    index = build_repo_index(root)
    findings = build_findings(index)
    return {
        "schema_version": SCHEMA_VERSION,
        "root": str(root),
        "scanned_file_count": len(index["records"]),
        "source_file_count": len(index["source_records"]),
        "test_file_count": len(index["test_records"]),
        "finding_count": len(findings),
        "findings": findings,
    }


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    payload = build_payload(root)
    if args.format == "markdown":
        print(render_markdown(payload), end="")
        return 0

    if args.pretty:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
