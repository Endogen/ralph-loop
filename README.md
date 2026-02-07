# 🐺 Ralph Loop (Event-Driven)

An enhanced [Ralph pattern](https://ghuntley.com/ralph/) implementation with **event-driven notifications** for AI agent loops.

Instead of polling or running blind, the AI agent (Codex, Claude Code, etc.) notifies OpenClaw when it needs attention — decisions, errors, blockers, or completion.

## What's Different?

| Standard Ralph | This Version |
|----------------|--------------|
| Bash loop runs until done/fail | Agent notifies on events |
| Manual monitoring | Automatic escalation |
| Silent failures | Immediate error alerts |
| No human-in-loop | Decision requests |

## How It Works

1. **PLANNING phase**: Agent analyzes specs, creates `IMPLEMENTATION_PLAN.md`
2. **BUILDING phase**: Agent implements tasks one by one, tests, commits
3. **Notifications**: Agent calls `openclaw gateway wake` when:
   - `DECISION:` — Needs human input
   - `ERROR:` — Tests failing after retries
   - `BLOCKED:` — Missing dependency or unclear spec
   - `PROGRESS:` — Major milestone complete
   - `DONE:` — All tasks finished

## Quick Start

```bash
# 1. Set up project
mkdir my-project && cd my-project && git init

# 2. Copy templates
cp templates/PROMPT-PLANNING.md PROMPT.md
cp templates/AGENTS.md AGENTS.md
mkdir specs && echo "# Overview\n\nGoal: ..." > specs/overview.md

# 3. Edit files for your project
# - PROMPT.md: Set your goal
# - AGENTS.md: Set test commands
# - specs/*.md: Define requirements

# 4. Run the loop
./scripts/ralph.sh 20
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Full documentation for AI agents |
| `scripts/ralph.sh` | The bash loop script |
| `templates/PROMPT-PLANNING.md` | Template for planning phase |
| `templates/PROMPT-BUILDING.md` | Template for building phase |
| `templates/AGENTS.md` | Template for project context |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_CLI` | `codex` | CLI to use (codex, claude, opencode, goose) |
| `RALPH_FLAGS` | `--full-auto` | Flags for the CLI |
| `RALPH_TEST` | (none) | Test command to run each iteration |

## Example: Antique Catalogue

```bash
# specs/overview.md
## Goal
Web app for cataloguing antique items with metadata, images, and categories.

## Features
1. CRUD for items (name, description, age, purchase info)
2. Image upload
3. Tags and categories
4. Search and filter

## Tech Stack
- Python 3.11 + FastAPI
- SQLite
- HTMX + Tailwind
```

Run planning:
```bash
cp templates/PROMPT-PLANNING.md PROMPT.md
# Edit PROMPT.md with the goal
./scripts/ralph.sh 10
```

After planning completes, switch to building:
```bash
cp templates/PROMPT-BUILDING.md PROMPT.md
# Edit with same goal
RALPH_TEST="pytest" ./scripts/ralph.sh 20
```

## Safety

⚠️ Auto-approve flags (`--full-auto`, `--dangerously-skip-permissions`) give the agent write access.

- Run in a dedicated branch
- Use a sandbox for untrusted code
- Keep `git reset --hard` ready
- Review commits before pushing

## Credits

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/) and [snarktank/ralph](https://github.com/snarktank/ralph).

## License

MIT
