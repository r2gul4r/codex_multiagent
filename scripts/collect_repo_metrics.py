#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


SCHEMA_VERSION = 1
MIN_DUPLICATE_BLOCK_LINES = 3
MIN_DUPLICATE_TOKEN_COUNT = 6
DEFAULT_EXCLUDED_DIRS = {
    ".git",
    ".codex",
    "__pycache__",
    ".pytest_cache",
}

LANGUAGE_BY_NAME = {
    "makefile": "makefile",
}

LANGUAGE_BY_SUFFIX = {
    ".md": "markdown",
    ".py": "python",
    ".ps1": "powershell",
    ".rules": "rules",
    ".sh": "shell",
    ".toml": "toml",
    ".txt": "text",
    ".yaml": "yaml",
    ".yml": "yaml",
}

COMMENT_PREFIXES = {
    "makefile": ("#",),
    "powershell": ("#",),
    "python": ("#",),
    "rules": ("#",),
    "shell": ("#",),
    "text": (),
    "toml": ("#",),
    "yaml": ("#",),
}

DECISION_TOKENS = {
    "powershell": ("if", "elseif", "switch", "for", "foreach", "while", "catch", "and", "or"),
    "python": ("if", "elif", "for", "while", "except", "case", "match", "and", "or"),
    "shell": ("if", "elif", "for", "while", "case", "&&", "||"),
}


@dataclass(frozen=True)
class FileMetrics:
    path: str
    language: str
    bytes_size: int
    total_lines: int
    blank_lines: int
    comment_lines: int
    code_lines: int
    max_line_length: int
    function_like_blocks: int
    class_like_blocks: int
    decision_points: int
    cyclomatic_estimate: int
    max_indent_level: int
    duplication_group_count: int = 0
    duplicated_line_instances: int = 0
    max_duplicate_block_lines: int = 0
    git_history: "GitHistoryMetrics" = field(default_factory=lambda: GitHistoryMetrics())

    def to_dict(self) -> dict[str, object]:
        return {
            "path": self.path,
            "language": self.language,
            "module_size": {
                "bytes": self.bytes_size,
                "total_lines": self.total_lines,
                "blank_lines": self.blank_lines,
                "comment_lines": self.comment_lines,
                "code_lines": self.code_lines,
                "max_line_length": self.max_line_length,
            },
            "complexity": {
                "function_like_blocks": self.function_like_blocks,
                "class_like_blocks": self.class_like_blocks,
                "decision_points": self.decision_points,
                "cyclomatic_estimate": self.cyclomatic_estimate,
                "max_indent_level": self.max_indent_level,
            },
            "duplication": {
                "group_count": self.duplication_group_count,
                "duplicated_line_instances": self.duplicated_line_instances,
                "max_duplicate_block_lines": self.max_duplicate_block_lines,
            },
            "change_frequency": self.git_history.to_dict(),
        }


@dataclass(frozen=True)
class GitHistoryMetrics:
    commit_count: int = 0
    author_count: int = 0
    first_commit_at: str | None = None
    last_commit_at: str | None = None
    active_days: int = 0
    commits_per_30_days: float = 0.0

    def to_dict(self) -> dict[str, object]:
        return {
            "commit_count": self.commit_count,
            "author_count": self.author_count,
            "first_commit_at": self.first_commit_at,
            "last_commit_at": self.last_commit_at,
            "active_days": self.active_days,
            "commits_per_30_days": self.commits_per_30_days,
        }


@dataclass(frozen=True)
class NormalizedCodeLine:
    normalized: str
    original_line: int


@dataclass(frozen=True)
class DuplicateOccurrence:
    path: str
    start_index: int
    line_count: int
    start_line: int
    end_line: int


