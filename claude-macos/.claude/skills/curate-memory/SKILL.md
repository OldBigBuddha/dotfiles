---
name: curate-memory
description: Restructure a bloated memory store into an efficient, progressive-disclosure shape — merge duplicates, split overloaded files, prune stale facts, and tighten the MEMORY.md index. Run at the end of the day to consolidate what /wrap-up accumulated across sessions.
disable-model-invocation: true
context: fork
---

Curate the file-based memory store: reorganize what has accumulated into a lean, progressive-disclosure structure, then report what changed.

This skill does **not** capture new session learnings — that is `/wrap-up`'s job. Assume per-session facts are already written; your task is to reshape the existing store so it stays cheap to load and easy to recall from. The memory format, file location, the four types (`user` / `feedback` / `project` / `reference`), and the `MEMORY.md` index rules are defined in your global instructions — follow them exactly.

## Progressive disclosure goal

`MEMORY.md` is loaded into context every session; individual files are read only when judged relevant. So:
- **Top layer (`MEMORY.md`)** stays minimal and scannable — one terse pointer per memory, just enough to decide relevance. Group pointers under headings (by type, then topic) once the list grows.
- **Detail layer (files)** holds exactly one fact each, read on demand.
Every byte in `MEMORY.md` is paid on every session; every file is paid only when recalled. Curate toward that asymmetry.

## Procedure

1. **Inventory.** Read `MEMORY.md` and every memory file. Build a picture of what exists and how it is referenced.

2. **Diagnose.** Flag:
   - **Duplicates / overlap** — multiple files asserting the same or nested facts
   - **Stale / contradicted** — facts a later session disproved or superseded (check dates; relative dates should already be absolute)
   - **Overloaded files** — one file carrying several distinct facts (violates one-fact-per-file)
   - **Weak index lines** — verbose, vague, or missing hooks in `MEMORY.md`; content leaking into the index instead of staying in files
   - **Broken graph** — `[[links]]` pointing nowhere, or related memories that should link but don't
   - **Orphans / dangling** — files absent from `MEMORY.md`, or index lines with no backing file

3. **Plan the restructure.**
   - **Merge** overlapping files into one canonical file (keep the best name; redirect inbound `[[links]]`)
   - **Split** overloaded files into focused single-fact files
   - **Prune** stale/wrong/superseded files
   - **Regroup** `MEMORY.md` under headings and tighten each pointer to a scannable one-liner hook
   - **Repair** the `[[link]]` graph and normalize frontmatter + kebab-case names
   Preserve the substance of every still-true fact — restructuring must not lose information.

4. **Confirm before applying.** Present a numbered plan of changes (merge / split / prune / rename / regroup + one-line reason each), and a one-line before/after size sense (e.g. file count, MEMORY.md line count). If the store is already clean, say so and stop. Otherwise wait for the user's go-ahead.

5. **Apply.** Make the file changes, then rewrite `MEMORY.md` so every pointer matches a file and no content lives in the index itself.

## Output

Conclude with the standard session summary:
1. What was done — merges / splits / prunes / renames, and the before→after size
2. What happened — anything notable (facts deliberately kept separate, judgment calls on merges)
3. What is needed from the user — usually nothing
