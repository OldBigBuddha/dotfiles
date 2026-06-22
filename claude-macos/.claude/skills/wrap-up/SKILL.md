---
name: wrap-up
description: Run at the end of a session to distill what was learned or discovered and append/update it to memory. Use when the user says "wrap up", wants to capture session learnings, or asks to persist what we figured out before ending.
disable-model-invocation: true
context: fork
---

Wrap up this session by capturing durable learnings into the file-based memory system, then report what changed.

The memory format, file location, the four memory types (`user` / `feedback` / `project` / `reference`), and the `MEMORY.md` index rules are defined in your global instructions — follow them exactly. This skill is only the end-of-session procedure.

## Procedure

1. **Review the session.** Scan the whole conversation for things worth persisting:
   - Stable facts about the user, their role, environment, or preferences (`user`)
   - Corrections or confirmed working approaches the user gave you, with the why (`feedback`)
   - Ongoing work, goals, or constraints not derivable from the code or git history (`project`)
   - Pointers to external resources — URLs, dashboards, tickets (`reference`)

2. **Filter hard.** Drop anything that is:
   - Already recorded in the repo, git history, or a CLAUDE.md
   - Only relevant to this one conversation (transient task state)
   - A fix or structure that re-reading the code would reveal
   If the user asked you to remember something that fails this filter, capture what was *non-obvious* about it instead, or say nothing.

3. **Reconcile with existing memory.** Read `MEMORY.md` and any candidate files. For each learning, decide:
   - **Update** an existing file if it already covers the topic (prefer this over duplicates)
   - **Create** a new file if nothing covers it
   - **Delete** a file that this session proved wrong
   Link related memories with `[[name]]` in the body.

4. **Confirm before writing.** Present a short numbered list of proposed changes (create / update / delete + one-line reason each). If there is nothing worth saving, say so and stop. Otherwise wait for the user's go-ahead, then apply.

5. **Apply.** Write each memory file with correct frontmatter, then add or update its one-line pointer in `MEMORY.md`. Never put memory content in `MEMORY.md` itself.

## Output

Conclude with the standard session summary:
1. What was done — which memories were created / updated / deleted
2. What happened — anything notable (e.g. learnings deliberately skipped and why)
3. What is needed from the user — usually nothing
