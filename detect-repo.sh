#!/bin/bash
# detect-repo.sh - Detect repo name from working directory
# Usage: ./detect-repo.sh
# Output: repo name (e.g., "kite")

# Try git remote first
REPO_NAME=$(git remote get-url origin 2>/dev/null | \
    sed 's|.*/\([^/]*\)\.git|\1|' | \
    sed 's|\.git$||')

if [ -n "$REPO_NAME" ]; then
    echo "$REPO_NAME"
    exit 0
fi

# Fallback: directory basename
basename "$(pwd)"