@dataclass(frozen=True)
class DuplicateGroup:
    fingerprint: str
    normalized_line_count: int
    token_count: int
    occurrences: tuple[DuplicateOccurrence, ...]
    excerpt_lines: tuple[str, ...]

    def to_dict(self) -> dict[str, object]:
        return {
            "fingerprint": self.fingerprint,
            "normalized_line_count": self.normalized_line_count,
            "token_count": self.token_count,
            "occurrence_count": len(self.occurrences),
            "modules": [
                {
                    "path": item.path,
                    "start_line": item.start_line,
                    "end_line": item.end_line,
                }
                for item in self.occurrences
            ],
            "excerpt": list(self.excerpt_lines),
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect per-file module size and lightweight complexity metrics for the repository."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root to scan when --paths is omitted. Defaults to the current directory.",
    )
    parser.add_argument(
        "--paths",
        nargs="+",
        help="Optional explicit file or directory paths to scan relative to --root.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    parser.add_argument(
        "--min-duplicate-lines",
        type=int,
        default=MIN_DUPLICATE_BLOCK_LINES,
        help=(
            "Minimum normalized code-line span used to form duplication groups. "
            f"Defaults to {MIN_DUPLICATE_BLOCK_LINES}."
        ),
    )
    return parser.parse_args()


def utc_timestamp() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def infer_language(path: Path) -> str:
    lower_name = path.name.lower()
    if lower_name in LANGUAGE_BY_NAME:
        return LANGUAGE_BY_NAME[lower_name]
    return LANGUAGE_BY_SUFFIX.get(path.suffix.lower(), "text")


def is_block_comment_start(language: str, line: str) -> bool:
    stripped = line.strip()
    if language == "markdown":
        return stripped.startswith("<!--")
    return False


def is_block_comment_end(language: str, line: str) -> bool:
    stripped = line.strip()
    if language == "markdown":
        return "-->" in stripped
    return False


def is_comment_line(language: str, line: str, in_block_comment: bool) -> tuple[bool, bool]:
    stripped = line.strip()
    if not stripped:
        return False, in_block_comment

    if in_block_comment:
        return True, not is_block_comment_end(language, line)

    if is_block_comment_start(language, line):
        return True, not is_block_comment_end(language, line)

    prefixes = COMMENT_PREFIXES.get(language, ())
    return stripped.startswith(prefixes), False


def count_decision_points(language: str, line: str) -> int:
    stripped = line.strip()
    if not stripped:
        return 0

    tokens = DECISION_TOKENS.get(language)
    if not tokens:
        return 0

    total = 0
    for token in tokens:
        if token in {"&&", "||"}:
            total += stripped.count(token)
            continue
        padded = f" {stripped} "
        total += padded.count(f" {token} ")
    return total


def count_function_like_blocks(language: str, line: str) -> int:
    stripped = line.strip()
    if not stripped:
        return 0

    if language == "python":
        return 1 if stripped.startswith("def ") else 0
    if language == "shell":
        if stripped.startswith("function "):
            return 1
        if stripped.endswith("() {"):
            return 1
        return 0
    if language == "powershell":
        return 1 if stripped.startswith("function ") else 0
    return 0


def count_class_like_blocks(language: str, line: str) -> int:
    stripped = line.strip()
    if language == "python":
        return 1 if stripped.startswith("class ") else 0
    return 0


def compute_indent_level(line: str) -> int:
    expanded = line.expandtabs(4)
    leading = len(expanded) - len(expanded.lstrip(" "))
    if leading == 0:
        return 0
    return leading // 4


def normalize_code_line(language: str, line: str) -> str:
    expanded = line.expandtabs(4).strip()
    if not expanded:
        return ""
    if language == "python":
        return re.sub(r"\s+", " ", expanded)
    if language in {"shell", "powershell", "makefile", "toml", "yaml", "rules", "markdown", "text"}:
        return re.sub(r"\s+", " ", expanded)
    return re.sub(r"\s+", " ", expanded)


