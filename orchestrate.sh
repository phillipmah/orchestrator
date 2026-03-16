#!/bin/bash
# orchestrate.sh - Spawn a monitoring subagent to dispatch and track worker sprites
# Usage: ./orchestrate.sh "<command>"
#
# Spawns a Claude Code subagent (via `claude` CLI) that:
# 1. Detects repo from current working directory (PWD)
# 2. Finds next idle worker sprite for that repo
# 3. Creates sprite if it doesn't exist
# 4. Provisions if needed (SSH keys, clone, deps, tmux, Claude auth)
# 5. Starts Claude and sends the command
# 6. Monitors progress every 30 seconds
# 7. Reports completion when Claude finishes

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"

# Detect repo from PWD (where this script is invoked from)
if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
    REPO_NAME=$(git remote get-url origin 2>/dev/null | sed 's|.*/\([^/]*\)\.git|\1|' | sed 's|\.git$||')
    if [ -z "$REPO_NAME" ]; then
        REPO_NAME=$(basename "$(pwd)")
    fi
else
    REPO_NAME=$(basename "$(pwd)")
fi

if [ $# -lt 1 ]; then
    echo "Usage: $0 \"<command>\""
    echo ""
    echo "Spawns a monitoring subagent to dispatch a task to the next available worker sprite."
    echo "Repo is auto-detected from the current directory: $REPO_NAME"
    echo ""
    echo "Example:"
    echo "  $0 'fix the authentication bug'"
    exit 1
fi

COMMAND="$1"
TASK_ID="${2:-$(date +%s)}"

echo "=== Orchestrator ==="
echo "Repo: $REPO_NAME (auto-detected from PWD)"
echo "Task: $COMMAND"
echo "Task ID: $TASK_ID"
echo "Spawning monitoring subagent..."
echo ""

# Step 1: Allocate next available worker
WORKER_SPRITE=$("$SCRIPT_DIR/allocate-sprite.sh" "$REPO_NAME")
echo "Allocated worker: $WORKER_SPRITE"

# Step 2: Check if sprite exists
if ! sprite list | grep -q "^${WORKER_SPRITE}$"; then
    echo "Creating new sprite: $WORKER_SPRITE..."
    sprite create "$WORKER_SPRITE"
fi

# Step 3: Check if worker needs provisioning
BUSY_STATUS=$("$SCRIPT_DIR/is-sprite-busy.sh" "$WORKER_SPRITE" 2>&1 || true)

if [ "$BUSY_STATUS" != "busy" ]; then
    echo "Status: idle (provisioning...)"
    "$SCRIPT_DIR/setup-ssh-on-worker.sh" "$WORKER_SPRITE" 2>&1 | tail -2
    "$SCRIPT_DIR/setup-worker.sh" "$WORKER_SPRITE" "$REPO_NAME" 2>&1 | tail -3
    "$SCRIPT_DIR/setup-interactive-worker.sh" "$WORKER_SPRITE" 2>&1 | tail -3
fi

# Step 4: Start Claude session on worker
echo ""
echo "Dispatching task to $WORKER_SPRITE..."

sprite exec -s "$WORKER_SPRITE" -- \
    ~/.sprite-worker/start-claude-session.sh "$COMMAND"

echo ""
echo "Claude session started on $WORKER_SPRITE"
echo "Spawning monitoring subagent to track progress..."
echo ""

# Step 5: Spawn Claude Code subagent for monitoring in background
# The subagent runs the monitoring loop and reports completion
echo "Starting monitoring subagent in background..."
nohup "$CLAUDE_BIN" "$(cat <<SUBAGENT_PROMPT
I am a monitoring subagent for the orchestrator skill.

Your task: Monitor a worker sprite until the Claude task completes.

WORKER_INFO:
- Worker sprite: $WORKER_SPRITE
- Task: $COMMAND
- Task ID: $TASK_ID

MONITORING LOOP:
1. Check status every 30 seconds using: ~/.sprite-orchestrator/worker-status.sh $WORKER_SPRITE
2. If status is "stopped", the task is complete - capture final summary
3. While running, use: ~/.sprite-orchestrator/capture-session-summary.sh $WORKER_SPRITE

When the worker completes:
1. Run capture-session-summary.sh to get the final output
2. Report a summary to the user including:
   - What was accomplished
   - Any errors or issues
   - Final state of the worker

Start by checking the initial status of the worker.
SUBAGENT_PROMPT
)" > /tmp/orchestrator-monitor-$TASK_ID.log 2>&1 &

# Step 6: Schedule silent 30-minute status checks
echo "Scheduling silent status checks..."
(
    while true; do
        sleep 1800  # 30 minutes
        "$SCRIPT_DIR/check-status-silent.sh" "$WORKER_SPRITE" "$REPO_NAME"
    done
) &
echo "Silent check PID: $!"

echo ""
echo "=== Task Dispatched ==="
echo "Worker: $WORKER_SPRITE"
echo "Task: $COMMAND"
echo "Status: Running in background"
echo "Monitor log: /tmp/orchestrator-monitor-$TASK_ID.log"
