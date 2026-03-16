#!/bin/bash
# send-to-worker.sh - Send command to worker sprite
# Usage: ./send-to-worker.sh <sprite-name> <window-index> <command>

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <sprite-name> <window-index> <command>"
    exit 1
fi

SPRITE_NAME="$1"
WINDOW="$2"
shift 2
COMMAND="$*"

WORKER_TMUX_SESSION="kite-dev"

# Use sprite exec to send keys to worker's tmux
sprite exec -s "$SPRITE_NAME" -- \
    tmux send-keys -t "$WORKER_TMUX_SESSION:$WINDOW" "$COMMAND" Enter

echo "Sent to $SPRITE_NAME:$WINDOW: $COMMAND"
