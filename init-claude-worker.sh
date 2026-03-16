#!/bin/bash
# init-claude-worker.sh - Initialize Claude Code for non-interactive use on worker sprite
# Usage: ./init-claude-worker.sh <sprite-name>
#
# This script:
# 1. Sets up authentication (requires CLAUDE_API_KEY or token)
# 2. Configures non-interactive settings
# 3. Creates a wrapper script for running claude in automation mode

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>"
    echo "Example: $0 kite-1"
    exit 1
fi

SPRITE_NAME="$1"
REPO_DIR="/home/sprite/kite"
TMUX_SESSION="kite-dev"
AGENT_WINDOW=1

echo "Initializing Claude Code on $SPRITE_NAME..."

# Step 1: Create non-interactive wrapper script on worker
echo "Creating claude-ni wrapper script..."
sprite exec -s "$SPRITE_NAME" -- sh -c '
mkdir -p ~/.sprite-worker

cat > ~/.sprite-worker/claude-ni << "CLAUDE_NI_EOF"
#!/bin/bash
# claude-ni - Non-interactive Claude Code wrapper
# Usage: claude-ni [prompt]
# Automatically uses --print and bypasses permissions

exec claude --print \
    --permission-mode bypassPermissions \
    --no-session-persistence \
    "$@"
CLAUDE_NI_EOF

chmod +x ~/.sprite-worker/claude-ni
'

# Step 2: Create automation runner script
echo "Creating automation runner..."
sprite exec -s "$SPRITE_NAME" -- sh -c '
cat > ~/.sprite-worker/run-agent.sh << "RUNNER_EOF"
#!/bin/bash
# run-agent.sh - Run Claude agent in tmux with non-interactive mode
# Usage: ./run-agent.sh <task-description> [output-file]

set -e

TMUX_SESSION="kite-dev"
AGENT_WINDOW=1
REPO_DIR="${REPO_DIR:-/home/sprite/kite}"

TASK="\$1"
OUTPUT_FILE="\${2:-/tmp/claude-output-\$\$.txt}"

if [ -z "\$TASK" ]; then
    echo "Usage: \$0 <task-description> [output-file]"
    exit 1
fi

# Change to repo dir and run claude in non-interactive mode
cd "\$REPO_DIR" 2>/dev/null || cd ~

# Run claude with output redirected to file (no UI)
nohup claude --print \
    --permission-mode bypassPermissions \
    --no-session-persistence \
    "\$TASK" > "\$OUTPUT_FILE" 2>&1 &

echo "Agent task started: \$TASK"
echo "Output: \$OUTPUT_FILE"
RUNNER_EOF

chmod +x ~/.sprite-worker/run-agent.sh
'

# Step 3: Verify Claude is authenticated
echo "Checking Claude authentication..."
if sprite exec -s "$SPRITE_NAME" -- claude --version > /dev/null 2>&1; then
    echo "Claude Code is installed"
else
    echo "ERROR: Claude Code not found on $SPRITE_NAME"
    exit 1
fi

# Step 4: Test non-interactive mode
echo "Testing non-interactive mode..."
OUTPUT=$(sprite exec -s "$SPRITE_NAME" -- claude --print --permission-mode bypassPermissions "echo test" 2>&1 || true)

if echo "$OUTPUT" | grep -q "test"; then
    echo "Non-interactive mode working"
else
    echo "WARNING: Non-interactive mode may need authentication"
    echo "Run on $SPRITE_NAME: claude setup-token"
    echo "Or set CLAUDE_API_KEY environment variable"
fi

echo ""
echo "Initialization complete!"
echo ""
echo "Usage on worker sprite:"
echo "  ~/.sprite-worker/claude-ni \"<prompt>\"     # One-off command"
echo "  ~/.sprite-worker/run-agent.sh \"<task>\"     # Run in tmux agent window"
echo ""
echo "From orchestrator:"
echo "  sprite exec -s $SPRITE_NAME -- ~/.sprite-worker/claude-ni \"ls -la\""
