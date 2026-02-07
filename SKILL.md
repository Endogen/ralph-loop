---
name: ralph-loop
description: Generate copy-paste bash scripts for Ralph Wiggum/AI agent loops (Codex, Claude Code, OpenCode, Goose). Use when asked for a "Ralph loop", "Ralph Wiggum loop", or an AI loop to plan/build code via PROMPT.md + AGENTS.md, SPECS, and IMPLEMENTATION_PLAN.md, including PLANNING vs BUILDING modes, backpressure, sandboxing, and completion conditions.
---

# Ralph Loop (Event-Driven)

Enhanced Ralph pattern with **event-driven notifications** — Codex/Claude calls OpenClaw when it needs attention instead of polling.

## Overview

The Ralph pattern runs an AI coding agent in a loop:
1. **PLANNING** → Break requirements into tasks in `IMPLEMENTATION_PLAN.md`
2. **BUILDING** → Implement tasks one by one, test, commit, repeat

**Key enhancement:** The agent notifies OpenClaw via `openclaw gateway wake` when:
- A decision is needed
- An error occurs
- It's blocked
- A milestone completes

## File Structure

```
project/
├── PROMPT.md              # Loaded each iteration (mode-specific)
├── AGENTS.md              # Project context, test commands, learnings
├── IMPLEMENTATION_PLAN.md # Task list with status
├── specs/                 # Requirements specs
│   ├── overview.md
│   └── <feature>.md
└── .ralph/
    └── ralph.log          # Execution log
```

## Workflow

### 1. Collect Requirements

Ask for (if not provided):
- **Goal/JTBD**: What outcome is needed?
- **CLI**: `codex`, `claude`, `opencode`, `goose`
- **Mode**: `PLANNING`, `BUILDING`, or `BOTH`
- **Tech stack**: Language, framework, database
- **Test command**: How to verify correctness
- **Max iterations**: Default 20

### 2. Generate Specs

Break the goal into **topics of concern** → `specs/*.md`:

```markdown
# specs/overview.md
## Goal
<one-sentence JTBD>

## Tech Stack
- Language: Python 3.11
- Framework: FastAPI
- Database: SQLite
- Frontend: HTMX + Tailwind

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

### 3. Generate AGENTS.md

```markdown
# AGENTS.md

## Project
<brief description>

## Commands
- **Install**: `pip install -e .`
- **Test**: `pytest`
- **Lint**: `ruff check .`
- **Run**: `python -m app`

## Backpressure
Run after each implementation:
1. `ruff check . --fix`
2. `pytest`

## Learnings
<!-- Agent appends operational notes here -->
```

### 4. Generate PROMPT.md (Mode-Specific)

#### PLANNING Mode

```markdown
# Ralph PLANNING Loop

## Goal
<JTBD>

