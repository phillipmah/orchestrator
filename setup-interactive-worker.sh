#!/bin/bash
# setup-interactive-worker.sh - Set up interactive Claude session on worker sprite
# Usage: ./setup-interactive-worker.sh <sprite-name>
#
# This script:
# 1. Ensures Claude is authenticated (via setup-token or existing auth)
# 2. Pre-configures theme to skip interactive prompt
# 3. Creates tmux session with Claude running interactively
# 4. Sets up auto-commit reminder for 30-minute rule

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>"
    echo "Example: $0 kite-1"
    exit 1
fi

SPRITE_NAME="$1"
REPO_DIR="/home/sprite/kite"
TMUX_SESSION="kite-dev"
SHELL_WINDOW=0
AGENT_WINDOW=1

echo "Setting up interactive Claude worker on $SPRITE_NAME..."

# Step 0: Copy Claude authentication from orchestrator
echo "Copying Claude authentication..."
CLAUDE_AUTH_B64=$(base64 -w0 < ~/.claude.json 2>/dev/null || echo "")
if [ -n "$CLAUDE_AUTH_B64" ]; then
    sprite exec -s "$SPRITE_NAME" -- sh -c "mkdir -p ~/.claude && echo '$CLAUDE_AUTH_B64' | base64 -d > ~/.claude.json && chmod 600 ~/.claude.json"
    echo "Claude auth copied"
else
    echo "WARNING: No Claude auth found on orchestrator"
fi

# Copy OAuth credentials
if [ -f ~/.claude/.credentials.json ]; then
    CRED_B64=$(base64 -w0 < ~/.claude/.credentials.json)
    sprite exec -s "$SPRITE_NAME" -- sh -c "echo '$CRED_B64' | base64 -d > ~/.claude/.credentials.json && chmod 600 ~/.claude/.credentials.json"
    echo "Claude credentials copied"
fi

# Copy settings
if [ -f ~/.claude/settings.json ]; then
    SETTINGS_B64=$(base64 -w0 < ~/.claude/settings.json)
    sprite exec -s "$SPRITE_NAME" -- sh -c "echo '$SETTINGS_B64' | base64 -d > ~/.claude/settings.json"
    echo "Claude settings copied"
fi

# Inject trusted directories and permissions into .claude.json
echo "Configuring trusted directories and permissions..."
sprite exec -s "$SPRITE_NAME" -- sh -c '
# Read .claude.json, ensure workspaceTrust and permissions are set, write back
python3 << "PYEOF"
import json

try:
    with open("/home/sprite/.claude.json", "r") as f:
        data = json.load(f)
except:
    data = {}

# Ensure workspaceTrust exists
if "workspaceTrust" not in data:
    data["workspaceTrust"] = {}

# Set accepted to skip dialog
data["workspaceTrust"]["accepted"] = True

# Trust the entire home directory (sprites are disposable anyway)
data["workspaceTrust"]["trustedDirectories"] = {
    "/home/sprite": True
}

# Write back
with open("/home/sprite/.claude.json", "w") as f:
    json.dump(data, f, indent=2)
PYEOF
'

# Copy settings.json with bypassPermissions
sprite exec -s "$SPRITE_NAME" -- sh -c '
cat > /home/sprite/.claude/settings.json << "EOF"
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true
}
EOF
'
echo "Trusted directories configured (/home/sprite)"

# Step 1: Ensure ~/.sprite-worker directory exists
echo "Creating worker directory..."
sprite exec -s "$SPRITE_NAME" -- mkdir -p ~/.sprite-worker

# Step 2: Create worker startup script
echo "Creating worker startup script..."
sprite exec -s "$SPRITE_NAME" -- sh -c '
cat > ~/.sprite-worker/start-claude-session.sh << "EOF"
#!/bin/bash
# start-claude-session.sh - Start interactive Claude in tmux agent window
# Usage: ./start-claude-session.sh [task]
#
# Uses --dangerously-skip-permissions + auto-accept trust dialog

TMUX_SESSION="kite-dev"
AGENT_WINDOW=1
REPO_DIR="${REPO_DIR:-/home/sprite/kite}"

TASK="$1"

