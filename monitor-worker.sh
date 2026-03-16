#!/bin/bash
# monitor-worker.sh - Monitor worker sprite progress with completion detection
# Usage: ./monitor-worker.sh <sprite-name> <task-id> [interval]
# Polls every N seconds (default 30) until Claude exits, captures final summary

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <sprite-name> <task-id> [interval]" >&2
    exit 1
fi

SPRITE_NAME="$1"
TASK_ID="$2"
INTERVAL="${3:-30}"

MONITOR_LOG="/tmp/monitor-${SPRITE_NAME}-${TASK_ID}.log"
ORCHESTRATOR_DIR="$HOME/.sprite-orchestrator"

log() {
    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] $1" | tee -a "$MONITOR_LOG"
}

log "Starting monitor for $SPRITE_NAME (task: $TASK_ID, interval: ${INTERVAL}s)"

# Track previous status for transition detection
PREV_STATUS="unknown"
COMPLETION_DETECTED=false

# Initial status check
PREV_STATUS=$("$ORCHESTRATOR_DIR/worker-status.sh" "$SPRITE_NAME" 2>/dev/null || echo "stopped")
log "Initial status: $PREV_STATUS"

# If not running initially, task may have already completed
if [ "$PREV_STATUS" = "stopped" ] || [ "$PREV_STATUS" = "completed" ]; then
    log "Task already completed or not started, capturing final summary"
    "$ORCHESTRATOR_DIR/capture-session-summary.sh" "$SPRITE_NAME" --final 2>&1 | tee -a "$MONITOR_LOG"
    log "Monitor loop ended - completion detected"
    echo "completed"
    exit 0
fi

log "Claude is running, beginning monitoring loop..."

while true; do
    # Check current status
    CURRENT_STATUS=$("$ORCHESTRATOR_DIR/worker-status.sh" "$SPRITE_NAME" 2>/dev/null || echo "stopped")

    log "Status: $CURRENT_STATUS (previous: $PREV_STATUS)"

    # Detect transition from running to stopped/completed
    if [ "$PREV_STATUS" = "running" ] && [ "$CURRENT_STATUS" != "running" ]; then
        log "COMPLETION DETECTED: Claude process exited (transition: running -> $CURRENT_STATUS)"
        COMPLETION_DETECTED=true

        # Capture final summary before returning
        log "Capturing final session summary..."
        "$ORCHESTRATOR_DIR/capture-session-summary.sh" "$SPRITE_NAME" --final 2>&1 | tee -a "$MONITOR_LOG"

        log "Monitor loop ended - completion detected"
        echo "completed"
        exit 0
    fi

    # Handle case where status shows completed directly
    if [ "$CURRENT_STATUS" = "completed" ]; then
        log "Completion status reported, capturing final summary..."
        "$ORCHESTRATOR_DIR/capture-session-summary.sh" "$SPRITE_NAME" --final 2>&1 | tee -a "$MONITOR_LOG"
        log "Monitor loop ended - completion detected"
        echo "completed"
        exit 0
    fi

    # Update previous status
    PREV_STATUS="$CURRENT_STATUS"

    sleep "$INTERVAL"
done
