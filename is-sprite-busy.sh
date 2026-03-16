#!/bin/bash
# is-sprite-busy.sh - Check if sprite has active claude/tmux session
# Usage: ./is-sprite-busy.sh <sprite-name>
# Exit: 0 if busy, 1 if idle
# Output: nothing on success, "busy" or "idle" on stderr for debugging

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>"
    exit 1
fi

SPRITE_NAME="$1"

# Check if tmux session "kite-dev" exists and has claude running
if sprite exec -s "$SPRITE_NAME" -- tmux has-session -t kite-dev 2>/dev/null; then
    # Check if claude process is running
    if sprite exec -s "$SPRITE_NAME" -- pgrep -f claude > /dev/null 2>&1; then
        echo "busy" >&2
        exit 0
    fi
fi

echo "idle" >&2
exit 1
