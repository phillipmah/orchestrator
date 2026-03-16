#!/bin/bash
# allocate-sprite.sh - Find idle sprite or return new name
# Usage: ./allocate-sprite.sh <repo-name>
# Output: sprite-name (e.g., kite-1)

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <repo-name>"
    exit 1
fi

REPO_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find sprites matching pattern: <repo>-N (e.g., kite-1, kite-2)
MATCHING_SPRITES=$(sprite list | grep "^${REPO_NAME}-[0-9]*$" || true)

if [ -z "$MATCHING_SPRITES" ]; then
    # No matching sprites - create first
    echo "${REPO_NAME}-1"
    exit 0
fi

# Check each sprite for availability
for sprite in $MATCHING_SPRITES; do
    if "$SCRIPT_DIR/is-sprite-busy.sh" "$sprite" 2>/dev/null; then
        # is-sprite-busy returns 0 if busy, so skip
        continue
    else
        # Sprite is idle (exit code 1 from is-sprite-busy)
        echo "$sprite"
        exit 0
    fi
done

# All busy - find next number
LAST_NUM=$(echo "$MATCHING_SPRITES" | sed "s/${REPO_NAME}-//" | sort -n | tail -1)
NEXT_NUM=$((LAST_NUM + 1))
echo "${REPO_NAME}-${NEXT_NUM}"
