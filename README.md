# 🐺 Ralph Loop (Event-Driven)

An enhanced [Ralph pattern](https://ghuntley.com/ralph/) implementation with **event-driven notifications** and **rate-limit resilience** for AI agent loops.

## Key Features

- 🔔 **Event-driven notifications** — Agent notifies OpenClaw on decisions, errors, completion
- 💾 **File-based fallback** — Notifications persist to `.ralph/pending-notification.txt` if wake fails
- 🔄 **Clean sessions** — Each iteration is a fresh agent context (avoids context limits)
- 📋 **PLANNING/BUILDING modes** — Separate phases for architecture and implementation
- 🧪 **Backpressure** — Run tests/lints after each implementation

## What's Different?

| Standard Ralph | This Version |
|----------------|--------------|
| Bash loop runs until done/fail | Agent notifies on events |
| Manual monitoring | Automatic escalation |
| Silent failures | Immediate error alerts |
| No rate-limit handling | File-based notification fallback |
| Lost notifications | Always recoverable |

## How It Works

1. **PLANNING phase**: Agent analyzes specs, creates `IMPLEMENTATION_PLAN.md`
2. **BUILDING phase**: Agent implements tasks one by one, tests, commits
3. **Notifications**: Agent writes to `.ralph/pending-notification.txt`
4. **Pickup**: OpenClaw checks for pending notifications during heartbeats

> **Note**: External processes (Codex, Claude Code) cannot directly wake OpenClaw — there's no CLI command for it. The file-based notification is the primary mechanism. Configure OpenClaw's HEARTBEAT.md to check for `.ralph/pending-notification.txt` files.

### Notification Format

`.ralph/pending-notification.txt`:
```json
{
  "timestamp": "2026-02-07T02:30:00+01:00",
  "project": "/home/user/my-project",
  "message": "DONE: All tasks complete.",
  "iteration": 15,
  "max_iterations": 20,
  "cli": "codex",
  "status": "pending"
}
```

### Message Prefixes

| Prefix | Meaning |
|--------|---------|
| `DECISION:` | Need human input on a choice |
| `ERROR:` | Tests failing after retries |
| `BLOCKED:` | Missing dependency or unclear spec |
| `PROGRESS:` | Major milestone complete |
| `DONE:` | All tasks finished |
| `PLANNING_COMPLETE:` | Ready for BUILDING mode |

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

## Clean Sessions

Each iteration spawns a **fresh agent session**:
- `codex exec` starts a new process with no memory
- Context persists via files: `IMPLEMENTATION_PLAN.md`, `AGENTS.md`, git history
- This is intentional — avoids context window limits

## Recovery After Rate Limits

If OpenClaw is rate-limited when a notification is sent:

```bash
# Find pending notifications
find ~/projects -name "pending-notification.txt" -path "*/.ralph/*"

# Check a specific project
cat /path/to/project/.ralph/pending-notification.txt

# After processing, clear it
mv .ralph/pending-notification.txt .ralph/last-notification.txt
```

## System Requirements

⚠️ **Memory**: AI coding agents can spike memory usage significantly. Recommended:
- **8GB+ RAM** with **4GB+ swap**
- Without swap, OOM killer may terminate the loop silently (signal 9)

```bash
# Add swap if needed
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Auto-Restart with systemd

For long-running loops, use systemd to auto-restart on crashes:

```bash
# Create service file
sudo tee /etc/systemd/system/ralph-loop.service << 'EOF'
[Unit]
Description=Ralph AI Loop
After=network.target

[Service]
Type=simple
User=YOUR_USER
WorkingDirectory=/path/to/project
ExecStart=/path/to/ralph.sh 50
Restart=on-failure
RestartSec=30
Environment=RALPH_CLI=codex

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ralph-loop
sudo systemctl start ralph-loop
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
