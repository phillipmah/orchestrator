# Tmux Orchestrator — Agent Knowledge Base

## Role

You coordinate Claude agents running on worker sprites using tmux. This is the **primary orchestration approach** for dispatching work to sprites.

## Quick Start

```bash
# From any project directory:
/orchestrator "<task>"

# Or directly:
~/.sprite-orchestrator/orchestrate.sh "fix the authentication bug"
```

## Skill

The `/orchestrator` skill is available at `~/.sprite-orchestrator/skills/orchestrator/SKILL.md`.

## Architecture

```
Orchestrator (auto-detects repo from PWD)
│
├─ allocate-sprite.sh → finds idle sprite (sonar-1, sonar-2, etc.)
├─ setup-worker.sh → provisions: SSH, clone repo, deps, tmux
│
└─ Worker Sprite (e.g., sonar-1)
    ├─ Repo: ~/sonar
    ├─ tmux session: sonar-dev
    │   ├─ window "shell"
    │   └─ window "agent:running" ← status signaled here
    └─ Claude process running in tmux
```

## Status Protocol

Workers report status via tmux window names. The orchestrator reads these every 30 minutes.

| Window Name | Meaning | When Set |
|-------------|---------|----------|
| `agent:waiting` | Claude started, awaiting input | Session start |
| `agent:running` | Actively working | When begins work |
| `agent:completed` | Task done | On completion |
| `agent:error` | Failed/blocked | On error |

**Agents update status** using raw tmux commands (documented in `~/.sprite-orchestrator/skills/tmux-status/SKILL.md`):

```bash
tmux rename-window -t sonar-dev:agent "agent:running"
```

**Orchestrator monitors** silently every 30 minutes:

```bash
~/.sprite-orchestrator/check-status-silent.sh sonar-1 sonar
# Logs to: /var/log/orchestrator-status.log
```

## 30-Minute Commit Rule

All workers must commit every 30 minutes while running. The orchestrator logs status silently—if a worker shows `agent:running` for more than 30 minutes without committing, it should be nudged.

## Commands

| Command | Purpose |
|---------|---------|
| `orchestrate.sh "<command>"` | Dispatch to next available worker (auto-detects repo) |
| `check-status-silent.sh <sprite> <repo>` | Silent 30-min status check via window name |
| `allocate-sprite.sh <repo>` | Find idle sprite by naming convention |
| `is-sprite-busy.sh <sprite>` | Check if sprite has claude running |
| `setup-worker.sh <sprite> <repo>` | Provision worker (SSH, clone, deps, tmux) |
| `setup-ssh-on-worker.sh <sprite>` | Set up SSH keys on worker |
| `detect-repo.sh` | Get repo name from PWD/git remote |
| `sprite list` | Discover all sprites |
| `worker-status.sh <sprite>` | Check Claude running status |
| `capture-session-summary.sh <sprite>` | Get final output when complete |

## Files

| File | Purpose |
|------|---------|
| `orchestrate.sh` | Main dispatch script with background monitoring |
| `check-status-silent.sh` | 30-min silent status check via window names |
| `allocate-sprite.sh` | Find idle sprite via `sprite list` |
| `setup-worker.sh` | Generic worker provisioning |
| `setup-ssh-on-worker.sh` | SSH key setup |
| `setup-interactive-worker.sh` | Claude auth setup |
| `is-sprite-busy.sh` | Check if claude process running |
| `worker-status.sh` | Status: running/completed/stopped |
| `capture-session-summary.sh` | Final summary capture |
| `skills/orchestrator/SKILL.md` | Claude skill definition |
| `skills/tmux-status/SKILL.md` | Status reporting protocol |

## Workflow

1. **Invoke** `/orchestrator <task>` from project directory
2. **Detect repo** from PWD (git remote or basename)
3. **Allocate sprite** (finds idle `sonar-N` or creates new)
4. **Provision** if needed (SSH, clone, deps, tmux)
5. **Dispatch** task via `start-claude-session.sh`
6. **Monitor** every 30 minutes (silent log)
7. **Complete** when Claude exits, capture summary

## Naming Convention

```
sonar-1, sonar-2, sonar-3  → sonar workers
kite-1, kite-2, kite-3     → kite workers
api-1, api-2               → api workers
```

## Logs

- Status log: `/var/log/orchestrator-status.log`
- Format: `TIMESTAMP SPRITE_NAME STATUS`
- Example: `2026-03-16T22:03:04 sonar-4 agent:running`

## Anti-Patterns

- Don't skip provisioning check
- Don't send to busy sprites (allocation handles this)
- Don't assume sprite has repo cloned
- Don't ignore 30-minute commit rule
