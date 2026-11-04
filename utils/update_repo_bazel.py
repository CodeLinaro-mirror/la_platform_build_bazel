"""Updates ignore_directories in REPO.bazel using bazel mod show_repo --all_repos."""

import argparse
from collections.abc import Sequence
import difflib
import os
from pathlib import Path
import re
from re import Pattern
import subprocess
import sys

_IGNORE_DIRS_PATTERN = re.compile(
    r"ignore_directories\s*\(\s*\[.*?\]\s*\)", re.DOTALL
)
_REPO_BLOCK_SPLIT_PATTERN = re.compile(r"(?=^## @@)", re.MULTILINE)
_PATH_ATTR_PATTERN = re.compile(r'^\s*path\s*=\s*"([^"]+)"', re.MULTILINE)


def run_bazel_show_repo(workspace_root: Path) -> str:
    """Runs `bazel mod show_repo --all_repos` in workspace_root and returns stdout."""
    result = subprocess.run(
        ["bazel", "mod", "show_repo", "--all_repos"],
        cwd=workspace_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"bazel mod show_repo --all_repos failed (exit {result.returncode}):\n"
            f"{result.stderr.strip()}"
        )
    return result.stdout


def parse_local_repo_paths(
    show_repo_output: str, workspace_root: Path
) -> set[str]:
    """Extracts existing workspace subdirectory paths from show_repo output."""
    abs_root = os.path.abspath(workspace_root)
    paths: set[str] = set()

    for block in _REPO_BLOCK_SPLIT_PATTERN.split(show_repo_output):
        if not block.lstrip().startswith("## @@"):
            continue
        for raw_path in _PATH_ATTR_PATTERN.findall(block):
            raw_path = raw_path.strip()
            if not raw_path:
                continue
            if os.path.isabs(raw_path):
                abs_path = os.path.abspath(raw_path)
                rel = os.path.relpath(abs_path, abs_root)
            else:
                rel = os.path.normpath(raw_path)

            rel_posix = Path(rel).as_posix()
            if (
                not rel_posix or rel_posix in {".", ".."} or rel_posix.startswith("../")
            ):
                continue

            if (workspace_root / rel_posix).is_dir():
                paths.add(rel_posix)

    return paths


def load_extra_patterns(extra_ignore_file: Path) -> list[str]:
    """Reads extra ignore glob patterns from a file, allowing # line comments."""
    if not extra_ignore_file.is_file():
        raise FileNotFoundError(
            f"Extra ignore file '{extra_ignore_file}' does not exist."
        )
    patterns: list[str] = []
    for raw_line in extra_ignore_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip().rstrip("/")
        if line and line != ".":
            patterns.append(line)
    return patterns


def _glob_to_regex(pattern: str) -> Pattern[str]:
    """Converts a POSIX glob pattern (*, ?, [...], **) into a compiled regex."""
    i = 0
    n = len(pattern)
    res: list[str] = ["^"]
    while i < n:
        if pattern.startswith("/**/", i):
            res.append("(?:/.*/|/)")
            i += 4
        elif i == 0 and pattern.startswith("**/", i):
            res.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("/**", i) and i + 3 == n:
            res.append("(?:/.*)?")
            i += 3
        elif pattern.startswith("**", i):
            res.append(".*")
            i += 2
        elif pattern[i] == "*":
            res.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            res.append("[^/]")
            i += 1
        elif pattern[i] == "[":
            j = i + 1
            if j < n and pattern[j] in ("!", "^"):
                j += 1
            if j < n and pattern[j] == "]":
                j += 1
            while j < n and pattern[j] != "]":
                j += 1
            if j < n:
                stuff = pattern[i + 1 : j].replace("\\", "\\\\")
                if stuff.startswith("!"):
                    stuff = "^" + stuff[1:]
                elif stuff.startswith("^"):
                    stuff = "\\" + stuff
                res.append(f"[{stuff}]")
                i = j + 1
            else:
                res.append(r"\[")
                i += 1
        else:
            res.append(re.escape(pattern[i]))
            i += 1
    res.append("$")
    return re.compile("".join(res))


def is_covered_by_patterns(path: str, patterns: Sequence[str]) -> bool:
    """Returns True if path or any of its ancestor directories matches patterns."""
    if not patterns:
        return False
    compiled = [_glob_to_regex(p) for p in patterns]
    parts = path.split("/")
    prefixes = ["/".join(parts[:i]) for i in range(1, len(parts) + 1)]
    return any(regex.match(prefix) for regex in compiled for prefix in prefixes)


