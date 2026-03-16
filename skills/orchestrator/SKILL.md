---
name: orchestrator
description: Coordinate Claude agents across worker sprites - allocates idle sprites, provisions environment, and dispatches tasks
---

## /orchestrator Skill

Dispatches tasks to Claude agents running on worker sprites (Fly.io VMs).

### Usage

```
/orchestrator --repo <name> --command "<task>"
/orchestrator --repo kite --command "fix the authentication bug"
/orchestrator --repo kite --command "add user login endpoint"
```

### Required Flags

- `--repo <name>` - The worker pool name (e.g., `kite`, `api`). **Cannot be auto-detected** because the orchestrator runs from its own directory.
- `--command "<task>"` - The task to send to the Claude agent.

### What It Does

1. **Allocates** - Finds the next idle worker sprite (`kite-1`, `kite-2`, etc.)
2. **Creates** - Provisions new sprite if none exist
3. **Setup** - Configures SSH keys, clones repo, installs deps, creates tmux session
4. **Dispatches** - Starts Claude interactively and sends your command

### Architecture

```
Orchestrator Sprite
│
├─ allocate-sprite.sh → finds idle kite-N
├─ setup-worker.sh → clones repo, runs scripts/dev-setup.sh
├─ setup-interactive-worker.sh → Claude auth, tmux
└─ start-claude-session.sh → launches Claude
    │
    └─> Worker Sprite (kite-1)
        ├─ Repo: ~/kite
        ├─ tmux: kite-dev
        │   ├─ Window 0: shell
        │   └─ Window 1: agent (Claude runs here)
        └─ Claude session running interactively
```

### Monitoring Workers

To watch a worker's Claude session:

```bash
sprite console -s kite-1
tmux attach -t kite-dev
```

To see session history:

```bash
sprite exec -s kite-1 -- cat ~/.claude/history.jsonl | tail -10
```

### Worker Protocols

- **30-Minute Commit Rule**: Workers should commit every 30 minutes
- **Hub-and-Spoke**: Workers report to orchestrator only
- **Naming Convention**: `kite-1`, `kite-2`, `kite-3`...

### Status Protocol

Workers report status via tmux window names:

| Window Name | Meaning |
|-------------|---------|
| `agent:waiting` | Claude started, awaiting input |
| `agent:running` | Actively working |
| `agent:completed` | Task done |
| `agent:error` | Failed/blocked |

Orchestrator checks every 30 minutes silently:
```bash
~/.sprite-orchestrator/check-status-silent.sh <sprite> <repo>
# Logs to: /var/log/orchestrator-status.log
```

### Commands Available

| Script | Purpose |
|--------|---------|
| `orchestrate.sh --repo X --command "Y"` | Dispatch task to next idle worker |
| `allocate-sprite.sh <repo>` | Find idle sprite or return new name |
| `is-sprite-busy.sh <sprite>` | Check if sprite has Claude running |
| `send-to-worker.sh <sprite> <window> <cmd>` | Send raw command |
| `setup-worker.sh <sprite> <repo>` | Provision worker (SSH, clone, dev-setup.sh, tmux) |

### Example Flow

```bash
# Dispatch a task
/orchestrator --repo kite --command "refactor the auth module"

# Output shows:
# - Which worker was allocated (e.g., kite-1)
# - Provisioning status
# - How to monitor the session
```

### Repository Requirements

Each repository must include a `scripts/dev-setup.sh` file that provisions the development environment:

**Example for Python (Sonar):**
```bash
#!/bin/bash
# scripts/dev-setup.sh
set -e
echo "Setting up Python environment..."
python3 --version
pip install poetry
poetry install
echo "✅ Ready"
```

**Example for Elixir (Kite):**
```bash
#!/bin/bash
# scripts/dev-setup.sh
set -e
echo "Setting up Elixir environment..."
mix deps.get
mix compile
echo "✅ Ready"
```

The orchestrator will:
1. Clone the repo to `~/<repo-name>`
2. Run `./scripts/dev-setup.sh` if it exists
3. Create tmux session named `<repo-name>-dev`

### Troubleshooting

**Sprite not found**: The skill auto-creates sprites if they don't exist.

**Claude shows trust dialog**: First run on a new sprite requires confirming the workspace trust dialog. Attach via tmux to confirm.

**All workers busy**: Orchestrator creates the next number (kite-N+1).