def collect_normalized_code_lines(language: str, lines: list[str]) -> list[NormalizedCodeLine]:
    normalized_lines: list[NormalizedCodeLine] = []
    in_block_comment = False

    for index, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped:
            continue
        is_comment, in_block_comment = is_comment_line(language, line, in_block_comment)
        if is_comment:
            continue
        normalized = normalize_code_line(language, line)
        if normalized:
            normalized_lines.append(NormalizedCodeLine(normalized=normalized, original_line=index))

    return normalized_lines


def iter_files(root: Path, explicit_paths: list[str] | None) -> Iterable[Path]:
    seen: set[Path] = set()
    if explicit_paths:
        sources = [root / entry for entry in explicit_paths]
    else:
        sources = [root]

    for source in sources:
        if not source.exists():
            raise FileNotFoundError(f"Path does not exist: {source}")

        if source.is_file():
            resolved = source.resolve()
            if resolved not in seen:
                seen.add(resolved)
                yield resolved
            continue

        for path in sorted(source.rglob("*")):
            if path.is_dir():
                continue
            if any(part in DEFAULT_EXCLUDED_DIRS for part in path.relative_to(source).parts):
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            yield resolved


def analyze_file(root: Path, path: Path) -> FileMetrics:
    language = infer_language(path)
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    blank_lines = 0
    comment_lines = 0
    function_like_blocks = 0
    class_like_blocks = 0
    decision_points = 0
    max_line_length = 0
    max_indent_level = 0
    in_block_comment = False

    for line in lines:
        max_line_length = max(max_line_length, len(line))
        stripped = line.strip()
        if not stripped:
            blank_lines += 1
            continue

        is_comment, in_block_comment = is_comment_line(language, line, in_block_comment)
        if is_comment:
            comment_lines += 1
            continue

        function_like_blocks += count_function_like_blocks(language, line)
        class_like_blocks += count_class_like_blocks(language, line)
        decision_points += count_decision_points(language, line)
        max_indent_level = max(max_indent_level, compute_indent_level(line))

    total_lines = len(lines)
    code_lines = max(total_lines - blank_lines - comment_lines, 0)
    relative_path = path.relative_to(root.resolve()).as_posix()

    return FileMetrics(
        path=relative_path,
        language=language,
        bytes_size=path.stat().st_size,
        total_lines=total_lines,
        blank_lines=blank_lines,
        comment_lines=comment_lines,
        code_lines=code_lines,
        max_line_length=max_line_length,
        function_like_blocks=function_like_blocks,
        class_like_blocks=class_like_blocks,
        decision_points=decision_points,
        cyclomatic_estimate=max(1, decision_points + 1),
        max_indent_level=max_indent_level,
    )


