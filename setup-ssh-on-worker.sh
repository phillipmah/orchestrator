#!/bin/bash
# setup-ssh-on-worker.sh - Copy SSH keys to worker sprite
# Usage: ./setup-ssh-on-worker.sh <sprite-name>

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <sprite-name>"
    exit 1
fi

SPRITE_NAME="$1"

echo "Setting up SSH keys on $SPRITE_NAME..."

# Create .ssh directory
sprite exec -s "$SPRITE_NAME" -- mkdir -p ~/.ssh
sprite exec -s "$SPRITE_NAME" -- chmod 700 ~/.ssh

# Copy private key via base64
PRIVATE_KEY_B64=$(base64 -w0 < ~/.ssh/id_ed25519)
sprite exec -s "$SPRITE_NAME" -- sh -c "echo '$PRIVATE_KEY_B64' | base64 -d > ~/.ssh/id_ed25519"
sprite exec -s "$SPRITE_NAME" -- chmod 600 ~/.ssh/id_ed25519

# Copy public key via base64
PUBLIC_KEY_B64=$(base64 -w0 < ~/.ssh/id_ed25519.pub)
sprite exec -s "$SPRITE_NAME" -- sh -c "echo '$PUBLIC_KEY_B64' | base64 -d > ~/.ssh/id_ed25519.pub"
sprite exec -s "$SPRITE_NAME" -- chmod 644 ~/.ssh/id_ed25519.pub

# Disable strict host key checking
sprite exec -s "$SPRITE_NAME" -- sh -c "echo 'StrictHostKeyChecking no' > ~/.ssh/config"
sprite exec -s "$SPRITE_NAME" -- chmod 644 ~/.ssh/config

# Copy known_hosts if exists
if [ -f ~/.ssh/known_hosts ]; then
    KNOWN_HOSTS_B64=$(base64 -w0 < ~/.ssh/known_hosts)
    sprite exec -s "$SPRITE_NAME" -- sh -c "echo '$KNOWN_HOSTS_B64' | base64 -d > ~/.ssh/known_hosts"
    sprite exec -s "$SPRITE_NAME" -- chmod 644 ~/.ssh/known_hosts
fi

echo "SSH keys configured on $SPRITE_NAME"
