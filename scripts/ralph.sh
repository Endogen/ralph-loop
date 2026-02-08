#!/usr/bin/env bash
#
# Ralph Loop - Event-Driven AI Agent Loop
# https://github.com/Endogen/ralph-loop
#
set -euo pipefail

# Defaults
MAX_ITERS=${1:-20}
CLI="${RALPH_CLI:-codex}"
# CLI-specific default flags
if [[ -z "${RALPH_FLAGS:-}" ]]; then
  case "${CLI}" in
    codex)  CLI_FLAGS="-s workspace-write" ;;  # codex exec sandbox mode
    claude) CLI_FLAGS="--dangerously-skip-permissions" ;;
    *)      CLI_FLAGS="" ;;
  esac
else
  CLI_FLAGS="${RALPH_FLAGS}"
fi
TEST_CMD="${RALPH_TEST:-}"
PLAN_FILE="IMPLEMENTATION_PLAN.md"
LOG_DIR=".ralph"
LOG_FILE="$LOG_DIR/ralph.log"
NOTIFY_FILE="$LOG_DIR/pending-notification.txt"

# Completion markers
PLANNING_DONE="STATUS: PLANNING_COMPLETE"
BUILDING_DONE="STATUS: COMPLETE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat << EOF
Usage: $(basename "$0") [max_iterations]

Environment variables:
  RALPH_CLI    - CLI to use (codex, claude, opencode, goose) [default: codex]
  RALPH_FLAGS  - CLI flags [default: --full-auto]
  RALPH_TEST   - Test command to run after each iteration [optional]

Examples:
  ./ralph.sh 20                          # Run 20 iterations with Codex
  RALPH_CLI=claude ./ralph.sh 10         # Use Claude Code
  RALPH_TEST="pytest" ./ralph.sh         # Run pytest after each iteration
EOF
  exit 1
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

# Setup
mkdir -p "$LOG_DIR"

