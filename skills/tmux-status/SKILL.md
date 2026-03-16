---
name: tmux-status
description: Use when running in orchestrated tmux session - updates window names with status
---

# Tmux Status Skill

Use raw tmux commands to update window names with your status.

## Status Commands

| Status | Command |
|--------|---------|
| Start working | `tmux rename-window -t $TMUX_SESSION:agent "agent:running"` |
| Complete task | `tmux rename-window -t $TMUX_SESSION:agent "agent:completed"` |
| Blocked/error | `tmux rename-window -t $TMUX_SESSION:agent "agent:error"` |

## Variables

- `TMUX_SESSION` - Set by orchestrator (e.g., `sonar-dev`)
- Default: `${REPO_NAME}-dev` where REPO_NAME is from working directory

## Usage

When you start working on a task:
```bash
tmux rename-window -t sonar-dev:agent "agent:running"
```

When you complete:
```bash
tmux rename-window -t sonar-dev:agent "agent:completed"
```

## Transparency

These commands are visible in your tmux session history. The orchestrator reads
window names every 30 minutes to monitor status.
