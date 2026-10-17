#!/usr/bin/env python3
"""
Build a lightweight OKF knowledge graph from Markdown files under docs/.

The script:
- scans docs/**/*.md
- skips reserved files such as index.md and log.md as concept nodes
- parses YAML frontmatter when present
- extracts Markdown links between docs
- creates nodes for OKF concept documents
- creates edges for internal Markdown links
- writes a JSON graph to docs/knowledge-graph.json

No external dependencies required.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RESERVED_FILENAMES = {"index.md", "log.md"}

FRONTMATTER_RE = re.compile(
    r"^---\s*\n(?P<frontmatter>.*?)\n---\s*\n",
    re.DOTALL,
)

MARKDOWN_LINK_RE = re.compile(
    r"""
    (?<!!)\[([^\]]+)\]      # link text, but not image syntax ![]
    \(([^)]+)\)             # link target
    """,
    re.VERBOSE,
)


@dataclass
class Node:
    id: str
    path: str
    title: str
    type: str | None
    description: str | None
    tags: list[str]
    status: str | None
    source_kind: str | None
    timestamp: str | None
    reserved: bool


@dataclass
class Edge:
    source: str
    target: str
    label: str
    link_text: str
    source_path: str
    target_path: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a JSON knowledge graph from an OKF-light docs/ folder."
    )
    parser.add_argument(
        "--docs-dir",
        default="docs",
        help="Path to the docs directory. Default: docs",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output JSON path. Default: <docs-dir>/knowledge-graph.json",
    )
    parser.add_argument(
        "--include-reserved",
        action="store_true",
        help="Include index.md and log.md as graph nodes.",
    )
    return parser.parse_args()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def concept_id(path: Path, docs_dir: Path) -> str:
    """
    Convert docs/foo/bar.md to foo/bar.
    Convert docs/index.md to index.
    """
    relative = path.relative_to(docs_dir).as_posix()
    if relative.endswith(".md"):
        relative = relative[:-3]
    return relative


def extract_frontmatter_and_body(text: str) -> tuple[dict[str, Any], str]:
    """
    Minimal YAML-ish frontmatter parser.

    Supports:
    - key: value
    - key: [a, b, c]
    - key:
        - a
        - b

    This avoids requiring PyYAML. If your repo already uses PyYAML,
    you can replace this with yaml.safe_load.
    """
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}, text

    raw = match.group("frontmatter")
    body = text[match.end() :]

    data: dict[str, Any] = {}
    current_list_key: str | None = None

    for line in raw.splitlines():
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            continue

        if current_list_key and stripped.startswith("- "):
            data.setdefault(current_list_key, []).append(stripped[2:].strip())
            continue

        current_list_key = None

        if ":" not in line:
            continue

        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()

        if not key:
            continue

        if value == "":
            data[key] = []
            current_list_key = key
            continue

        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            if not inner:
                data[key] = []
            else:
                data[key] = [
                    item.strip().strip('"').strip("'")
                    for item in inner.split(",")
                    if item.strip()
                ]
            continue

        data[key] = value.strip('"').strip("'")

    return data, body


def extract_h1(body: str) -> str | None:
    for line in body.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return None


def normalize_tags(value: Any) -> list[str]:
    if value is None:
        return []

    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]

    if isinstance(value, str):
        if not value.strip():
            return []
        return [value.strip()]

    return []


def strip_anchor_and_query(target: str) -> str:
    target = target.split("#", 1)[0]
    target = target.split("?", 1)[0]
    return target


def is_external_link(target: str) -> bool:
    lowered = target.lower()
    return (
        lowered.startswith("http://")
        or lowered.startswith("https://")
        or lowered.startswith("mailto:")
        or lowered.startswith("tel:")
    )


def resolve_markdown_link(source_file: Path, docs_dir: Path, target: str) -> Path | None:
    """
    Resolve an internal Markdown link target to a docs-relative Markdown file.

    Supports:
    - ./foo.md
    - ../bar.md
    - /01-API/auth.md
    - folder/ without filename, resolved as folder/index.md
    """
    target = strip_anchor_and_query(target).strip()

    if not target or is_external_link(target):
        return None

    # Ignore non-markdown assets.
    if Path(target).suffix and Path(target).suffix.lower() != ".md":
        return None

    if target.startswith("/"):
        candidate = docs_dir / target.lstrip("/")
    else:
        candidate = source_file.parent / target

    if candidate.suffix == "":
        candidate = candidate / "index.md"

    try:
        return candidate.resolve()
    except OSError:
        return None


def extract_links(body: str) -> list[tuple[str, str]]:
    links: list[tuple[str, str]] = []

    for match in MARKDOWN_LINK_RE.finditer(body):
        link_text = match.group(1).strip()
        target = match.group(2).strip()

        # Remove optional title from links like: [x](file.md "title")
        if " " in target and not target.startswith("<"):
            target = target.split(" ", 1)[0]

        target = target.strip("<>")

        links.append((link_text, target))

    return links


def build_node(path: Path, docs_dir: Path, include_reserved: bool) -> Node | None:
    reserved = path.name in RESERVED_FILENAMES

    if reserved and not include_reserved:
        return None

    text = read_text(path)
    frontmatter, body = extract_frontmatter_and_body(text)

    fallback_title = extract_h1(body) or path.stem.replace("-", " ").replace("_", " ").title()

    return Node(
        id=concept_id(path, docs_dir),
        path=path.relative_to(docs_dir).as_posix(),
        title=str(frontmatter.get("title") or fallback_title),
        type=str(frontmatter["type"]) if frontmatter.get("type") else None,
        description=(
            str(frontmatter["description"])
            if frontmatter.get("description")
            else None
        ),
        tags=normalize_tags(frontmatter.get("tags")),
        status=str(frontmatter["status"]) if frontmatter.get("status") else None,
        source_kind=(
            str(frontmatter["source_kind"])
            if frontmatter.get("source_kind")
            else None
        ),
        timestamp=(
            str(frontmatter["timestamp"])
            if frontmatter.get("timestamp")
            else None
        ),
        reserved=reserved,
    )


def build_graph(
    docs_dir: Path,
    output_path: Path,
    include_reserved: bool = False,
) -> dict[str, Any]:
    docs_dir = docs_dir.resolve()
    output_path = output_path.resolve()

    markdown_files = sorted(docs_dir.rglob("*.md"))
    markdown_path_set = {path.resolve() for path in markdown_files}

    nodes: list[Node] = []
    node_by_resolved_path: dict[Path, Node] = {}

    for path in markdown_files:
        node = build_node(path, docs_dir, include_reserved)

        if node is None:
            continue

        resolved = path.resolve()
        nodes.append(node)
        node_by_resolved_path[resolved] = node

    edges: list[Edge] = []
    unresolved_links: list[dict[str, str]] = []

    for source_file in markdown_files:
        source_reserved = source_file.name in RESERVED_FILENAMES

        if source_reserved and not include_reserved:
            # Reserved files can be navigation files, but they are not concept nodes.
            # Skip them as edge sources unless explicitly included.
            continue

        source_node = node_by_resolved_path.get(source_file.resolve())
        if not source_node:
            continue

        text = read_text(source_file)
        _, body = extract_frontmatter_and_body(text)

        for link_text, raw_target in extract_links(body):
            resolved_target = resolve_markdown_link(source_file, docs_dir, raw_target)

            if resolved_target is None:
                continue

            target_node = node_by_resolved_path.get(resolved_target)

            if target_node is None:
                # Existing reserved files are valid navigation targets, not unresolved links.
                if resolved_target in markdown_path_set:
                    continue
                unresolved_links.append(
                    {
                        "source": source_node.id,
                        "source_path": source_node.path,
                        "link_text": link_text,
                        "target": raw_target,
                    }
                )
                continue

            edges.append(
                Edge(
                    source=source_node.id,
                    target=target_node.id,
                    label="links_to",
                    link_text=link_text,
                    source_path=source_node.path,
                    target_path=target_node.path,
                )
            )

    graph = {
        "schema": "okf-light-knowledge-graph-v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "docs_dir": docs_dir.as_posix(),
        "node_count": len(nodes),
        "edge_count": len(edges),
        "unresolved_link_count": len(unresolved_links),
        "nodes": [asdict(node) for node in nodes],
        "edges": [asdict(edge) for edge in edges],
        "unresolved_links": unresolved_links,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(graph, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    return graph


def main() -> None:
    args = parse_args()

    docs_dir = Path(args.docs_dir)

    if not docs_dir.exists():
        raise SystemExit(f"Docs directory does not exist: {docs_dir}")

    output_path = Path(args.output) if args.output else docs_dir / "knowledge-graph.json"

    graph = build_graph(
        docs_dir=docs_dir,
        output_path=output_path,
        include_reserved=args.include_reserved,
    )

    print(f"Generated: {output_path}")
    print(f"Nodes: {graph['node_count']}")
    print(f"Edges: {graph['edge_count']}")
    print(f"Unresolved links: {graph['unresolved_link_count']}")


if __name__ == "__main__":
    main()
