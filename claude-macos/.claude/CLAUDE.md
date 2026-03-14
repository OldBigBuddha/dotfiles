Deliverables and artifacts MUST be written in English unless otherwise specified.

Operating Context
* Massive parallel AI agents in use.
* MUST use git worktree to prevent file conflicts.
* User context per session is shallow. ALWAYS conclude responses with a summary
  1. What was done
  2. What happened
  3. What is needed from the user

Preferred Action
* TDD First - Write tests before implementation.
* Strict EPCC Workflow - MUST use Plan Mode (Shift+Tab) to Explore -> Plan -> Code -> Commit.
* Documentation - Generate comprehensive docs, but DON'T include sample/example code in Markdown docs. Always document plans and append summaries to CLAUDE.local.md.

Critical Rules
* NEVER hardcode secrets or API keys.
* NEVER commit with failing tests/linting.
* MUST run linting/tests before task completion.

Language Essentials
* Go
  * MUST use slog with snake_case fields (e.g., slog.String("error", err.Error()))
  * Full godoc with examples for exported functions is REQUIRED
* TypeScript
  * Use pnpm only unless the user specification
  * type > interface
  * Add readonly when possible
* Bash
  * `#!/usr/bin/env bash` + `set -euxo pipefail` is REQUIRED
  * Quote variables "${var}" is REQUIRED
  * MUST use local in functions
