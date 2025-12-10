#!/bin/bash

# Create OpenPlay Fee Collector Instances
# This script creates fee collector instances for a given house

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

# Function to save fee collector creation output to files
save_fee_collector_output() {
    local env="$1"
    local timestamp="$2"
    local output_dir="outputs/$env"
    local base_filename="fee_collector_${timestamp}"
    
    # Create environment-specific directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Save env file with fee collector id and cap id
    local env_file="$output_dir/${base_filename}.env"
    > "$env_file"
    echo "export OPENPLAY_FEE_COLLECTOR_ID=\"$FEE_COLLECTOR_ID\"" >> "$env_file"
    echo "export OPENPLAY_FEE_COLLECTOR_CAP_ID=\"$FEE_COLLECTOR_CAP_ID\"" >> "$env_file"
    echo "export OPENPLAY_HOUSE_ID=\"$HOUSE_ID\"" >> "$env_file"
    print_success "Fee collector environment saved to $env_file"
}

if [ $# -ne 3 ]; then
    echo ""
    print_status "Usage: $0 <house_id> <house_admin_cap_id> <recipient_address>"
    print_status "Example: $0 0x123... 0x456... 0xabc..."
    echo ""
    print_status "This script creates a fee collector for the specified house."
    print_status "The fee collector will be shared and the cap will be sent to the recipient."
    exit 1
fi

HOUSE_ID="$1"
HOUSE_ADMIN_CAP_ID="$2"
RECIPIENT_ADDRESS="$3"

if [ -z "$HOUSE_ID" ] || [ -z "$HOUSE_ADMIN_CAP_ID" ] || [ -z "$RECIPIENT_ADDRESS" ]; then
    print_error "All parameters are required: house_id, house_admin_cap_id, and recipient_address"
    exit 1
fi

if [ ! -f "package/Move.toml" ]; then
    print_error "This script must be run from the openplay-core root directory"
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
print_status "Creation timestamp: $TIMESTAMP"

# Load core environment variables
if [ -f "outputs/$ACTIVE_ENV/latest.env" ]; then
    # shellcheck disable=SC1090
    source "outputs/$ACTIVE_ENV/latest.env"
    print_success "Loaded core package environment variables"
else
    print_error "Core package not deployed. Run ./scripts/core/deploy-core.sh first."
    exit 1
fi

# Check if package variables are loaded
if [ -z "$CURRENT_OPENPLAY_CORE_PACKAGE_ID" ]; then
    print_error "Required package variables not loaded. Ensure core package is deployed."
    exit 1
fi

CORE_PACKAGE_ID="$CURRENT_OPENPLAY_CORE_PACKAGE_ID"

print_status "Creating fee collector for house: $HOUSE_ID"
print_status "House Admin Cap: $HOUSE_ADMIN_CAP_ID"
print_status "Recipient: $RECIPIENT_ADDRESS"

# Create the fee collector
print_status "Creating fee collector instance..."
print_status "Core Package ID: $CORE_PACKAGE_ID"

# Temporarily disable exit on error to capture the output
set +e
FEE_COLLECTOR_OUTPUT=$(sui client ptb \
    --move-call $CORE_PACKAGE_ID::house::admin_create_fee_collector @$HOUSE_ID @$HOUSE_ADMIN_CAP_ID \
    --assign createFeeCollectorOutput \
    --move-call $CORE_PACKAGE_ID::fee_collector::share createFeeCollectorOutput.0 \
    --transfer-objects [createFeeCollectorOutput.1] @$RECIPIENT_ADDRESS \
    --json 2>&1)
PTB_EXIT_CODE=$?
set -e

# Check if the command itself failed
if [ $PTB_EXIT_CODE -ne 0 ]; then
    print_error "sui client ptb command failed with exit code: $PTB_EXIT_CODE"
    print_error "Output:"
    echo "$FEE_COLLECTOR_OUTPUT"
    exit 1
fi

# Check if output is valid JSON
if ! echo "$FEE_COLLECTOR_OUTPUT" | jq empty 2>/dev/null; then
    print_error "Invalid JSON response from sui client ptb"
    print_error "Raw output:"
    echo "$FEE_COLLECTOR_OUTPUT"
    exit 1
fi

# Check if fee collector creation was successful
if echo "$FEE_COLLECTOR_OUTPUT" | jq -e '.effects.status.status == "success"' > /dev/null; then
    print_success "Fee collector created successfully!"
else
    print_error "Fee collector creation failed!"
    print_error "Status:"
    echo "$FEE_COLLECTOR_OUTPUT" | jq '.effects.status'
    print_error "Full response:"
    echo "$FEE_COLLECTOR_OUTPUT" | jq '.'
    exit 1
fi

# Extract fee collector ID (get first match only)
FEE_COLLECTOR_ID=$(echo "$FEE_COLLECTOR_OUTPUT" | jq -r '.objectChanges[] | select(.type == "created" and (.objectType | contains("::fee_collector::FeeCollector"))) | .objectId' | head -n1)

if [ -z "$FEE_COLLECTOR_ID" ] || [ "$FEE_COLLECTOR_ID" = "null" ]; then
    print_error "Failed to extract fee collector ID"
    exit 1
fi

# Extract fee collector cap ID (check both created and transferred since it's transferred in the same transaction, get first match only)
FEE_COLLECTOR_CAP_ID=$(echo "$FEE_COLLECTOR_OUTPUT" | jq -r '.objectChanges[] | select((.type == "created" or .type == "transferred") and (.objectType | contains("::fee_collector::FeeCollectorCap"))) | .objectId' | head -n1)

if [ -z "$FEE_COLLECTOR_CAP_ID" ] || [ "$FEE_COLLECTOR_CAP_ID" = "null" ]; then
    print_error "Failed to extract fee collector cap ID"
    exit 1
fi

# Save outputs to files
save_fee_collector_output "$ACTIVE_ENV" "$TIMESTAMP"

# Print summary
echo ""
print_success "Fee collector creation completed successfully!"
echo ""
print_status "Fee Collector Summary:"
echo "  Fee Collector ID: $FEE_COLLECTOR_ID"
echo "  Fee Collector Cap ID: $FEE_COLLECTOR_CAP_ID"
echo "  House ID: $HOUSE_ID"
echo "  Cap Recipient: $RECIPIENT_ADDRESS"
echo ""
