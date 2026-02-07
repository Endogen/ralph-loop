# Ralph BUILDING Loop

## Goal
[YOUR GOAL HERE - What are you building?]

## Context
- Read: specs/*.md
- Read: IMPLEMENTATION_PLAN.md (your task list)
- Read: AGENTS.md (test commands, project conventions, learnings, human decisions)

## Rules
1. Pick the highest priority incomplete task from IMPLEMENTATION_PLAN.md
2. Investigate the relevant code BEFORE making changes
3. Implement the task completely
4. Run the backpressure commands from AGENTS.md (lint, test)
5. If tests pass:
   - Commit with a clear, conventional message (feat:, fix:, refactor:, etc.)
   - Mark the task as done in IMPLEMENTATION_PLAN.md: `- [x] Task`
6. If tests fail:
   - Attempt to fix (max 3 tries per task)
   - If still failing after 3 attempts, notify for help
7. Update AGENTS.md with any operational learnings
8. Move to next task

## Error Handling
If you encounter issues:
- Missing dependency: Try to add it, if unsure notify
- Unclear requirement: Check specs/ and AGENTS.md (Human Decisions section), if still unclear notify
- Repeated test failures: Notify after 3 attempts
- Blocked by external factor: Notify immediately

## Notifications
When you need input or hit milestones, ALWAYS do both:

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
- `DECISION:` — Need human input (e.g., "Use REST or GraphQL?")
- `ERROR:` — Tests failing after 3 attempts on same task
- `BLOCKED:` — Missing credentials, unclear spec, external dependency
- `PROGRESS:` — Major milestone complete (e.g., "Auth module done")
- `DONE:` — All tasks complete

## Completion
When ALL tasks in IMPLEMENTATION_PLAN.md are marked done:
1. Run final test suite to verify everything works
2. Add this line to IMPLEMENTATION_PLAN.md:
   ```
   STATUS: COMPLETE
   ```
3. Notify with summary (both file and wake):
   ```bash
   mkdir -p .ralph
   cat > .ralph/pending-notification.txt << EOF
   {"timestamp":"$(date -Iseconds)","message":"DONE: All tasks complete. Built: <summary>","status":"pending"}
   EOF
   openclaw gateway wake --text "DONE: All tasks complete. Built: <summary of what was created>" --mode now
   ```
