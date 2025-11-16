#!/bin/bash

# Mint and transfer a Play Cap to a specified address

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_active_env() { sui client active-env 2>/dev/null || echo "unknown"; }
get_timestamp() { date +"%Y%m%d_%H%M%S"; }

if [ $# -ne 1 ]; then
    echo ""
    echo "Usage: $0 <recipient_address>"
    echo "Example: $0 0xabc123..."
    exit 1
fi

RECIPIENT_ADDRESS="$1"

if [ -z "$RECIPIENT_ADDRESS" ]; then
    print_error "Recipient address is required"
    exit 1
fi

if [ ! -f "packages/openplay_core/Move.toml" ]; then
    print_error "This script must be run from the openplay-framework root directory"
    exit 1
fi

if ! command -v sui &> /dev/null; then
    print_error "sui client is not available. Please ensure Sui is installed and in your PATH."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    exit 1
fi

ACTIVE_ENV=$(get_active_env)
TIMESTAMP=$(get_timestamp)
print_status "Active environment: $ACTIVE_ENV"
print_status "Mint timestamp: $TIMESTAMP"

# Load core package and balance manager IDs
if [ -f "outputs/$ACTIVE_ENV/latest.env" ]; then
    # shellcheck disable=SC1090
    source "outputs/$ACTIVE_ENV/latest.env"
    print_success "Loaded core package environment variables"
else
    print_error "Core package not deployed. Run ./scripts/deploy-core.sh first."
    exit 1
fi

if [ -f "outputs/$ACTIVE_ENV/latest_balance_manager.env" ]; then
    # shellcheck disable=SC1090
    source "outputs/$ACTIVE_ENV/latest_balance_manager.env"
    print_success "Loaded balance manager environment variables"
else
    print_error "Balance manager not set up. Run ./scripts/setup-balance-manager.sh first."
    exit 1
fi

if [ -z "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" ]; then
    print_error "Core package variables not loaded."
    exit 1
fi

if [ -z "$OPENPLAY_BALANCE_MANAGER_ID" ] || [ -z "$OPENPLAY_BALANCE_MANAGER_CAP_ID" ]; then
    print_error "Balance manager variables not loaded from latest_balance_manager.env."
    exit 1
fi

CORE_PACKAGE_ID="$CURRENT_OPENPLAY_CORE_PACKAGE_ID"
print_status "Minting Play Cap using Core Package: $CORE_PACKAGE_ID"
print_status "Recipient: $RECIPIENT_ADDRESS"

MINT_OUTPUT=$(sui client ptb \
    --move-call $CORE_PACKAGE_ID::balance_manager::mint_play_cap @$OPENPLAY_BALANCE_MANAGER_ID @$OPENPLAY_BALANCE_MANAGER_CAP_ID \
    --assign playCap \
    --transfer-objects "[playCap]" @$RECIPIENT_ADDRESS \
    --json)

PLAY_CAP_ID=$(echo "$MINT_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("::balance_manager::PlayCap"))) | .objectId')

if [ -z "$PLAY_CAP_ID" ] || [ "$PLAY_CAP_ID" = "null" ]; then
    print_error "Failed to mint/transfer Play Cap"
    echo "$MINT_OUTPUT" | jq '.' || echo "$MINT_OUTPUT"
    exit 1
fi

print_success "Play cap created and transferred: $PLAY_CAP_ID -> $RECIPIENT_ADDRESS"

# Save to outputs
OUTPUT_DIR="outputs/$ACTIVE_ENV"
mkdir -p "$OUTPUT_DIR"
ENV_FILE="$OUTPUT_DIR/play_cap_${TIMESTAMP}.env"
> "$ENV_FILE"
echo "export OPENPLAY_PLAY_CAP_ID=\"$PLAY_CAP_ID\"" >> "$ENV_FILE"
print_success "Saved Play Cap env to $ENV_FILE"

echo ""
print_status "Mint Summary:"
echo "  Play Cap ID: $PLAY_CAP_ID"
echo "  Recipient: $RECIPIENT_ADDRESS"
echo ""


