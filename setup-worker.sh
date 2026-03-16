#!/bin/bash
# setup-worker.sh - Generic worker provisioning using repo's dev-setup.sh
# Usage: ./setup-worker.sh <sprite-name> <repo-name>
# Example: ./setup-worker.sh kite-1 kite

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <sprite-name> <repo-name>"
    echo "Example: $0 kite-1 kite"
    exit 1
fi

SPRITE_NAME="$1"
REPO_NAME="$2"
REPO_URL="git@github.com:phillipmah/${REPO_NAME}.git"
REPO_DIR="/home/sprite/${REPO_NAME}"
TMUX_SESSION="${REPO_NAME}-dev"

echo "Provisioning worker: $SPRITE_NAME for repo: $REPO_NAME"

# Step 1: Set up SSH keys on worker sprite
echo "Setting up SSH keys on $SPRITE_NAME..."
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

# Step 2: Clone repo on worker sprite
echo "Cloning $REPO_NAME repo on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
    if [ ! -d '$REPO_DIR' ]; then
        git clone '$REPO_URL' '$REPO_DIR'
    fi
"

# Step 3: Run repo's dev-setup.sh
echo "Running dev-setup.sh on $SPRITE_NAME..."
sprite exec -s "$SPRITE_NAME" -- sh -c "
    cd '$REPO_DIR'
    if [ -f 'scripts/dev-setup.sh' ]; then
        ./scripts/dev-setup.sh
    else
        echo 'Warning: No scripts/dev-setup.sh found. Skipping setup.'
    fi
"

# Step 4: Create tmux session on worker sprite
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

echo "Worker '$SPRITE_NAME' ready for $REPO_NAME"
echo "  - Repo: $REPO_DIR"
echo "  - Tmux: $TMUX_SESSION (windows: shell, agent)"
