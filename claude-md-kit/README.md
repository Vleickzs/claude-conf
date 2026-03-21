# claude-md-kit

Three slash commands to generate, clean up, and optimize your project's CLAUDE.md.

## Commands

| Command | When to use |
|---------|-------------|
| `/claude-md-init` | Project has no CLAUDE.md — generates one from scratch by analyzing your codebase |
| `/claude-md-cleanup` | CLAUDE.md is bloated — removes duplicates with global config and generic filler |
| `/claude-md-boost` | CLAUDE.md exists but is underperforming — rewrites it with expert prompt engineering and stack-specific conventions |

All three commands analyze your real code, never generate generic content, and ask for validation before writing.

## What boost adds (examples)

**Before:**
> "Use proper error handling"

**After:**
> "Wrap errors with `fmt.Errorf("functionName: %w", err)` — never return bare errors. Always add context about what operation failed."

**Before:**
> "Follow React best practices"

**After:**
> "Server Components by default. Add `'use client'` only for hooks/interactivity. Never import server-only modules in client components."

## Install

```bash
bash install.sh
```

Copies the 3 commands to `~/.claude/commands/`. Backs up existing commands if present.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
