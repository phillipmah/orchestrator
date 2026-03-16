#!/bin/bash
# check-completion.sh - Check if a worker task has completed
# Usage: ./check-completion.sh <sprite-name> [task-id]
# Exit: 0 if completed, 1 if still running, 2 if error

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name> [task-id]" >&2
    exit 2
fi

SPRITE_NAME="$1"
TASK_ID="${2:-unknown}"
ORCHESTRATOR_DIR="$HOME/.sprite-orchestrator"

# Get worker status
STATUS=$("$ORCHESTRATOR_DIR/worker-status.sh" "$SPRITE_NAME" 2>/dev/null) || {
    echo "error"
    exit 2
}

case "$STATUS" in
    "running")
        echo "running"
        exit 1
        ;;
    "completed")
        echo "completed"
        exit 0
        ;;
    "stopped")
        # Check if this is a clean completion or crash
        # Look for recent history entries
        LAST_ACTIVITY=$(sprite exec -s "$SPRITE_NAME" -- sh -c "tail -1 ~/.claude/history.jsonl 2>/dev/null" 2>/dev/null || echo "")
        if [ -n "$LAST_ACTIVITY" ]; then
            echo "completed"
            exit 0
        else
            echo "crashed"
            exit 1
        fi
        ;;
    *)
        echo "unknown: $STATUS"
        exit 2
        ;;
esac
