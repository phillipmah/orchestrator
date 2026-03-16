#!/bin/bash
# setup-kite.sh - Provision a kite worker sprite
# Usage: ./setup-kite.sh <sprite-name>
# Example: ./setup-kite.sh kite-1

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>"
    echo "Example: $0 kite-1"
    exit 1
fi

SPRITE_NAME="$1"
REPO_URL="git@github.com:phillipmah/kite.git"
REPO_DIR="/home/sprite/kite"
TMUX_SESSION="kite-dev"

echo "Provisioning kite worker: $SPRITE_NAME"

# Step 1: Set up SSH keys on worker sprite
echo "Setting up SSH keys on $SPRITE_NAME..."
SPRITE_SSH_DIR="/home/sprite/.ssh"
sprite exec -s "$SPRITE_NAME" -- sh -c "
    mkdir -p ~/.ssh && chmod 700 ~/.ssh

    # Copy SSH private key
    cat > ~/.ssh/id_ed25519 << 'SSHKEY_EOF'
$(cat ~/.ssh/id_ed25519 | base64 -w0 | base64 -d)
SSHKEY_EOF
    chmod 600 ~/.ssh/id_ed25519

    # Copy SSH public key
    cat ~/.ssh/id_ed25519.pub > ~/.ssh/id_ed25519.pub

    # Disable strict host key checking for first clone
    echo 'StrictHostKeyChecking no' > ~/.ssh/config
    chmod 644 ~/.ssh/config
"

# Clone repo on worker sprite
echo "Cloning kite repo on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
    if [ ! -d '$REPO_DIR' ]; then
        git clone '$REPO_URL' '$REPO_DIR'
    fi
"

# Install deps on worker sprite (skip database creation)
echo "Installing dependencies (mix deps.get + compile) on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
    cd '$REPO_DIR' && mix deps.get && mix compile
"

# Create tmux session on worker sprite
echo "Creating tmux session on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
    if tmux has-session -t $TMUX_SESSION 2>/dev/null; then
        echo 'Tmux session already exists'
    else
        tmux new-session -d -s $TMUX_SESSION -n 'shell'
        tmux new-window -t $TMUX_SESSION -n 'agent'
        tmux send-keys -t $TMUX_SESSION:agent 'cd $REPO_DIR' Enter
        tmux send-keys -t $TMUX_SESSION:agent 'echo Ready for work' Enter
    fi
"

echo "kite worker '$SPRITE_NAME' ready"
echo "  - Repo: $REPO_DIR"
echo "  - Tmux: $TMUX_SESSION (windows: shell, agent)"
