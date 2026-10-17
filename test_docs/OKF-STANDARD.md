---
type: Reference
title: OKF-Light Documentation Standard
description: "Defines metadata, classification, navigation, history, and validation rules for the project knowledge bundle."
tags: [documentation, okf, knowledge-base]
status: active
source_kind: hand-written
timestamp: "2026-06-30T07:02:53Z"
---

# OKF-Light Documentation Standard

`/` is the project knowledge bundle. Start navigation at [index.md](index.md).

## Concept Documents

Every Markdown document except files named `index.md` or `log.md` starts with YAML frontmatter:

```yaml
---
type: Architecture Note
title: Example Architecture Note
description: "One-sentence summary of the document."
tags: [architecture, example]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---
```

`type` is required and non-empty. Normal documents also include `title`, `description`, `tags`, `status`, `source_kind`, and an ISO 8601 `timestamp`. Preserve useful additional metadata. Use `deprecated` only when content explicitly says so, and `generated` only when generation is clear.

Choose a direct content type such as `Project Overview`, `API Reference`, `API Endpoint`, `Architecture Note`, `ADR`, `Domain Concept`, `Data Model`, `Runbook`, `Playbook`, `Integration Guide`, `Development Guide`, `Configuration Reference`, `Operational Procedure`, or `Reference`. Former RAG material receives the same content-based classification; `RAG Source` is not a content type.

## Navigation and History

- Root `index.md` links major sections; folder indexes link documents within their section.
- Index entries use relative Markdown links and short descriptions; indexes do not duplicate document bodies.
- Update applicable indexes after adding, removing, renaming, or materially changing documents.
- Record significant knowledge-bundle changes in root `log.md`, newest first.
- Add `Related` sections only when relationships are supported by repository evidence.

## Knowledge Graph Lifecycle

Markdown files under `/` are the source of truth. `knowledge-graph.json` is a generated navigation artifact; it never overrides Markdown. Regenerate it after adding, deleting, or renaming documents; changing frontmatter or Markdown links; or materially changing document meaning:

```bash
python3 docs/build_okf_graph.py
```

Generator creates concept-document nodes with OKF metadata, edges from internal Markdown links, and a list of unresolved links. Reserved `index.md` and `log.md` files are excluded as concept nodes by default.

When available, agents should load graph first for discovery, filter nodes by `type`, `tags`, `status`, or keywords in `title` and `description`, then follow `edges` to related concepts. Read actual Markdown documents before making decisions or changes. If graph is missing or stale, navigate from [index.md](index.md), use Markdown directly, then regenerate graph when possible.

## Validation

Run from repository root:

```bash
python3 docs/lint_okf_docs.py
```

Validator checks required frontmatter, common fields, non-empty `type`, and local Markdown links. Navigation/history files are exempt from frontmatter checks.