# Ensure tmux session exists
if ! tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    tmux new-session -d -s $TMUX_SESSION -n "shell"
    tmux new-window -t $TMUX_SESSION -n "agent"
fi

# Change to repo dir
tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "cd $REPO_DIR" Enter

# Start Claude with --dangerously-skip-permissions and auto-accept trust dialog
sleep 2  # Let tmux process the cd command
if [ -n "$TASK" ]; then
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "claude --dangerously-skip-permissions \"$TASK\"" Enter
    sleep 3  # Wait for trust dialog to appear
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW Enter  # Auto-accept trust (option 1 is default)
else
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "claude --dangerously-skip-permissions" Enter
    sleep 3
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW Enter
fi

echo "Claude session started in $TMUX_SESSION:$AGENT_WINDOW"
EOF
chmod +x ~/.sprite-worker/start-claude-session.sh
'

# Step 3: Create auto-commit reminder script (30-minute rule)
echo "Creating auto-commit reminder..."
sprite exec -s "$SPRITE_NAME" -- sh -c '
cat > ~/.sprite-worker/commit-reminder.sh << "EOF"
#!/bin/bash
# commit-reminder.sh - Prompt Claude to commit every 30 minutes
# Run this periodically via cron or tmux

TMUX_SESSION="kite-dev"
AGENT_WINDOW=1

# Send reminder to agent window
tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "echo \"=== 30-minute commit reminder ===\"" Enter
tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "echo \"Run /commit to save your work\"" Enter
tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW "" Enter
EOF
chmod +x ~/.sprite-worker/commit-reminder.sh
'

# Step 4: Check authentication status
echo "Checking authentication..."
AUTH_STATUS=$(sprite exec -s "$SPRITE_NAME" -- sh -c '
if [ -f ~/.claude.json ] || [ -f ~/.config/claude/claude.json ]; then
    echo "authenticated"
else
    echo "needs-auth"
fi
')

if [ "$AUTH_STATUS" = "needs-auth" ]; then
    echo ""
    echo "WARNING: Claude needs authentication on $SPRITE_NAME"
    echo "Run this command to set up token:"
    echo "  sprite console -s $SPRITE_NAME"
    echo "  claude setup-token"
    echo ""
    echo "Or if already authenticated on orchestrator, copy auth:"
    echo "  sprite exec -s $SPRITE_NAME -- mkdir -p ~/.claude"
    echo "  sprite exec -s $SPRITE_NAME -- cp ~/.claude.json ~/.sprite-worker/ 2>/dev/null || true"
    echo ""
fi

# Step 5: Initialize tmux session
echo "Initializing tmux session on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
    echo 'Tmux session already exists'
else
    tmux new-session -d -s $TMUX_SESSION -n 'shell'
    tmux new-window -t $TMUX_SESSION -n 'agent'
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW 'cd $REPO_DIR' Enter
    tmux send-keys -t $TMUX_SESSION:$AGENT_WINDOW 'echo Ready for Claude session' Enter
fi
"

# Step 6: Verify tmux setup
echo "Verifying tmux setup..."
WINDOWS=$(sprite exec -s "$SPRITE_NAME" -- tmux list-windows -t $TMUX_SESSION -F '#I:#W' 2>/dev/null || echo "")
echo "Windows: $WINDOWS"

echo ""
echo "Setup complete!"
echo ""
echo "To start an interactive Claude session:"
echo "  sprite exec -s $SPRITE_NAME -- ~/.sprite-worker/start-claude-session.sh [task]"
echo ""
echo "To monitor Claude (attach to tmux session):"
echo "  sprite console -s $SPRITE_NAME"
echo "  tmux attach -t kite-dev"
echo ""
echo "Note: Claude uses a full-screen TUI. To watch live, you must attach to tmux."
echo "      The capture-pane command only shows shell history, not Claude's UI."
echo ""
echo "Windows:"
echo "  0: shell (commands, logs)"
echo "  1: agent (Claude interactive session)"
echo ""
echo "To send commands from orchestrator:"
echo "  ~/.sprite-orchestrator/send-to-worker.sh $SPRITE_NAME 1 \"ls -la\""
echo ""
echo "To view Claude's session history:"
echo "  sprite exec -s $SPRITE_NAME -- cat ~/.claude/history.jsonl | tail -20"