def shorten_paths(
    paths: set[str],
    extra_patterns: Sequence[str],
    workspace_root: Path,
) -> list[str]:
    """Filters covered paths, drops nested paths, and collapses sibling subdirs."""
    # 1. Exclude paths already covered by extra_patterns.
    filtered = [
        p
        for p in sorted(paths)
        if not is_covered_by_patterns(p, extra_patterns)
    ]

    # 2. If a path is nested in another path, only ignore the top-most one.
    top_paths: list[str] = []
    for p in filtered:
        if not any(p == top or p.startswith(top + "/") for top in top_paths):
            top_paths.append(p)

    # 3. If all subdirectories under an immediate parent path are ignored,
    # collapse them into <parent>/* (when there are at least 2 subdirectories).
    by_parent: dict[str, list[str]] = {}
    for p in top_paths:
        parent = os.path.dirname(p)
        by_parent.setdefault(parent, []).append(p)

    shortened: set[str] = set()
    for parent, group in by_parent.items():
        if not parent:
            shortened.update(group)
            continue
        parent_dir = workspace_root / parent
        if parent_dir.is_dir():
            disk_subdirs = {
                f"{parent}/{d.name}"
                for d in parent_dir.iterdir()
                if d.is_dir()
                and not d.name.startswith(".")
                and not d.name.startswith("bazel-")
            }
            if len(disk_subdirs) >= 2 and disk_subdirs.issubset(set(group)):
                shortened.add(f"{parent}/*")
                continue
        shortened.update(group)

    # 4. Include extra patterns unconditionally and sort.
    shortened.update(extra_patterns)
    return sorted(shortened)


def format_ignore_directories(ignored_dirs: Sequence[str]) -> str:
    """Formats the ignore_directories([...]) call block."""
    if not ignored_dirs:
        return "ignore_directories([])"
    lines = ["ignore_directories(["]
    for d in ignored_dirs:
        lines.append(f'    "{d}",')
    lines.append("])")
    return "\n".join(lines)


def update_repo_bazel_content(
    original_content: str, ignored_dirs: Sequence[str]
) -> str:
    """Updates or appends the ignore_directories([...]) call in-place."""
    new_block = format_ignore_directories(ignored_dirs)
    if _IGNORE_DIRS_PATTERN.search(original_content):
        return _IGNORE_DIRS_PATTERN.sub(
            lambda _: new_block, original_content, count=1
        )

    if not original_content:
        return new_block + "\n"
    if not original_content.endswith("\n"):
        return original_content + "\n\n" + new_block + "\n"
    if original_content.endswith("\n\n"):
        return original_content + new_block + "\n"
    return original_content + "\n" + new_block + "\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Update ignore_directories in REPO.bazel using "
            "`bazel mod show_repo --all_repos`."
        )
    )
    parser.add_argument(
        "--repo_file",
        required=True,
        help="Path to the REPO.bazel file to update or check.",
    )
    parser.add_argument(
        "--extra_ignore_file",
        default=None,
        help="Optional file containing extra ignored glob patterns.",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="Output unified diff and exit with 1 if the file needs updating.",
    )
    args = parser.parse_args(argv)

    working_dir = Path(os.environ.get("BUILD_WORKING_DIRECTORY") or Path.cwd())
    workspace_root = Path(
        os.environ.get("BUILD_WORKSPACE_DIRECTORY") or working_dir
    )

    repo_file = Path(args.repo_file)
    if not repo_file.is_absolute():
        repo_file = working_dir / repo_file

    extra_patterns: list[str] = []
    if args.extra_ignore_file:
        extra_file = Path(args.extra_ignore_file)
        if not extra_file.is_absolute():
            extra_file = working_dir / extra_file
        try:
            extra_patterns = load_extra_patterns(extra_file)
        except OSError as e:
            print(f"Error reading extra ignore file: {e}", file=sys.stderr)
            return 1

    try:
        show_repo_output = run_bazel_show_repo(workspace_root)
        discovered_paths = parse_local_repo_paths(
            show_repo_output, workspace_root
        )
        ignored_dirs = shorten_paths(
            discovered_paths, extra_patterns, workspace_root
        )
    except (RuntimeError, OSError) as e:
        print(f"Error discovering repositories: {e}", file=sys.stderr)
        return 1

    original_content = (
        repo_file.read_text(encoding="utf-8") if repo_file.is_file() else ""
    )
    updated_content = update_repo_bazel_content(original_content, ignored_dirs)

    if args.diff:
        if original_content != updated_content:
            display_path = args.repo_file
            diff = difflib.unified_diff(
                original_content.splitlines(keepends=True),
                updated_content.splitlines(keepends=True),
                fromfile=f"a/{display_path}",
                tofile=f"b/{display_path}",
            )
            sys.stdout.writelines(diff)
            print(f"Error: '{display_path}' is out of date.", file=sys.stderr)
            return 1
        return 0

    if original_content != updated_content or not repo_file.is_file():
        repo_file.parent.mkdir(parents=True, exist_ok=True)
        repo_file.write_text(updated_content, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