## Context
- Read: specs/*.md
- Read: Current codebase structure
- Update: IMPLEMENTATION_PLAN.md

## Rules
1. Do NOT implement code
2. Do NOT commit
3. Analyze gaps between specs and current state
4. Create/update IMPLEMENTATION_PLAN.md with prioritized tasks
5. Each task should be small (< 1 hour of work)
6. If requirements are unclear, list questions

## Notifications
When you need input or finish planning:
```bash
openclaw gateway wake --text "PLANNING: <your message>" --mode now
```

Use prefixes:
- `DECISION:` — Need human input on a choice
- `QUESTION:` — Requirements unclear
- `DONE:` — Planning complete

## Completion
When plan is complete and ready for building, add to IMPLEMENTATION_PLAN.md:
```
STATUS: PLANNING_COMPLETE
```
Then notify:
```bash
openclaw gateway wake --text "DONE: Planning complete. X tasks identified." --mode now
```
```

#### BUILDING Mode

```markdown
# Ralph BUILDING Loop

## Goal
<JTBD>

## Context
- Read: specs/*.md, IMPLEMENTATION_PLAN.md, AGENTS.md
- Implement: One task per iteration
- Test: Run backpressure commands from AGENTS.md

## Rules
1. Pick the highest priority incomplete task from IMPLEMENTATION_PLAN.md
2. Investigate relevant code before changing
3. Implement the task
4. Run backpressure commands (lint, test)
5. If tests pass: commit with clear message, mark task done
6. If tests fail: try to fix (max 3 attempts), then notify
7. Update AGENTS.md with any operational learnings
8. Update IMPLEMENTATION_PLAN.md with progress

## Notifications
Call OpenClaw when needed:
```bash
openclaw gateway wake --text "<PREFIX>: <message>" --mode now
```

Prefixes:
- `DECISION:` — Need human input (e.g., "SQLite vs PostgreSQL?")
- `ERROR:` — Tests failing after 3 attempts
- `BLOCKED:` — Missing dependency, credentials, or unclear spec
- `PROGRESS:` — Major milestone complete (optional)
- `DONE:` — All tasks complete

## Completion
When all tasks are done:
1. Add to IMPLEMENTATION_PLAN.md: `STATUS: COMPLETE`
2. Notify:
```bash
openclaw gateway wake --text "DONE: All tasks complete. Summary: <what was built>" --mode now
```
```

### 5. Generate the Loop Script

#### Minimal (Geoff-style)
```bash
while :; do codex exec --full-auto "$(cat PROMPT.md)"; done
```

#### Controlled Loop (Recommended)
```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
MAX_ITERS=${1:-20}
CLI="codex"
CLI_FLAGS="--full-auto"
TEST_CMD="pytest"
PLAN_FILE="IMPLEMENTATION_PLAN.md"
LOG_DIR=".ralph"
LOG_FILE="$LOG_DIR/ralph.log"

# Completion markers
PLANNING_DONE="STATUS: PLANNING_COMPLETE"
BUILDING_DONE="STATUS: COMPLETE"

# Setup
mkdir -p "$LOG_DIR"
touch PROMPT.md AGENTS.md "$PLAN_FILE"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Must run inside a git repository"
  exit 1
fi

log() {
  echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
  openclaw gateway wake --text "$1" --mode now 2>/dev/null || true
}

# Main loop
for i in $(seq 1 "$MAX_ITERS"); do
  log "=== Iteration $i/$MAX_ITERS ==="
  
  # Run the agent
  $CLI exec $CLI_FLAGS "$(cat PROMPT.md)" 2>&1 | tee -a "$LOG_FILE"
  EXIT_CODE=${PIPESTATUS[0]}
  
  if [[ $EXIT_CODE -ne 0 ]]; then
    log "⚠️ Agent exited with code $EXIT_CODE"
    notify "ERROR: Agent crashed on iteration $i. Check logs."
    sleep 5
    continue
  fi
  
  # Run tests if in building mode
  if [[ -n "$TEST_CMD" ]] && grep -q "BUILDING" PROMPT.md 2>/dev/null; then
    log "Running tests: $TEST_CMD"
    if ! bash -lc "$TEST_CMD" 2>&1 | tee -a "$LOG_FILE"; then
      log "⚠️ Tests failed"
    fi
  fi
  
  # Check completion
  if grep -Fq "$BUILDING_DONE" "$PLAN_FILE" 2>/dev/null; then
    log "✅ All tasks complete!"
    notify "DONE: Ralph loop finished. All tasks complete."
    exit 0
  fi
  
  if grep -Fq "$PLANNING_DONE" "$PLAN_FILE" 2>/dev/null; then
    log "📋 Planning complete. Switch PROMPT.md to BUILDING mode."
    notify "PLANNING: Complete. Ready to switch to BUILDING mode."
    exit 0
  fi
  
  # Brief pause between iterations
  sleep 2
done

log "❌ Max iterations ($MAX_ITERS) reached"
notify "BLOCKED: Max iterations reached without completion."
exit 1
```

## Event Handling (for OpenClaw)

When I receive a wake notification from the Ralph loop, I should:

| Prefix | Action |
|--------|--------|
| `DONE:` | Report completion to user, summarize what was built |
| `PROGRESS:` | Log it, optionally update user if significant |
| `DECISION:` | Present options to user, wait for answer, then inject response |
| `ERROR:` | Analyze the error, attempt to help, or escalate to user |
| `BLOCKED:` | Escalate to user immediately with context |
| `QUESTION:` | Present question to user, get clarification |

### Injecting Responses

To send a decision back to the running loop, append to AGENTS.md:
```markdown
## Human Decisions
- [2024-01-15 14:30] Q: SQLite vs PostgreSQL? A: Use SQLite for simplicity.
```

The next iteration will read AGENTS.md and see the answer.

## CLI-Specific Notes

### Codex
- Requires git repository
- `--full-auto`: Auto-approve in workspace (sandboxed)
- `--yolo`: No sandbox, no approvals (dangerous but fast)
- Default model: gpt-5.2-codex

### Claude Code
- `--dangerously-skip-permissions`: Auto-approve (use in sandbox)
- No git requirement

### OpenCode
- `opencode run "$(cat PROMPT.md)"`

### Goose
- `goose run "$(cat PROMPT.md)"`

## Safety

⚠️ **Auto-approve flags are dangerous.** Always:
1. Run in a dedicated directory/branch
2. Use a sandbox (Docker/VM) for untrusted projects
3. Have `git reset --hard` ready as escape hatch
4. Review commits before pushing

## Quick Start

```bash
# 1. Create project directory
mkdir my-project && cd my-project && git init

# 2. Create initial files
cat > PROMPT.md << 'EOF'
# Ralph PLANNING Loop
## Goal
Build a web app that...
...
EOF

cat > AGENTS.md << 'EOF'
# AGENTS.md
## Commands
- Test: `pytest`
...
EOF

mkdir specs
cat > specs/overview.md << 'EOF'
# Overview
...
EOF

# 3. Run the loop
./ralph.sh 20
```

## Example: Antique Catalogue

```bash
# specs/overview.md
## Goal
Web app for cataloguing antique items with metadata, images, and categories.

## Tech Stack
- Python 3.11 + FastAPI
- SQLite + SQLAlchemy
- HTMX + Tailwind CSS
- Local file storage for images

## Features
1. CRUD for items (name, description, age, purchase info, dimensions)
2. Image upload (multiple per item)
3. Tags and categories
4. Search and filter
5. Multiple view modes (grid, list, detail)
```

The agent will break this into tasks, implement each, test, and notify on completion.
