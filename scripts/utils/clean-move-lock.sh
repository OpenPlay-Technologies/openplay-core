#!/bin/bash

# Clean Move.lock file by removing the localnet environment section
# This script removes only [env.localnet] section that is auto-generated on local deployments
# Other environment sections (like [env.testnet], [env.mainnet]) are preserved

set -euo pipefail

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MOVE_LOCK="$PROJECT_ROOT/package/Move.lock"

if [ ! -f "$MOVE_LOCK" ]; then
    echo "Move.lock file not found at $MOVE_LOCK"
    exit 1
fi

# Create a temporary file
TEMP_FILE=$(mktemp)

# Use awk to remove only [env.localnet] section and its contents
# Keep all other [env.*] sections (like [env.testnet], [env.mainnet], etc.)
awk '
    BEGIN {
        in_localnet_section = 0
    }
    /^\[env\.localnet\]/ {
        # Start of [env.localnet] section - skip it
        in_localnet_section = 1
        next
    }
    /^\[/ {
        # Hit a new section header - stop skipping localnet section
        in_localnet_section = 0
        print
        next
    }
    !in_localnet_section {
        # Print lines that are not in the localnet section
        print
    }
' "$MOVE_LOCK" > "$TEMP_FILE"

# Remove trailing empty [env] section if it exists
# This handles the case where [env] is left empty after removing [env.localnet]
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires backup extension
    sed -i.bak '/^\[env\]$/d' "$TEMP_FILE" 2>/dev/null || true
    rm -f "${TEMP_FILE}.bak" 2>/dev/null || true
else
    sed -i '/^\[env\]$/d' "$TEMP_FILE" 2>/dev/null || true
fi

# Ensure file ends with exactly one newline (remove any trailing newlines, then add one)
# This preserves the original file format
# Use a Python one-liner or awk to normalize trailing newlines
python3 -c "
import sys
with open('$TEMP_FILE', 'rb') as f:
    content = f.read()
# Remove all trailing newlines
content = content.rstrip(b'\n')
# Add exactly one newline
content += b'\n'
with open('$TEMP_FILE', 'wb') as f:
    f.write(content)
" 2>/dev/null || \
awk 'BEGIN{RS="^$";ORS=""} {gsub(/\n+$/, ""); print; print "\n"}' "$TEMP_FILE" > "${TEMP_FILE}.new" && mv "${TEMP_FILE}.new" "$TEMP_FILE" 2>/dev/null || true

# Replace the original file only if there are changes
if ! cmp -s "$MOVE_LOCK" "$TEMP_FILE"; then
    mv "$TEMP_FILE" "$MOVE_LOCK"
    echo "Cleaned Move.lock: removed environment-specific sections"
    exit 0
else
    rm "$TEMP_FILE"
    exit 0
fi

