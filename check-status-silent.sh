#!/bin/bash
# check-status-silent.sh - Silent 30-minute status check via window name
# Usage: ./check-status-silent.sh <sprite-name> <repo-name>
# Output: Status logged to /var/log/orchestrator-status.log

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <sprite-name> <repo-name>"
    exit 1
fi

SPRITE_NAME="$1"
REPO_NAME="$2"
TMUX_SESSION="${REPO_NAME}-dev"
AGENT_WINDOW="agent"
LOG_FILE="/var/log/orchestrator-status.log"
MARKER_FILE="/tmp/orchestrator-last-check-${SPRITE_NAME}"

# Check if 30 minutes have passed since last check
LAST_CHECKED=0
if [ -f "$MARKER_FILE" ]; then
    LAST_CHECKED=$(stat -c %Y "$MARKER_FILE" 2>/dev/null || echo 0)
fi
NOW=$(date +%s)
AGE=$((NOW - LAST_CHECKED))

if [ $AGE -gt 1800 ]; then
    # Check if sprite exists
    if sprite list 2>/dev/null | grep -q "^${SPRITE_NAME}$"; then
        # Read window name via tmux - use list-windows and grep since sprite exec doesn't return stdout well
        STATUS=$(sprite exec -s "$SPRITE_NAME" -- tmux list-windows -t "$TMUX_SESSION" -F "#W" 2>/dev/null | grep "^${AGENT_WINDOW}" || echo "unknown")

        # Log silently
        echo "$(date +%Y-%m-%dT%H:%M:%S) $SPRITE_NAME $STATUS" >> "$LOG_FILE"
    fi

    # Update marker
    touch "$MARKER_FILE"
fi