def resolve_git_root(root: Path) -> Path | None:
    try:
        completed = subprocess.run(
            ["git", "-C", root.as_posix(), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None

    output = completed.stdout.strip()
    if not output:
        return None
    return Path(output).resolve()


def format_git_timestamp(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def collect_git_history_for_path(git_root: Path, target: Path) -> GitHistoryMetrics:
    try:
        relative_path = target.resolve().relative_to(git_root).as_posix()
    except ValueError:
        return GitHistoryMetrics()

    try:
        completed = subprocess.run(
            [
                "git",
                "-C",
                git_root.as_posix(),
                "log",
                "--follow",
                "--format=%H%x1f%aI%x1f%an",
                "--",
                relative_path,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return GitHistoryMetrics()

    lines = [line for line in completed.stdout.splitlines() if line.strip()]
    if not lines:
        return GitHistoryMetrics()

    commits: list[tuple[str, datetime, str]] = []
    for line in lines:
        commit_hash, authored_at, author_name = line.split("\x1f", maxsplit=2)
        commits.append((commit_hash, datetime.fromisoformat(authored_at), author_name))

    commit_count = len(commits)
    author_count = len({author_name for _, _, author_name in commits})
    first_commit_at = commits[-1][1]
    last_commit_at = commits[0][1]
    span_seconds = max((last_commit_at - first_commit_at).total_seconds(), 0.0)
    active_days = int(span_seconds // 86400)
    commits_per_30_days = round(commit_count * 30 / max(active_days, 1), 2)
    return GitHistoryMetrics(
        commit_count=commit_count,
        author_count=author_count,
        first_commit_at=format_git_timestamp(first_commit_at),
        last_commit_at=format_git_timestamp(last_commit_at),
        active_days=active_days,
        commits_per_30_days=commits_per_30_days,
    )


def apply_git_history_metrics(root: Path, metrics: list[FileMetrics]) -> list[FileMetrics]:
    git_root = resolve_git_root(root)
    if git_root is None:
        return metrics

    per_path = {
        item.path: collect_git_history_for_path(git_root, root / item.path)
        for item in metrics
    }

    return [
        FileMetrics(
            path=item.path,
            language=item.language,
            bytes_size=item.bytes_size,
            total_lines=item.total_lines,
            blank_lines=item.blank_lines,
            comment_lines=item.comment_lines,
            code_lines=item.code_lines,
            max_line_length=item.max_line_length,
            function_like_blocks=item.function_like_blocks,
            class_like_blocks=item.class_like_blocks,
            decision_points=item.decision_points,
            cyclomatic_estimate=item.cyclomatic_estimate,
            max_indent_level=item.max_indent_level,
            duplication_group_count=item.duplication_group_count,
            duplicated_line_instances=item.duplicated_line_instances,
            max_duplicate_block_lines=item.max_duplicate_block_lines,
            git_history=per_path[item.path],
        )
        for item in metrics
    ]


def extend_duplicate_block(
    path_to_lines: dict[str, list[NormalizedCodeLine]],
    occurrences: list[tuple[str, int]],
    seed_length: int,
) -> tuple[int, int]:
    backward = 0
    while True:
        candidate_lines: set[str] = set()
        for path, start_index in occurrences:
            next_index = start_index - backward - 1
            if next_index < 0:
                candidate_lines = set()
                break
            candidate_lines.add(path_to_lines[path][next_index].normalized)
        if len(candidate_lines) != 1:
            break
        backward += 1

    forward = 0
    while True:
        candidate_lines = set()
        for path, start_index in occurrences:
            next_index = start_index + seed_length + forward
            if next_index >= len(path_to_lines[path]):
                candidate_lines = set()
                break
            candidate_lines.add(path_to_lines[path][next_index].normalized)
        if len(candidate_lines) != 1:
            break
        forward += 1

    return backward, seed_length + forward


def build_duplicate_group(
    path_to_lines: dict[str, list[NormalizedCodeLine]],
    occurrences: list[tuple[str, int]],
    backward: int,
    length: int,
) -> DuplicateGroup:
    normalized_sequence = [
        path_to_lines[occurrences[0][0]][occurrences[0][1] - backward + offset].normalized
        for offset in range(length)
    ]
    sequence_text = "\n".join(normalized_sequence)
    fingerprint = hashlib.sha1(sequence_text.encode("utf-8")).hexdigest()[:12]
    excerpt_lines = tuple(normalized_sequence[: min(3, len(normalized_sequence))])
    duplicate_occurrences: list[DuplicateOccurrence] = []

    for path, start_index in sorted(set(occurrences)):
        first = path_to_lines[path][start_index - backward]
        last = path_to_lines[path][start_index - backward + length - 1]
        duplicate_occurrences.append(
            DuplicateOccurrence(
                path=path,
                start_index=start_index - backward,
                line_count=length,
                start_line=first.original_line,
                end_line=last.original_line,
            )
        )

    token_count = sum(len(line.split()) for line in normalized_sequence)
    return DuplicateGroup(
        fingerprint=fingerprint,
        normalized_line_count=length,
        token_count=token_count,
        occurrences=tuple(duplicate_occurrences),
        excerpt_lines=excerpt_lines,
    )


def group_is_subsumed(candidate: DuplicateGroup, selected: DuplicateGroup) -> bool:
    if len(candidate.occurrences) != len(selected.occurrences):
        return False
    for candidate_occurrence, selected_occurrence in zip(candidate.occurrences, selected.occurrences):
        if candidate_occurrence.path != selected_occurrence.path:
            return False
        if candidate_occurrence.start_line < selected_occurrence.start_line:
            return False
        if candidate_occurrence.end_line > selected_occurrence.end_line:
            return False
    return True


def collect_duplicate_groups(metrics: list[FileMetrics], root: Path, min_duplicate_lines: int) -> list[DuplicateGroup]:
    if min_duplicate_lines < 2:
        raise ValueError("--min-duplicate-lines must be at least 2")

    path_to_lines: dict[str, list[NormalizedCodeLine]] = {}
    for item in metrics:
        path = root / item.path
        lines = path.read_text(encoding="utf-8").splitlines()
        path_to_lines[item.path] = collect_normalized_code_lines(item.language, lines)

    windows: dict[tuple[str, ...], list[tuple[str, int]]] = {}
    for path, normalized_lines in path_to_lines.items():
        if len(normalized_lines) < min_duplicate_lines:
            continue
        for start_index in range(len(normalized_lines) - min_duplicate_lines + 1):
            window = tuple(
                normalized_lines[start_index + offset].normalized for offset in range(min_duplicate_lines)
            )
            windows.setdefault(window, []).append((path, start_index))

    groups: list[DuplicateGroup] = []
    seen_signatures: set[tuple[tuple[str, int, int], ...]] = set()
    for occurrences in windows.values():
        unique_occurrences = sorted(set(occurrences))
        if len(unique_occurrences) < 2:
            continue
        backward, length = extend_duplicate_block(path_to_lines, unique_occurrences, min_duplicate_lines)
        group = build_duplicate_group(path_to_lines, unique_occurrences, backward, length)
        if group.token_count < MIN_DUPLICATE_TOKEN_COUNT:
            continue
        signature = tuple(
            (item.path, item.start_line, item.end_line) for item in group.occurrences
        )
        if signature in seen_signatures:
            continue
        seen_signatures.add(signature)
        groups.append(group)

    groups.sort(
        key=lambda item: (
            -item.normalized_line_count,
            -len(item.occurrences),
            -item.token_count,
            item.fingerprint,
        )
    )
    filtered_groups: list[DuplicateGroup] = []
    for group in groups:
        if any(group_is_subsumed(group, existing) for existing in filtered_groups):
            continue
        filtered_groups.append(group)
    return filtered_groups


def apply_duplication_metrics(metrics: list[FileMetrics], groups: list[DuplicateGroup]) -> list[FileMetrics]:
    per_path = {
        item.path: {
            "group_count": 0,
            "duplicated_line_instances": 0,
            "max_duplicate_block_lines": 0,
        }
        for item in metrics
    }

    for group in groups:
        for occurrence in group.occurrences:
            stats = per_path[occurrence.path]
            stats["group_count"] += 1
            stats["duplicated_line_instances"] += group.normalized_line_count
            stats["max_duplicate_block_lines"] = max(
                stats["max_duplicate_block_lines"],
                group.normalized_line_count,
            )

    return [
        FileMetrics(
            path=item.path,
            language=item.language,
            bytes_size=item.bytes_size,
            total_lines=item.total_lines,
            blank_lines=item.blank_lines,
            comment_lines=item.comment_lines,
            code_lines=item.code_lines,
            max_line_length=item.max_line_length,
            function_like_blocks=item.function_like_blocks,
            class_like_blocks=item.class_like_blocks,
            decision_points=item.decision_points,
            cyclomatic_estimate=item.cyclomatic_estimate,
            max_indent_level=item.max_indent_level,
            duplication_group_count=per_path[item.path]["group_count"],
            duplicated_line_instances=per_path[item.path]["duplicated_line_instances"],
            max_duplicate_block_lines=per_path[item.path]["max_duplicate_block_lines"],
        )
        for item in metrics
    ]


def build_summary(metrics: list[FileMetrics]) -> dict[str, object]:
    totals = {
        "bytes": 0,
        "total_lines": 0,
        "blank_lines": 0,
        "comment_lines": 0,
        "code_lines": 0,
        "function_like_blocks": 0,
        "class_like_blocks": 0,
        "decision_points": 0,
        "cyclomatic_estimate": 0,
        "duplicated_line_instances": 0,
    }
    languages: dict[str, int] = {}
    files_with_duplicates = 0
    max_duplicate_block_lines = 0
    files_with_history = 0
    max_commit_count = 0

    for item in metrics:
        totals["bytes"] += item.bytes_size
        totals["total_lines"] += item.total_lines
        totals["blank_lines"] += item.blank_lines
        totals["comment_lines"] += item.comment_lines
        totals["code_lines"] += item.code_lines
        totals["function_like_blocks"] += item.function_like_blocks
        totals["class_like_blocks"] += item.class_like_blocks
        totals["decision_points"] += item.decision_points
        totals["cyclomatic_estimate"] += item.cyclomatic_estimate
        totals["duplicated_line_instances"] += item.duplicated_line_instances
        languages[item.language] = languages.get(item.language, 0) + 1
        if item.duplication_group_count > 0:
            files_with_duplicates += 1
            max_duplicate_block_lines = max(
                max_duplicate_block_lines,
                item.max_duplicate_block_lines,
            )
        if item.git_history.commit_count > 0:
            files_with_history += 1
            max_commit_count = max(max_commit_count, item.git_history.commit_count)

    sorted_languages = dict(sorted(languages.items(), key=lambda item: item[0]))
    hotspots = [
        {
            "path": item.path,
            "commit_count": item.git_history.commit_count,
            "last_commit_at": item.git_history.last_commit_at,
            "commits_per_30_days": item.git_history.commits_per_30_days,
        }
        for item in sorted(
            (entry for entry in metrics if entry.git_history.commit_count > 0),
            key=lambda entry: (
                -entry.git_history.commit_count,
                -entry.git_history.commits_per_30_days,
                entry.path,
            ),
        )[:5]
    ]
    return {
        "file_count": len(metrics),
        "languages": sorted_languages,
        "totals": totals,
        "duplication": {
            "files_with_duplicates": files_with_duplicates,
            "max_duplicate_block_lines": max_duplicate_block_lines,
        },
        "change_frequency": {
            "files_with_history": files_with_history,
            "max_commit_count": max_commit_count,
            "hotspots": hotspots,
        },
    }


def build_payload(root: Path, metrics: list[FileMetrics], groups: list[DuplicateGroup], min_duplicate_lines: int) -> dict[str, object]:
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at": utc_timestamp(),
        "root": root.resolve().as_posix(),
        "summary": build_summary(metrics),
        "duplication": {
            "minimum_block_lines": min_duplicate_lines,
            "group_count": len(groups),
            "files_with_duplicates": sum(1 for item in metrics if item.duplication_group_count > 0),
            "groups": [group.to_dict() for group in groups],
        },
        "files": [item.to_dict() for item in metrics],
    }


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Root does not exist: {root}", file=sys.stderr)
        return 1

    try:
        metrics = [analyze_file(root, path) for path in iter_files(root, args.paths)]
        groups = collect_duplicate_groups(metrics, root, args.min_duplicate_lines)
        metrics = apply_duplication_metrics(metrics, groups)
        metrics = apply_git_history_metrics(root, metrics)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except UnicodeDecodeError as exc:
        print(f"Failed to read a file as UTF-8: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except subprocess.SubprocessError as exc:
        print(f"Failed to inspect git history: {exc}", file=sys.stderr)
        return 1

    metrics.sort(key=lambda item: item.path)
    payload = build_payload(root, metrics, groups, args.min_duplicate_lines)
    indent = 2 if args.pretty else None
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=indent)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
