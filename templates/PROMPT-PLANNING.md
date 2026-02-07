# Ralph PLANNING Loop

## Goal
[YOUR GOAL HERE - What are you building?]

## Context
- Read: specs/*.md
- Read: Current codebase structure
- Update: IMPLEMENTATION_PLAN.md

## Rules
1. Do NOT implement any code
2. Do NOT commit anything
3. Analyze gaps between specs and current codebase
4. Create/update IMPLEMENTATION_PLAN.md with prioritized tasks
5. Each task should be atomic and achievable in < 1 hour
6. If requirements are unclear, list specific questions

## Task Format
Use this format in IMPLEMENTATION_PLAN.md:
```markdown
## Tasks

### HIGH PRIORITY
- [ ] Task 1: Brief description
- [ ] Task 2: Brief description

### MEDIUM PRIORITY
- [ ] Task 3: Brief description

### LOW PRIORITY
- [ ] Task 4: Brief description

## Questions
- Question 1?
- Question 2?

## Notes
- Observation 1
- Observation 2
```

## Notifications
When you need input or finish, ALWAYS do both:

1. Write to file (fallback for rate limits):
```bash
mkdir -p .ralph
cat > .ralph/pending-notification.txt << EOF
{"timestamp":"$(date -Iseconds)","message":"<PREFIX>: <message>","status":"pending"}
EOF
```

2. Try wake notification:
```bash
openclaw gateway wake --text "<PREFIX>: <message>" --mode now
```

Prefixes:
- `DECISION:` — Need human input on architectural choice
- `QUESTION:` — Requirements unclear, need clarification
- `DONE:` — Planning complete

## Completion
When the plan is complete and comprehensive:
1. Add this line to IMPLEMENTATION_PLAN.md:
   ```
   STATUS: PLANNING_COMPLETE
   ```
2. Notify (both file and wake):
   ```bash
   mkdir -p .ralph
   cat > .ralph/pending-notification.txt << EOF
   {"timestamp":"$(date -Iseconds)","message":"PLANNING_COMPLETE: X tasks identified. Ready for BUILDING.","status":"pending"}
   EOF
   openclaw gateway wake --text "PLANNING_COMPLETE: X tasks identified. Ready for BUILDING mode." --mode now
   ```
