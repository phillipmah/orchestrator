# Tmux Orchestrator

**Run AI agents 24/7 while you sleep.**

A tmux-based orchestrator that coordinates Claude agents across a pool of Fly.io sprites. Infers the project repo from your working directory, allocates idle worker sprites, and provisions them automatically.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Orchestrator (single codebase, infers repo from PWD)       │
│  - pool.json: tracks sprites per repo                       │
│  - allocate-sprite.sh: finds idle or creates new            │
│  - setup-<repo>.sh: provisions worker                       │
└─────────────────────────────────────────────────────────────┘
         │
         │ sprite exec
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Worker Sprite Pool (e.g., kite-1, kite-2, kite-3)          │
│  - Repo cloned (~/kite)                                     │
│  - Dependencies installed (mix setup)                       │
│  - tmux session: kite-dev (windows: shell, agent)           │
│  - Claude agent running in agent window                     │
└─────────────────────────────────────────────────────────────┘
```

## How It Works

### Start of Day

```bash
cd ~/projects/kite
/orchestrator "add login button"
```

### What Happens

1. **Detect repo** - reads git remote, infers "kite"
2. **Allocate sprite** - finds idle sprite from pool (kite-1, kite-2, etc.)
3. **Provision** - clones repo, installs deps, creates tmux session
4. **Send command** - runs command in worker's agent window
5. **Mark busy** - updates pool.json

## Pool State

```json
{
  "repos": {
    "kite": {
      "sprites": [
        {"name": "kite-1", "status": "idle"},
        {"name": "kite-2", "status": "busy", "task": "implement auth"}
      ],
      "setup_script": "setup-kite.sh",
      "repo_url": "git@github.com:phillipmah/kite.git"
    }
  }
}
```

## Scripts

| Script | Purpose |
|--------|---------|
| `detect-repo.sh` | Get repo name from PWD/git remote |
| `allocate-sprite.sh <repo>` | Find idle sprite or create new |
| `setup-kite.sh <sprite>` | Provision kite worker |
| `send-to-worker.sh <sprite> <window> <cmd>` | Send command |
| `capture-from-worker.sh <sprite> <window>` | Capture output |

## Usage

### Claude Skill

```bash
/orchestrator "implement the auth module"
/orchestrator "fix the login bug"
```

### Manual Commands

```bash
# Detect current repo
~/.sprite-orchestrator/detect-repo.sh

# Allocate a sprite
~/.sprite-orchestrator/allocate-sprite.sh kite

# Provision a worker
~/.sprite-orchestrator/setup-kite.sh kite-1

# Send command
~/.sprite-orchestrator/send-to-worker.sh kite-1 1 "mix test"

# Capture output
~/.sprite-orchestrator/capture-from-worker.sh kite-1 1 200
```

## Protocols

### 30-Minute Commit Rule

All worker agents must commit every 30 minutes to prevent work loss.

### Hub-and-Spoke Communication

- Workers report to Orchestrator only
- No direct worker-to-worker communication

## Tech Stack

- tmux - session management
- sprite CLI - Fly.io sprite management
- bash - orchestration scripts
- Elixir/Mix - for kite project

## Repository

https://github.com/phillipmah/orchestrator

## License

MIT
