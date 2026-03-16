#!/bin/bash
# capture-from-worker.sh - Capture output from worker sprite
# Usage: ./capture-from-worker.sh <sprite-name> <window-index> [lines]

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <sprite-name> <window-index> [num-lines]"
    exit 1
fi

SPRITE_NAME="$1"
WINDOW="$2"
LINES="${3:-200}"

WORKER_TMUX_SESSION="kite-dev"

# Capture pane content
sprite exec -s "$SPRITE_NAME" -- \
    tmux capture-pane -t "$WORKER_TMUX_SESSION:$WINDOW" -p -S -"$LINES"