log() {
  echo -e "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Enhanced notification: write to file AND try wake
notify() {
  local message="$1"
  local timestamp
  timestamp="$(date -Iseconds)"
  local project_dir
  project_dir="$(pwd)"
  
  # Always write to pending notification file (fallback for rate limits)
  cat > "$NOTIFY_FILE" << EOF
{
  "timestamp": "$timestamp",
  "project": "$project_dir",
  "message": "$message",
  "iteration": ${CURRENT_ITER:-0},
  "max_iterations": $MAX_ITERS,
  "cli": "$CLI",
  "status": "pending"
}
EOF
  
  log "📝 Notification written to $NOTIFY_FILE"
  
  # Try wake (may fail if rate limited)
  if command -v openclaw &>/dev/null; then
    if openclaw gateway wake --text "[$project_dir] $message" --mode now 2>/dev/null; then
      # Wake succeeded - mark as delivered
      sed -i 's/"status": "pending"/"status": "delivered"/' "$NOTIFY_FILE" 2>/dev/null || true
      log "✅ Wake notification sent"
    else
      log "⚠️ Wake failed (rate limit?) - notification saved to file"
    fi
  else
    log "⚠️ openclaw not found - notification saved to file only"
  fi
}

# Clear pending notification (called by OpenClaw after processing)
clear_notification() {
  if [[ -f "$NOTIFY_FILE" ]]; then
    mv "$NOTIFY_FILE" "$LOG_DIR/last-notification.txt" 2>/dev/null || true
  fi
}

# Preflight checks
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo -e "${RED}❌ Must run inside a git repository${NC}"
  exit 1
fi

if ! command -v "$CLI" &>/dev/null; then
  echo -e "${RED}❌ CLI not found: $CLI${NC}"
  exit 1
fi

if [[ ! -f "PROMPT.md" ]]; then
  echo -e "${YELLOW}⚠️ PROMPT.md not found. Creating template...${NC}"
  cat > PROMPT.md << 'EOF'
# Ralph Loop

## Goal
[Describe what you want to build]

## Context
- Read: specs/*.md, IMPLEMENTATION_PLAN.md, AGENTS.md

## Notifications
When you need input or complete a milestone, write to .ralph/pending-notification.txt AND run:
```bash
cat > .ralph/pending-notification.txt << 'NOTIFY'
{"timestamp":"$(date -Iseconds)","message":"<PREFIX>: <your message>","status":"pending"}
NOTIFY
openclaw gateway wake --text "<PREFIX>: <message>" --mode now
```
Prefixes: DECISION, ERROR, BLOCKED, PROGRESS, DONE

## Completion
When finished, add to IMPLEMENTATION_PLAN.md: STATUS: COMPLETE
EOF
  echo -e "${BLUE}📝 Created PROMPT.md template. Edit it and run again.${NC}"
  exit 0
fi

touch AGENTS.md "$PLAN_FILE" 2>/dev/null || true

# Clear any stale pending notification from previous run
[[ -f "$NOTIFY_FILE" ]] && rm -f "$NOTIFY_FILE"

echo -e "${BLUE}🐺 Ralph Loop starting${NC}"
echo -e "   CLI: $CLI $CLI_FLAGS"
echo -e "   Max iterations: $MAX_ITERS"
echo -e "   Project: $(pwd)"
[[ -n "$TEST_CMD" ]] && echo -e "   Test command: $TEST_CMD"
echo ""

# Main loop
for i in $(seq 1 "$MAX_ITERS"); do
  CURRENT_ITER=$i
  export CURRENT_ITER
  
  log "${BLUE}=== Iteration $i/$MAX_ITERS ===${NC}"
  
  # Build the command based on CLI
  case "$CLI" in
    codex)
      # codex exec for non-interactive mode, flags go after exec
      CMD="codex exec $CLI_FLAGS"
      ;;
    claude)
      # Claude Code uses --print for non-interactive
      CMD="claude --print $CLI_FLAGS"
      ;;
    opencode)
      CMD="opencode run"
      ;;
    goose)
      CMD="goose run"
      ;;
    *)
      CMD="$CLI $CLI_FLAGS"
      ;;
  esac
  
  # Run the agent (fresh session each time!)
  log "Running: $CMD \"...\""
  if ! $CMD "$(cat PROMPT.md)" 2>&1 | tee -a "$LOG_FILE"; then
    EXIT_CODE=$?
    log "${YELLOW}⚠️ Agent exited with code $EXIT_CODE${NC}"
    notify "ERROR: Agent crashed on iteration $i/$MAX_ITERS (exit $EXIT_CODE)"
    sleep 5
    continue
  fi
  
  # Run tests if configured
  if [[ -n "$TEST_CMD" ]]; then
    log "Running tests: $TEST_CMD"
    if bash -lc "$TEST_CMD" 2>&1 | tee -a "$LOG_FILE"; then
      log "${GREEN}✅ Tests passed${NC}"
    else
      log "${YELLOW}⚠️ Tests failed${NC}"
    fi
  fi
  
  # Check completion markers
  if grep -Fq "$BUILDING_DONE" "$PLAN_FILE" 2>/dev/null; then
    log "${GREEN}✅ All tasks complete!${NC}"
    notify "DONE: Ralph loop finished. All tasks complete."
    exit 0
  fi
  
  if grep -Fq "$PLANNING_DONE" "$PLAN_FILE" 2>/dev/null; then
    log "${GREEN}📋 Planning phase complete${NC}"
    notify "PLANNING_COMPLETE: Ready for BUILDING mode. Switch PROMPT.md and restart."
    exit 0
  fi
  
  # Brief pause between iterations
  sleep 2
done

log "${RED}❌ Max iterations ($MAX_ITERS) reached${NC}"
notify "BLOCKED: Max iterations ($MAX_ITERS) reached without completion. Manual intervention needed."
exit 1
