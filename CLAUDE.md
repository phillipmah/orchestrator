# Tmux Orchestrator — Agent Knowledge Base

## Role

You coordinate Claude agents running on worker sprites using tmux.

## Skill

The `/orchestrator` skill is available at `~/.sprite-orchestrator/skills/orchestrator/SKILL.md`.

Users can invoke it via:
```
/orchestrator --repo <name> --command "<task>"
```

## Architecture

```
Orchestrator (single codebase, infers repo from PWD)
│
├─ sprite list (discovers all sprites)
│   └─ Filter: kite-1, kite-2, kite-3
│
└─ Worker Sprite (e.g., kite-1)
    ├─ Repo cloned (~/kite)
    ├─ deps installed (mix setup)
    └─ tmux: kite-dev (windows: shell, agent)
```

## Commands

| Command | Purpose |
|---------|---------|
| `orchestrate.sh "<command>"` | Send command to next available worker (auto-detects repo) |
| `detect-repo.sh` | Get repo name from PWD/git |
| `sprite list` | Discover all sprites |
| `allocate-sprite.sh <repo>` | Find idle by naming convention |
| `is-sprite-busy.sh <sprite>` | Check if sprite has claude running |
| `send-to-worker.sh <sprite> <window> <cmd>` | Send command |
| `capture-from-worker.sh <sprite> <window>` | Get output |
| `setup-kite.sh <sprite>` | Provision kite worker |

## orchestrate.sh

**Usage:** `./orchestrate.sh "<command>"`

The repo name is auto-detected from the current working directory (PWD) using:
1. `git remote get-url origin` → repo name
2. Fallback: directory basename

## Protocols

### Repo Detection
1. Git remote origin → repo name
2. Fallback: directory basename

### Allocation
1. `sprite list` | grep "^kite-[0-9]*$"
2. Check each with `is-sprite-busy.sh`
3. First idle wins
4. All busy → create next number

### 30-Minute Commit Rule
All workers commit every 30 minutes.

## Files

| File | Purpose |
|------|---------|
| `setup-kite.sh` | Kite provisioning |
| `allocate-sprite.sh` | Find idle via sprite list |
| `is-sprite-busy.sh` | Check if claude running |
| `send-to-worker.sh` | Send command |
| `capture-from-worker.sh` | Capture output |
| `detect-repo.sh` | Detect repo from PWD |
