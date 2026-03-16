#!/bin/bash
# capture-session-summary.sh - Get Claude session summary from worker
# Usage: ./capture-session-summary.sh <sprite-name> [window] [--final]
# Outputs last N lines of Claude history and tmux session
# --final: capture final output when session ends

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name> [window] [--final]" >&2
    exit 1
fi

SPRITE_NAME="$1"
WINDOW="${2:-1}"  # default to agent window
FINAL=false

# Check for --final flag
for arg in "$@"; do
    if [ "$arg" = "--final" ]; then
        FINAL=true
    fi
done

# Capture Claude history (last 30 lines for more context)
echo "=== Claude Session History (last 30 lines) ==="
HISTORY_OUTPUT=$(sprite exec -s "$SPRITE_NAME" -- sh -c "tail -30 ~/.claude/history.jsonl 2>/dev/null || echo 'No history found'" 2>/dev/null || echo "Error reading history")
echo "$HISTORY_OUTPUT"

echo ""
echo "=== Session End Markers ==="
# Look for completion indicators in history
if echo "$HISTORY_OUTPUT" | grep -q "completed\|finished\|done" 2>/dev/null; then
    echo "Session completion markers detected"
fi

echo ""
echo "=== Tmux Session Output (last 100 lines) ==="
# Capture more lines for final summary
LINES="${FINAL:+-100}"
LINES="${LINES:--50}"
sprite exec -s "$SPRITE_NAME" -- sh -c "tmux capture-pane -t kite-dev:$WINDOW -p -S $LINES 2>/dev/null || echo 'No tmux session'"

echo ""
echo "=== Process Status ==="
sprite exec -s "$SPRITE_NAME" -- sh -c "ps aux | grep claude | grep -v grep || echo 'No Claude process'"

echo ""
echo "=== tmux Session Status ==="
sprite exec -s "$SPRITE_NAME" -- sh -c "tmux list-sessions 2>/dev/null || echo 'No tmux sessions'"
