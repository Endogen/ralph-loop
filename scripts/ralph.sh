#!/usr/bin/env bash
#
# Ralph Loop - Event-Driven AI Agent Loop
# https://github.com/Endogen/ralph-loop
#
set -euo pipefail

# Defaults
MAX_ITERS=${1:-20}
CLI="${RALPH_CLI:-codex}"
CLI_FLAGS="${RALPH_FLAGS:---full-auto}"
TEST_CMD="${RALPH_TEST:-}"
PLAN_FILE="IMPLEMENTATION_PLAN.md"
LOG_DIR=".ralph"
LOG_FILE="$LOG_DIR/ralph.log"

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

notify() {
  if command -v openclaw &>/dev/null; then
    openclaw gateway wake --text "$1" --mode now 2>/dev/null || true
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
When you need input or complete a milestone:
```bash
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

echo -e "${BLUE}🐺 Ralph Loop starting${NC}"
echo -e "   CLI: $CLI $CLI_FLAGS"
echo -e "   Max iterations: $MAX_ITERS"
[[ -n "$TEST_CMD" ]] && echo -e "   Test command: $TEST_CMD"
echo ""

# Main loop
for i in $(seq 1 "$MAX_ITERS"); do
  log "${BLUE}=== Iteration $i/$MAX_ITERS ===${NC}"
  
  # Build the command based on CLI
  case "$CLI" in
    codex)
      CMD="codex exec $CLI_FLAGS"
      ;;
    claude)
      CMD="claude $CLI_FLAGS"
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
  
  # Run the agent
  log "Running: $CMD \"...\""
  if ! $CMD "$(cat PROMPT.md)" 2>&1 | tee -a "$LOG_FILE"; then
    EXIT_CODE=$?
    log "${YELLOW}⚠️ Agent exited with code $EXIT_CODE${NC}"
    notify "ERROR: Agent crashed on iteration $i (exit $EXIT_CODE)"
    sleep 5
    continue
  fi
  
  # Run tests if configured and in building mode
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
    notify "DONE: Ralph loop finished successfully."
    exit 0
  fi
  
  if grep -Fq "$PLANNING_DONE" "$PLAN_FILE" 2>/dev/null; then
    log "${GREEN}📋 Planning phase complete${NC}"
    notify "PLANNING: Complete. Ready for BUILDING mode."
    echo -e "${BLUE}Switch PROMPT.md to BUILDING mode and run again.${NC}"
    exit 0
  fi
  
  # Brief pause
  sleep 2
done

log "${RED}❌ Max iterations ($MAX_ITERS) reached${NC}"
notify "BLOCKED: Max iterations reached without completion."
exit 1
