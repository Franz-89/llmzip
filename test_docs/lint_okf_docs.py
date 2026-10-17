#!/usr/bin/env python3
"""Validate OKF-light Markdown documents and local links under docs/."""

from pathlib import Path
import re
import sys
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
RECOMMENDED_FIELDS = (
    "type",
    "title",
    "description",
    "tags",
    "status",
    "source_kind",
    "timestamp",
)
RESERVED_NAMES = {"index.md", "log.md"}
LINK_PATTERN = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")


def parse_frontmatter(path: Path, content: str) -> tuple[dict[str, str], list[str]]:
    error_list: list[str] = []
    line_list = content.splitlines()
    if not line_list or line_list[0].strip() != "---":
        return {}, [f"{path.relative_to(ROOT)}: missing YAML frontmatter"]

    try:
        closing_index = line_list[1:].index("---") + 1
    except ValueError:
        return {}, [f"{path.relative_to(ROOT)}: unclosed YAML frontmatter"]

    field_map: dict[str, str] = {}
    for line in line_list[1:closing_index]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            error_list.append(
                f"{path.relative_to(ROOT)}: invalid frontmatter line: {line!r}"
            )
            continue
        key, value = line.split(":", 1)
        field_map[key.strip()] = value.strip()

    for field in RECOMMENDED_FIELDS:
        if not field_map.get(field):
            error_list.append(
                f"{path.relative_to(ROOT)}: missing or empty frontmatter field '{field}'"
            )

    return field_map, error_list


def check_links(path: Path, content: str) -> list[str]:
    error_list: list[str] = []
    for raw_target in LINK_PATTERN.findall(content):
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(("#", "/", "mailto:")):
            continue
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target):
            continue
        local_target = unquote(target.split("#", 1)[0].split("?", 1)[0])
        if local_target and not (path.parent / local_target).resolve().exists():
            error_list.append(
                f"{path.relative_to(ROOT)}: broken local link '{raw_target}'"
            )
    return error_list


def main() -> int:
    error_list: list[str] = []
    file_list = sorted(DOCS.rglob("*.md"))

    for path in file_list:
        content = path.read_text(encoding="utf-8")
        if path.name not in RESERVED_NAMES:
            _, frontmatter_error_list = parse_frontmatter(path, content)
            error_list.extend(frontmatter_error_list)
        error_list.extend(check_links(path, content))

    if error_list:
        print("OKF docs validation failed:")
        for error in error_list:
            print(f"- {error}")
        return 1

    normal_count = sum(path.name not in RESERVED_NAMES for path in file_list)
    print(
        f"OKF docs validation passed: {normal_count} concept documents, "
        f"{len(file_list) - normal_count} reserved navigation/history files."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
