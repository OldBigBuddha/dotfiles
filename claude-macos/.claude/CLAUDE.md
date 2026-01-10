# CLAUDE.md - Global Configuration

## Core Philosophy
- **Simple is Best** - YAGNI/KISS principles always
- **TDD proposed by t_wada First** - Write tests before implementation
- **Flat is Better** - Avoid deep nesting, use early returns
- **Proactive Help** - Spot issues and improvements before asked
- **Document Everything** - Auto-generate comprehensive docs
- **Simple Documentation** - DON'T include any sample or example code in Markdown doc
- **Learn & Optimize** - Recognize patterns, suggest abstractions

## Workflow

### Explore-Plan-Code-Commit (EPCC)
1. **EXPLORE** - Understand before acting
   - Read CLAUDE.*.md files first
   - Scan relevant code, docs, and context
   - Look for repetitive patterns → suggest abstractions
   - Spot missing error handling → propose fixes
   - Use Task agents for complex exploration
   - NEVER skip to coding without understanding

2. **PLAN** - Think before implementing
   - Create detailed approach with TodoWrite
   - Use "ultrathink" for complex problems
   - Write tests first (TDD approach)
   - See manual processes → create automation scripts
   - Always document plan in CLAUDE.local.md

3. **CODE** - Implement systematically
   - Follow the plan, don't improvise
   - Make tests pass → Refactor → Document
   - Find undocumented code → generate docs
   - Verify solution reasonableness
   - Run lint/type checks continuously

4. **COMMIT** - Finalize properly
   - Only commit after ALL checks pass
   - Update docs/READMEs if needed
   - Create PR with clear description
   - After completing → append summary to CLAUDE.local.md

### Git Commits

feat(auth): add JWT token refresh endpoint
fix(api): handle null response in user service
docs(readme): update installation instructions
perf(db): optimize query with proper indexing
refactor(core): extract validation logic to utils
chore(deps): upgrade to React 19

## Critical Rules

### NEVER (Non-negotiable)
- Hardcode secrets or API keys
- Commit with failing tests/linting
- Use `any` in TypeScript production
- Ignore errors in Go

### MUST (Required)
- Generate comprehensive function documentation
- Run linting/tests before task completion
- Suggest improvements in every interaction
- Check CLAUDE.*.md files FIRST in new projects

## Language Essentials

### Go
- Error handling: Always check, use `fmt.Errorf("%w", err)`
- Logging: `slog` with snake_case fields, `slog.String("error", err.Error())`
- Docs: Full godoc with examples for exported functions

### TypeScript
- Package manager: `pnpm` only
- Types: `type` > `interface`, add `readonly` when possible
- Quality: `npx biome format/lint`, `npx tsc --noEmit`

### Bash
- Always: `#!/usr/bin/env bash` + `set -euxo pipefail`
- Quote variables: `"${var}"`, use `local` in functions

