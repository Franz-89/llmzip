---
type: Reference
title: Repository Skills
description: "Catalog of repository-local and configured skills with their purposes and activation criteria."
tags: [skills, agents, workflows]
status: active
source_kind: hand-written
timestamp: "2026-06-30T06:51:14Z"
---

## Repository Skills

### tabler-htmx-alpine-migration

- Purpose: Migrate controller/template UI surfaces to a single Tabler, HTMX, and Alpine architecture.
- Current location: `.agents/skills/tabler-htmx-alpine-migration/SKILL.md`
- Related workflow/config file: `.agents/skills/tabler-htmx-alpine-migration/agents/openai.yaml`
- Summary: Merges the Tabler UI, HTMX, and Alpine migration workflows into one Sapienscore-specific process. It supports starting from an attached controller and using `../ui/template-map.md` to update all affected templates, or starting from an attached template and migrating controller actions/functions that render or update it. It requires Tabler for presentation, Bootstrap 5-compatible Tabler utilities where useful, HTMX for server-rendered fragments and dynamic UI, update actions that swap only the affected element when practical, Alpine only for lightweight local state, no retrocompatibility with old UI/AJAX/plugin layers, and no custom CSS unless a narrow exception is unavoidable. Any unavoidable CSS must live in `customTabler.css`.
- Use when: A user asks to migrate a controller, route, View class, or `.phtml` template to the preferred Tabler, HTMX, and Alpine stack, especially when the affected files must be discovered through `../ui/template-map.md`.

### cavecrew

- Purpose: Decide when to use caveman-compressed subagent presets for investigation, small edits, or diff review.
- Current location: `.agents/skills/cavecrew/SKILL.md`
- Related file: `.agents/skills/cavecrew/README.md`
- Summary: Guides the main thread toward `cavecrew-investigator`, `cavecrew-builder`, or `cavecrew-reviewer` when compressed subagent output is useful for saving context. It defines when to use cavecrew instead of vanilla explorer/reviewer agents, the output contracts each preset returns, and safe chaining patterns such as locate-fix-verify.
- Use when: A user asks to delegate to subagents, use cavecrew, spawn investigator/builder/reviewer agents, save context during delegation, or produce compressed subagent output.

### caveman

- Purpose: Use ultra-compressed communication while preserving technical accuracy.
- Current location: `.agents/skills/caveman/SKILL.md`
- Related file: `.agents/skills/caveman/README.md`
- Summary: Defines caveman communication modes including lite, full, ultra, wenyan-lite, wenyan-full, and wenyan-ultra. It removes filler, pleasantries, hedging, and redundant prose while preserving code, exact technical terms, commands, and clarity for security or irreversible actions.
- Use when: A user asks for caveman mode, terse communication, fewer tokens, brief answers, or invokes `/caveman`.

### caveman-commit

- Purpose: Generate terse Conventional Commits messages with minimal noise.
- Current location: `.agents/skills/caveman-commit/SKILL.md`
- Related file: `.agents/skills/caveman-commit/README.md`
- Summary: Produces concise commit messages using Conventional Commits types, imperative mood, short subjects, and optional bodies only when the reason, breaking change, migration, security context, or issue reference is needed. It does not stage files or run `git commit`.
- Use when: A user asks for a commit message, wants to write or generate a commit, invokes `/commit`, or invokes `/caveman-commit`.

### caveman-compress

- Purpose: Compress natural-language memory files into caveman format while preserving technical substance.
- Current location: `.agents/skills/caveman-compress/SKILL.md`
- Related files: `.agents/skills/caveman-compress/README.md`, `.agents/skills/caveman-compress/SECURITY.md`, `.agents/skills/caveman-compress/scripts/`
- Summary: Runs the adjacent compression scripts to rewrite markdown memory files such as `CLAUDE.md`, todos, or preferences in compact caveman prose. It preserves code blocks, inline code, URLs, file paths, commands, headings, list structure, tables, frontmatter, technical terms, dates, and version numbers, while saving a human-readable backup as `FILE.original.md`.
- Use when: A user invokes `/caveman-compress FILEPATH` or asks to compress a memory file for lower token usage.

### caveman-help

- Purpose: Show a one-shot quick-reference card for caveman modes, commands, and related skills.
- Current location: `.agents/skills/caveman-help/SKILL.md`
- Related file: `.agents/skills/caveman-help/README.md`
- Summary: Displays available caveman modes, skill triggers, deactivation commands, and default-mode configuration without changing or persisting the current mode.
- Use when: A user invokes `/caveman-help` or asks for caveman help, caveman commands, or how to use caveman.

### caveman-review

- Purpose: Produce ultra-compressed code review comments.
- Current location: `.agents/skills/caveman-review/SKILL.md`
- Related file: `.agents/skills/caveman-review/README.md`
- Summary: Formats review findings as one-line comments with file or line location, problem, and concrete fix. It supports severity prefixes for bugs, risks, nits, and questions, while dropping filler and preserving exact symbols and line numbers.
- Use when: A user asks for a code review, PR review, diff review, invokes `/review`, or invokes `/caveman-review`.

### caveman-stats

- Purpose: Show real token usage and estimated savings for the current session.
- Current location: `.agents/skills/caveman-stats/SKILL.md`
- Related file: `.agents/skills/caveman-stats/README.md`
- Summary: Documents the hook-backed `/caveman-stats` behavior. The stats are produced by `hooks/caveman-stats.js` through `hooks/caveman-mode-tracker.js`; the model does not estimate or compute the numbers.
- Use when: A user invokes `/caveman-stats`.

### operational-guide-from-branch

- Purpose: Generate an employee-facing operational guide from branch changes or from one or more attached feature files plus their related files.
- Current location: `.agents/skills/operational-guide-from-branch/SKILL.md`
- Related files: `.agents/skills/operational-guide-from-branch/examples/example2.html`, `.agents/skills/operational-guide-from-branch/examples/format_example.html`
- Summary: Reviews branch changes or a feature file set, traces related routes/controllers/templates/managers/models/migrations/assets, and generates a practical TinyMCE-compatible HTML guide for employees. It emphasizes family entertainment venue operations, real-world business context, workflow consequences, realistic scenarios, and user-friendly explanations.
- Use when: A user asks for operational documentation or an employee guide for a feature based on the current branch, named files, attached files, or an explicitly requested cross-repository feature analysis.

### review-branch-code

- Purpose: Make an extensive code review of all files modified or added in the current branch compared with `develop`.
- Current location: `.agents/skills/review-branch-code/SKILL.md`
- Related workflow/config file: `.agents/skills/review-branch-code/agents/openai.yaml`
- Summary: Compares branch changes against `develop`, inspects added and modified files, follows references as needed, and reports defects first with severity and file/line references. It focuses on logical inconsistencies, calculation errors, persistence issues, incomplete behavior, data integrity, performance, unused logic, security/access control, and repository conventions.
- Use when: A user asks for a branch code review, especially before merging or when looking for defects in changed files.

### translate-adminlte-file

- Purpose: Translate an attached English Sapienscore AdminLTE translation utility file to the requested language while preserving the original file structure.
- Current location: `.agents/skills/translate-adminlte-file/SKILL.md`
- Related workflow/config file: `.agents/skills/translate-adminlte-file/agents/openai.yaml`
- Summary: Translates only human-facing values in AdminLTE translation utility files, preserves `<<...>>` tags and `{{...}}` placeholders, ensures parameterized entries have `/** Has param`, and saves the result as the next sequential file under `translation/translation_utility/adminlte/$lang`.
- Use when: A user provides or names an English AdminLTE translation utility file and asks for a translation into a specific target language.
