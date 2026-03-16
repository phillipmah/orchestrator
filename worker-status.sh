#!/bin/bash
# worker-status.sh - Check if Claude is running on a worker sprite
# Usage: ./worker-status.sh <sprite-name>
# Exit: 0 always (status returned via stdout)
# Output: "running", "completed", or "stopped"

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>" >&2
    exit 1
fi

SPRITE_NAME="$1"

# Check if tmux session exists
SESSION_EXISTS=false
if sprite exec -s "$SPRITE_NAME" -- tmux has-session -t kite-dev 2>/dev/null; then
    SESSION_EXISTS=true
fi

# Check if Claude process is running
CLAUDE_RUNNING=false
if sprite exec -s "$SPRITE_NAME" -- pgrep -f "claude" > /dev/null 2>&1; then
    CLAUDE_RUNNING=true
fi

# Check for completion markers in history (session ended normally)
HAS_COMPLETED=false
if [ "$SESSION_EXISTS" = "true" ]; then
    # Look for session end markers in recent history
    LAST_ENTRIES=$(sprite exec -s "$SPRITE_NAME" -- sh -c "tail -5 ~/.claude/history.jsonl 2>/dev/null || echo ''" 2>/dev/null || echo "")
    if echo "$LAST_ENTRIES" | grep -q "session.*end\|completed\|finished" 2>/dev/null; then
        HAS_COMPLETED=true
    fi
fi

# Determine status
if [ "$CLAUDE_RUNNING" = "true" ]; then
    echo "running"
    exit 0
elif [ "$HAS_COMPLETED" = "true" ]; then
    echo "completed"
    exit 0
elif [ "$SESSION_EXISTS" = "true" ]; then
    # tmux exists but Claude not running - likely completed
    echo "completed"
    exit 0
else
    echo "stopped"
    exit 0
fi
